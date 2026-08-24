pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import QtQuick
import qs.theme
import qs.modules.common
import "../net"
import "../audio"
import "../session"
import "../widgets"

// BarSegments — the bar's segment model (PH.14). Parses the persisted ordered
// array [{id, zone, enabled}] from ShellState and answers the bar's layout
// questions: which segments live in each zone, which are currently visible
// (enabled AND their runtime condition holds), and what click-action each
// carries. Settings' BAR tab drives the same functions for enable/reorder.
Singleton {
    id: root

    readonly property var meta: ({
            "identity": { label: "Identity", jp: "識別" },
            "workspaces": { label: "Workspaces", jp: "作業場" },
            "taskbar": { label: "Taskbar", jp: "任務" },
            "activewindow": { label: "Active window", jp: "窓" },
            "tray": { label: "System tray", jp: "盤" },
            "media": { label: "Media ticker", jp: "媒" },
            "net": { label: "Network chip", jp: "網" },
            "bt": { label: "Bluetooth chip", jp: "歯" },
            "audio": { label: "Audio chip", jp: "音" },
            "stats": { label: "Stats (net/cpu/mem/bat)", jp: "計" },
            "cputemp": { label: "CPU temp", jp: "熱" },
            "gpu": { label: "GPU", jp: "画" },
            "disk": { label: "Disk IO", jp: "盤" },
            "nightlight": { label: "Night light chip", jp: "夜" },
            "session": { label: "Inhibit chip", jp: "阻" },
            "recording": { label: "Recording chip", jp: "録" },
            "pluginwidgets": { label: "Plugin widgets", jp: "拡" },
            "clock": { label: "Clock", jp: "時" }
        })

    // persisted model, parsed with fallback to the default order
    readonly property var model: {
        try {
            const v = JSON.parse(ShellState.barSegments);
            if (Array.isArray(v) && v.length > 0)
                return v;
        } catch (e) {}
        return defaultModel;
    }

    readonly property var defaultModel: [
        { id: "identity", zone: "left", enabled: true },
        { id: "workspaces", zone: "left", enabled: true },
        { id: "taskbar", zone: "left", enabled: false },
        { id: "activewindow", zone: "center", enabled: true },
        { id: "tray", zone: "right", enabled: true },
        { id: "media", zone: "right", enabled: true },
        { id: "net", zone: "right", enabled: true },
        { id: "bt", zone: "right", enabled: true },
        { id: "audio", zone: "right", enabled: true },
        { id: "stats", zone: "right", enabled: true },
        { id: "cputemp", zone: "right", enabled: false },
        { id: "gpu", zone: "right", enabled: false },
        { id: "disk", zone: "right", enabled: false },
        { id: "nightlight", zone: "right", enabled: true },
        { id: "session", zone: "right", enabled: true },
        { id: "recording", zone: "right", enabled: true },
        { id: "pluginwidgets", zone: "right", enabled: false },
        { id: "clock", zone: "right", enabled: true }
    ]

    function enabled(id) {
        const s = root.model.find(x => x.id === id);
        return s ? s.enabled !== false : false;
    }

    // a segment's zone (its persisted zone, or its meta default)
    function zoneOf(id) {
        const s = root.model.find(x => x.id === id);
        return s ? s.zone : "right";
    }

    function zoneList(zone) {
        return root.model.filter(s => s.zone === zone);
    }

    // runtime visibility: enabled AND the underlying condition holds
    function present(id) {
        if (!root.enabled(id))
            return false;
        switch (id) {
        case "media":
            return (Mpris.players.values ?? []).length > 0;
        case "bt": {
            const a = Bluetooth.defaultAdapter;
            return a !== null && a.enabled;
        }
        case "nightlight":
            return NightLight.active;
        case "session":
            return Session.inhibitCount > 0;
        case "recording":
            return Recording.active;
        case "pluginwidgets":
            return PluginService.enabledWidgets.length > 0;
        default:
            return true;
        }
    }

    // the ordered list of visible segment ids for a zone
    readonly property var leftVisible: root._visible("left")
    readonly property var rightVisible: root._visible("right")
    readonly property var centerVisible: root._visible("center")

    function _visible(zone) {
        return root.zoneList(zone).filter(s => root.present(s.id));
    }

    // click action for a segment id, with defaults merged over the pref
    readonly property var defaultClick: ({
            "clock": "calendar",
            "net": "network",
            "bt": "bluetooth",
            "audio": "audio",
            "media": "media",
            "stats": "controlcenter",
            "cputemp": "controlcenter",
            "gpu": "controlcenter",
            "disk": "controlcenter",
            "identity": "settings",
            "nightlight": "nightlight",
            "session": "power",
            "tray": "",
            "workspaces": "",
            "taskbar": ""
        })

    function clickFor(id) {
        try {
            const map = JSON.parse(ShellState.barClick);
            if (map[id])
                return map[id];
        } catch (e) {}
        return root.defaultClick[id] ?? "";
    }

    // ---- mutations (settings BAR tab drives these) ----
    function setEnabled(id, on) {
        const list = root.model.map(s => s.id === id ? {
                    id: s.id,
                    zone: s.zone,
                    enabled: on
                } : s);
        ShellState.set("barSegments", JSON.stringify(list));
    }

    function setZone(id, zone) {
        const list = root.model.map(s => s.id === id ? {
                    id: s.id,
                    zone: zone,
                    enabled: s.enabled !== false
                } : s);
        ShellState.set("barSegments", JSON.stringify(list));
    }

    function move(id, delta) {
        const ids = root.model.map(s => s.id);
        const idx = ids.indexOf(id);
        const j = idx + delta;
        if (idx < 0 || j < 0 || j >= ids.length)
            return;
        // move within the same zone only
        const cur = root.model[idx];
        if (root.model[j].zone !== cur.zone)
            return;
        ids.splice(idx, 1);
        ids.splice(j, 0, id);
        const byId = {};
        for (const s of root.model)
            byId[s.id] = s;
        ShellState.set("barSegments", JSON.stringify(ids.map(x => ({
                        id: x,
                        zone: byId[x].zone,
                        enabled: byId[x].enabled !== false
                    }))));
    }

    function setClick(id, action) {
        let map = {};
        try {
            map = JSON.parse(ShellState.barClick);
        } catch (e) {}
        if (action.length === 0)
            delete map[id];
        else
            map[id] = action;
        ShellState.set("barClick", JSON.stringify(map));
    }
}
