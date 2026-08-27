pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.theme
import qs.modules.common
import "../widgets"

// BarActions — the single dispatcher for segment click-actions (PH.14 + PH.07).
// Maps an action string to the shell's open/toggle functions. Supports compound
// actions (JSON array of strings), shell commands, theme switching, and arbitrary
// IPC forwarding via `ipc:<target>/<fn>`.
Singleton {
    id: root

    readonly property var clickProfiles: ({
            "productivity": {
                label: "Productivity",
                actions: { "clock": "calendar", "identity": "controlcenter", "net": "networkdetails" }
            },
            "media-first": {
                label: "Media First",
                actions: { "clock": "media", "identity": "media", "net": "network" }
            },
            "dev": {
                label: "Developer",
                actions: { "clock": "calendar", "identity": "settings", "net": "controlcenter", "cpu": "controlcenter" }
            }
        })

    function applyClickProfile(profileId) {
        const p = root.clickProfiles[profileId];
        if (!p) return;
        let map = {};
        try { map = JSON.parse(ShellState.barClick); } catch (e) {}
        for (const [segId, action] of Object.entries(p.actions))
            map[segId] = action;
        ShellState.set("barClick", JSON.stringify(map));
    }

    function dispatch(action) {
        // compound: JSON array of actions executed in sequence
        if (typeof action === "string" && action.startsWith("[")) {
            try {
                const arr = JSON.parse(action);
                if (Array.isArray(arr)) {
                    for (const a of arr)
                        root.dispatch(a);
                    return true;
                }
            } catch (e) {}
        }
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
        if (a.startsWith("shell:")) {
            root._dispatchShell(a.slice(6));
            return true;
        }
        if (a.startsWith("theme:")) {
            root._dispatchTheme(a.slice(6));
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
        case "networkdetails":
            ShellState.toggleNetDetails();
            break;
        case "processes":
            ShellState.toggleProcesses();
            break;
        case "pomodoro":
            Pomodoro.toggle();
            break;
        case "cheatsheet":
            ShellState.toggleCheatsheet();
            break;
        case "profiles":
            ProfileService.cycle();
            break;
        case "automation":
            ShellState.toggleAutomation();
            break;
        case "ai":
            ShellState.toggleAi();
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
        ipcProc.command = ["qs", "ipc", "call", target].concat(fn.split(/\s+/));
        ipcProc.running = true;
    }

    function _dispatchShell(cmd) {
        shellProc.command = ["sh", "-c", cmd.trim()];
        shellProc.running = true;
    }

    function _dispatchTheme(schemeId) {
        Theme.applyPreset(schemeId.trim());
    }

    Process {
        id: ipcProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: shellProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
}
