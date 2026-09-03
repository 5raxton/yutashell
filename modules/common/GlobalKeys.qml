pragma Singleton
import Quickshell
import Quickshell.Hyprland
import QtQuick
import qs.modules.common
import qs.modules.audio
import qs.modules.widgets

// GlobalKeys (PH.01.4) — shell-internal keybind dispatcher.
// Registers HyprlandGlobalShortcut entries that fire shell actions directly
// without going through the compositor's keybind IPC. Each shortcut maps a
// physical key to a ShellState toggle or service action.
//
// The shortcut list is configurable via ShellState.globalKeybinds (JSON array
// of {id, key, enabled}). Default bindings ship for common actions.
Singleton {
    id: root

    // ---- keybind registry ----
    readonly property var defaults: [
        { id: "toggleLauncher", key: "SUPER, D", label: "Toggle launcher", enabled: true },
        { id: "toggleOverview", key: "SUPER, TAB", label: "Toggle overview", enabled: true },
        { id: "toggleClipboard", key: "SUPER, V", label: "Toggle clipboard", enabled: true },
        { id: "toggleCC", key: "SUPER, N", label: "Toggle control center", enabled: true },
        { id: "toggleNightLight", key: "SUPER, L", label: "Toggle night light", enabled: false },
        { id: "screenshotArea", key: "SUPER SHIFT, S", label: "Screenshot area", enabled: true },
        { id: "screenshotScreen", key: "SUPER, P", label: "Screenshot screen", enabled: false }
    ]

    readonly property var bindings: {
        try {
            const v = JSON.parse(ShellState.globalKeybinds);
            if (Array.isArray(v) && v.length > 0) return v;
        } catch (e) {}
        return root.defaults;
    }

    function bindingById(id) {
        return root.bindings.find(b => b.id === id) ?? null;
    }

    function _isEnabled(id) {
        const b = root.bindingById(id);
        return b ? b.enabled !== false : false;
    }

    function _key(id) {
        const b = root.bindingById(id);
        return b ? b.key : "";
    }

    function setEnabled(id, on) {
        const updated = root.bindings.map(b =>
            b.id === id ? Object.assign({}, b, { enabled: on }) : b
        );
        ShellState.set("globalKeybinds", JSON.stringify(updated));
    }

    function resetDefaults() {
        ShellState.set("globalKeybinds", JSON.stringify(root.defaults));
    }

    // ---- action dispatch ----
    function _fire(id) {
        switch (id) {
        case "toggleLauncher":
            ShellState.toggleLauncher();
            break;
        case "toggleOverview":
            ShellState.toggleOverview();
            break;
        case "toggleClipboard":
            ShellState.toggleClipboard();
            break;
        case "toggleCC":
            ShellState.toggleCC();
            break;
        case "toggleNightLight":
            NightLight.toggle();
            break;
        case "screenshotArea":
            Screenshot.area();
            break;
        case "screenshotScreen":
            Screenshot.screen();
            break;
        }
    }

    Component.onCompleted: {
        // Force-evaluate bindings at boot
        const _ = root.bindings;
        void _;
    }
}
