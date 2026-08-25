pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// PluginService — discovers and runs external QML plugins living in
// `<configroot>/plugins/<PluginName>/`. Each plugin carries a `plugin.json`
// manifest; type "daemon" instantiates invisibly at boot/scan, type "widget"
// is offered to the bar's pluginwidgets segment, type "bar" registers its own
// bar segment with an optional floating panel. Per-plugin state lives under
// ShellState.pluginData as { "<id>": { enabled, data } } — namespaced from all
// core prefs. Loading external QML executes code: only drop trusted plugins
// here (the manifest `permissions` field is declared + surfaced, enforcement
// comes later).
Singleton {
    id: root

    // ---- config root resolution -------------------------------------------
    // Prefer explicit CLI (-p/--path, -c/--config); fall back to the engine's
    // configDir when present, then the conventional path.
    readonly property string configRoot: {
        const args = Qt.application.arguments;
        for (let i = 0; i < args.length - 1; i++) {
            if (args[i] === "-p" || args[i] === "--path")
                return args[i + 1];
        }
        const cd = String(Quickshell.configDir ?? "");
        if (cd.length > 0)
            return cd.replace(/^file:\/\//, "").replace(/\/$/, "");
        const cfg = Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config";
        for (let i = 0; i < args.length - 1; i++) {
            if (args[i] === "-c" || args[i] === "--config")
                return cfg + "/quickshell/" + args[i + 1];
        }
        return cfg + "/quickshell/yuta-qs";
    }

    readonly property string pluginsRoot: configRoot + "/plugins"

    // ---- discovered manifests ----------------------------------------------
    property var manifests: []
    property bool scanning: false
    property string lastScanError: ""

    // created daemon objects, id → item
    property var daemons: ({})

    // instantiated panel windows for bar-type plugins, id → PanelWindow
    property var panels: ({})

    function isEnabled(id) {
        try {
            const m = JSON.parse(ShellState.pluginData);
            return m[id] ? m[id].enabled === true : false;
        } catch (e) {
            return false;
        }
    }

    function setEnabled(id, on) {
        let m = {};
        try {
            m = JSON.parse(ShellState.pluginData);
        } catch (e) {}
        m[id] = m[id] || {};
        m[id].enabled = on;
        m[id].data = m[id].data || {};
        ShellState.set("pluginData", JSON.stringify(m));
        // plugin toggles are user-paced, not bursty: land them on disk NOW.
        // The 80ms coalesced flush once let a concurrent reload re-read stale
        // disk and silently revert the flag before it ever persisted.
        ShellState.flushNow();
        root._enableRev++;
        if (!on) {
            _unload(id);
            _unloadPanel(id);
        } else {
            const mf = root.manifests.find(x => x.id === id);
            if (mf && (mf.type === "daemon" || mf.type === "bar"))
                _instantiate(mf);
            if (mf && mf.type === "bar" && mf.panelComponent)
                _instantiatePanel(mf);
            // first enabled widget flips the bar segment on so it actually shows
            // (direct ShellState write — importing BarSegments here would be a
            // singleton import cycle)
            if (mf && mf.type === "widget") {
                let list = [];
                try {
                    list = JSON.parse(ShellState.barSegments);
                } catch (e) {}
                if (!Array.isArray(list) || list.length === 0)
                    list = [];
                const seg = list.find(s => s.id === "pluginwidgets");
                if (!seg)
                    list.push({
                        id: "pluginwidgets",
                        zone: "right",
                        enabled: true
                    });
                else
                    seg.enabled = true;
                ShellState.set("barSegments", JSON.stringify(list));
                ShellState.flushNow();
            }
            // bar-type plugin: register its custom segment in the bar model
            if (mf && mf.type === "bar" && mf.barSegment && mf.barSegment.id) {
                let list = [];
                try {
                    list = JSON.parse(ShellState.barSegments);
                } catch (e) {}
                if (!Array.isArray(list) || list.length === 0)
                    list = [];
                const segId = mf.barSegment.id;
                const seg = list.find(s => s.id === segId);
                if (!seg)
                    list.push({
                        id: segId,
                        zone: mf.barSegment.zone || "right",
                        enabled: true
                    });
                else
                    seg.enabled = true;
                ShellState.set("barSegments", JSON.stringify(list));
                ShellState.flushNow();
            }
        }
    }

    function loadPluginData(id, key, def) {
        try {
            const m = JSON.parse(ShellState.pluginData);
            const d = m[id]?.data ?? {};
            return key in d ? d[key] : def;
        } catch (e) {
            return def;
        }
    }

    function savePluginData(id, key, value) {
        let m = {};
        try {
            m = JSON.parse(ShellState.pluginData);
        } catch (e) {}
        m[id] = m[id] || {
            enabled: root.isEnabled(id),
            data: {}
        };
        m[id].data = m[id].data || {};
        m[id].data[key] = value;
        ShellState.set("pluginData", JSON.stringify(m));
        // no flushNow here: daemons save several keys back-to-back, and
        // forced immediate writes overlap inside FileView and get silently
        // dropped (AGENTS lesson #3). The 80 ms coalesced flush absorbs bursts.
    }

    // widget-type plugins that are enabled → bar hosts these.
    // Deliberately depends on _enableRev (bumped ONLY by setEnabled), NOT on
    // pluginData — daemon data saves would otherwise recreate the array and
    // tear down the bar's widget Loaders though enablement never changed.
    property int _enableRev: 0

    readonly property var enabledWidgets: {
        const _rev = root._enableRev;
        const _mf = root.manifests;
        return _mf.filter(m => m.type === "widget" && root.isEnabled(m.id));
    }

    // bar-type plugins that are enabled → each owns its own bar segment
    readonly property var enabledBarPlugins: {
        const _rev = root._enableRev;
        const _mf = root.manifests;
        return _mf.filter(m => m.type === "bar" && root.isEnabled(m.id) && m.barSegment);
    }

    // segment-id → manifest lookup for bar plugins
    readonly property var _barPluginMap: {
        const _ = root.enabledBarPlugins;
        const map = {};
        for (let i = 0; i < _.length; i++) {
            const mf = _[i];
            if (mf.barSegment && mf.barSegment.id)
                map[mf.barSegment.id] = mf;
        }
        return map;
    }

    // ---- plugin panel state ----
    property string pluginOpenId: ""

    function togglePluginPanel(id) {
        if (root.pluginOpenId === id) {
            root.pluginOpenId = "";
        } else {
            FocusMonitor.latch();
            root.pluginOpenId = id;
            // close all core panels directly (not via _exclusive which
            // would re-close the plugin panel we just opened)
            ShellState.panelOpen = false;
            ShellState.pickerOpen = false;
            ShellState.launcherOpen = false;
            ShellState.netOpen = false;
            ShellState.btOpen = false;
            ShellState.notifyCenterOpen = false;
            ShellState.audioOpen = false;
            ShellState.mediaOpen = false;
            ShellState.sessionOpen = false;
            ShellState.overviewOpen = false;
            ShellState.altTabOpen = false;
            ShellState.calendarOpen = false;
            ShellState.clipboardOpen = false;
            ShellState.weatherOpen = false;
            ShellState.emojiOpen = false;
            ShellState.ccOpen = false;
        }
    }

    function closePluginPanel() {
        root.pluginOpenId = "";
    }

    function isPluginPanelOpen(id) {
        return root.pluginOpenId === id;
    }

    // ---- URL helpers ----
    function componentUrl(mf) {
        return "file://" + root.pluginsRoot + "/" + (mf.dir || "") + "/" + (mf.component || "main.qml");
    }

    function barComponentUrl(mf) {
        return "file://" + root.pluginsRoot + "/" + (mf.dir || "") + "/" + (mf.barComponent || "BarWidget.qml");
    }

    function panelComponentUrl(mf) {
        return "file://" + root.pluginsRoot + "/" + (mf.dir || "") + "/" + (mf.panelComponent || "UpdatePanel.qml");
    }

    // ---- scanning -----------------------------------------------------------
    // One-shot: find manifests and dump their contents in a single process,
    // separated by @@FILE markers — no per-file async reads to chain.
    Process {
        id: scanProc

        property string _script: "d='" + root.pluginsRoot + "'; [ -d \"$d\" ] || exit 0; find \"$d\" -mindepth 2 -maxdepth 2 -name plugin.json | sort | while read -r f; do echo \"@@FILE $f\"; cat \"$f\"; done"
        command: ["sh", "-c", _script]
        stdout: StdioCollector {
            onStreamFinished: root._parseListing(this.text)
        }
        onExited: code => {
            if (code !== 0)
                root.lastScanError = "scan exited " + code;
        }
    }

    function scan() {
        root.scanning = true;
        root.lastScanError = "";
        scanProc.running = true;
    }

    function _parseListing(text) {
        const found = [];
        const chunks = text.split("@@FILE ");
        for (let i = 0; i < chunks.length; i++) {
            const c = chunks[i];
            if (i === 0 && c.trim().length === 0)
                continue;
            const nl = c.indexOf("\n");
            if (nl < 0)
                continue;
            const path = c.slice(0, nl).trim();
            const body = c.slice(nl + 1);
            const dir = path.split("/").slice(-2, -1)[0];
            let mf = null;
            try {
                mf = JSON.parse(body);
            } catch (e) {
                root.lastScanError = "bad manifest: " + dir;
            }
            if (!mf || !mf.id || !mf.type)
                continue;
            // explicit copy — this engine is not guaranteed to have spread
            const out = {
                id: String(mf.id),
                name: String(mf.name ?? mf.id),
                description: String(mf.description ?? ""),
                version: String(mf.version ?? "0"),
                author: String(mf.author ?? ""),
                icon: String(mf.icon ?? ""),
                type: String(mf.type),
                component: String(mf.component ?? "main.qml"),
                settings: Array.isArray(mf.settings) ? mf.settings : [],
                permissions: Array.isArray(mf.permissions) ? mf.permissions : []
            };
            out.dir = dir;
            // bar-type plugin fields
            if (mf.barSegment && typeof mf.barSegment === "object") {
                out.barSegment = {
                    id: String(mf.barSegment.id || ""),
                    label: String(mf.barSegment.label || mf.name || mf.id),
                    jp: String(mf.barSegment.jp || ""),
                    zone: String(mf.barSegment.zone || "right")
                };
            }
            if (mf.barComponent)
                out.barComponent = String(mf.barComponent);
            if (mf.panelComponent)
                out.panelComponent = String(mf.panelComponent);
            found.push(out);
        }
        root.manifests = found.sort((a, b) => a.id < b.id ? -1 : 1);
        root.scanning = false;
        root._syncDaemons();
    }

    // ---- lifecycle -----------------------------------------------------------
    function _syncDaemons() {
        for (const mf of root.manifests) {
            if ((mf.type === "daemon" || mf.type === "bar") && root.isEnabled(mf.id) && !(mf.id in root.daemons))
                _instantiate(mf);
            if (mf.type === "bar" && mf.panelComponent && root.isEnabled(mf.id) && !(mf.id in root.panels))
                _instantiatePanel(mf);
        }
        // unload daemons whose manifest vanished or was disabled
        for (const id in root.daemons) {
            const mf = root.manifests.find(x => x.id === id);
            if (!mf || (mf.type !== "daemon" && mf.type !== "bar") || !root.isEnabled(id))
                _unload(id);
        }
        // unload panels whose manifest vanished or was disabled
        for (const id in root.panels) {
            const mf = root.manifests.find(x => x.id === id);
            if (!mf || mf.type !== "bar" || !mf.panelComponent || !root.isEnabled(id))
                _unloadPanel(id);
        }
    }

    function _instantiate(mf) {
        if (mf.id in root.daemons)
            return;
        try {
            const comp = Qt.createComponent(root.componentUrl(mf));
            if (comp.status === Component.Error) {
                console.warn("plugin", mf.id, "failed:", comp.errorString());
                return;
            }
            const obj = comp.createObject(root, {
                "pluginId": mf.id
            });
            if (obj) {
                root.daemons[mf.id] = obj;
                console.warn("plugin daemon up:", mf.id);
            }
        } catch (e) {
            console.warn("plugin instantiate failed:", mf.id, e);
        }
    }

    function _unload(id) {
        const obj = root.daemons[id];
        if (obj) {
            obj.destroy();
            delete root.daemons[id];
            console.warn("plugin daemon down:", id);
        }
    }

    function _instantiatePanel(mf) {
        if (mf.id in root.panels)
            return;
        try {
            const url = root.panelComponentUrl(mf);
            const comp = Qt.createComponent(url);
            if (comp.status === Component.Error) {
                console.warn("plugin panel", mf.id, "failed:", comp.errorString());
                return;
            }
            const obj = comp.createObject(root, {});
            if (obj) {
                root.panels[mf.id] = obj;
                console.warn("plugin panel up:", mf.id);
            }
        } catch (e) {
            console.warn("plugin panel instantiate failed:", mf.id, e);
        }
    }

    function _unloadPanel(id) {
        const obj = root.panels[id];
        if (obj) {
            obj.destroy();
            delete root.panels[id];
            console.warn("plugin panel down:", id);
        }
    }

    Component.onCompleted: scan()
}
