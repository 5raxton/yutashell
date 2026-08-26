pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common
import "../widgets"

// BarActions — the single dispatcher for segment click-actions (PH.14). Maps an
// action string to the shell's open/toggle functions; `ipc:<target>/<fn>`
// forwards to the shell's own IPC surface (same code the CLI/keybinds use).
Singleton {
    id: root

    // returns true when the action was recognized — callers may fall back
    function dispatch(action) {
        const a = String(action ?? "").trim();
        if (a.length === 0 || a === "none")
            return false;
        if (a.startsWith("ipc:")) {
            root._dispatchIpc(a.slice(4));
            return true;
        }
        if (a.startsWith("plugin:")) {
            PluginService.togglePluginPanel(a.slice(7));
            return true;
        }
        switch (a) {
        case "calendar":
            ShellState.toggleCalendar();
            break;
        case "network":
            ShellState.toggleNet();
            break;
        case "bluetooth":
            ShellState.toggleBt();
            break;
        case "audio":
            ShellState.toggleAudio();
            break;
        case "media":
            ShellState.toggleMedia();
            break;
        case "power":
            ShellState.toggleSession();
            break;
        case "notifications":
            ShellState.toggleNotifyCenter();
            break;
        case "controlcenter":
            ShellState.toggleCc();
            break;
        case "launcher":
            ShellState.toggleLauncher();
            break;
        case "settings":
            ShellState.togglePanel();
            break;
        case "picker":
            ShellState.togglePicker();
            break;
        case "nightlight":
            NightLight.toggle();
            break;
        case "mixer":
            ShellState.toggleMixer();
            break;
        case "scratchpad":
            ShellState.toggleOverview();
            break;
        default:
            return false;
        }
        return true;
    }

    function _dispatchIpc(spec) {
        const idx = spec.indexOf("/");
        if (idx <= 0)
            return;
        const target = spec.slice(0, idx).trim();
        const fn = spec.slice(idx + 1).trim();
        if (target.length === 0 || fn.length === 0)
            return;
        // re-enter the shell's own IPC: `qs ipc call <target> <fn...>`
        proc.command = ["qs", "ipc", "call", target].concat(fn.split(/\s+/));
        proc.running = true;
    }

    Process {
        id: proc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
}
