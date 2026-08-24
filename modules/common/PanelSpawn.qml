pragma Singleton
import Quickshell
import QtQuick
import qs.theme

// PanelSpawn — where popup cards spawn from and dock to. One persisted pref
// per panel (bar|top|bottom|float), plus a shell-wide default; YSurface
// consumes modeFor() to place its resting spot, hidden offset and flare
// shoulders. Settings' PANELS page drives set()/setDefault().
Singleton {
    id: root

    // every configurable popup surface (id → settings label)
    readonly property var panels: [
        { id: "cc", label: "Control center" },
        { id: "settings", label: "Settings" },
        { id: "launcher", label: "App launcher" },
        { id: "picker", label: "Wallpapers" },
        { id: "notify", label: "Notifications" },
        { id: "calendar", label: "Calendar" },
        { id: "clipboard", label: "Clipboard" },
        { id: "emoji", label: "Emoji" },
        { id: "weather", label: "Weather" },
        { id: "power", label: "Power menu" },
        { id: "net", label: "Network" },
        { id: "bt", label: "Bluetooth" },
        { id: "vol", label: "Volume" },
        { id: "media", label: "Media" },
        { id: "overview", label: "Overview" }
    ]

    readonly property var modes: ["bar", "top", "bottom", "float"]

    function _map() {
        try {
            const m = JSON.parse(ShellState.panelSpawn);
            return m && typeof m === "object" ? m : {};
        } catch (e) {
            return {};
        }
    }

    function defaultMode() {
        const d = String(ShellState.panelSpawnDefault);
        return root.modes.indexOf(d) >= 0 ? d : "bar";
    }

    // resolved spawn origin for a panel id
    function modeFor(id) {
        const m = root._map()[id];
        return root.modes.indexOf(m) >= 0 ? m : root.defaultMode();
    }

    function set(id, mode) {
        if (root.modes.indexOf(mode) < 0)
            return;
        const m = root._map();
        if (mode === root.defaultMode())
            delete m[id];
        else
            m[id] = mode;
        ShellState.set("panelSpawn", JSON.stringify(m));
    }

    function setDefault(mode) {
        if (root.modes.indexOf(mode) < 0)
            return;
        ShellState.set("panelSpawnDefault", mode);
    }
}
