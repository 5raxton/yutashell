pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// PluginService (PH.05) — discovers and runs external QML plugins living in
// `<configroot>/plugins/<PluginName>/`. Each plugin carries a `plugin.json`
// manifest; type "daemon" instantiates invisibly at boot/scan, type "widget"
// is offered to the bar's pluginwidgets segment. Per-plugin state lives under
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
        if (!on) {
            _unload(id);
        } else {
            const mf = root.manifests.find(x => x.id === id);
            if (mf && mf.type === "daemon")
                _instantiate(mf);
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

    // widget-type plugins that are enabled → bar hosts these
    readonly property var enabledWidgets: root.manifests.filter(m => m.type === "widget" && root.isEnabled(m.id))

    function componentUrl(mf) {
        return "file://" + root.pluginsRoot + "/" + (mf.dir || "") + "/" + (mf.component || "main.qml");
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
            found.push(out);
        }
        root.manifests = found.sort((a, b) => a.id < b.id ? -1 : 1);
        root.scanning = false;
        root._syncDaemons();
    }

    // ---- lifecycle -----------------------------------------------------------
    function _syncDaemons() {
        for (const mf of root.manifests) {
            if (mf.type === "daemon" && root.isEnabled(mf.id) && !(mf.id in root.daemons))
                _instantiate(mf);
        }
        // unload daemons whose manifest vanished or was disabled
        for (const id in root.daemons) {
            const mf = root.manifests.find(x => x.id === id);
            if (!mf || mf.type !== "daemon" || !root.isEnabled(id))
                _unload(id);
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

    Component.onCompleted: scan()
}
