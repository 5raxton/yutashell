import Quickshell
import Quickshell.Io
import qs.theme
import qs.modules.common
import "modules/bar"
import "modules/bar/ui"
import "modules/settings"
import "modules/picker"
import "modules/launcher"
import "modules/notify"
import "modules/net"

ShellRoot {
    Tooltip {
        id: tooltip
    }

    // one bar window per connected screen; instances appear/disappear with
    // monitor hot-plug
    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData

            screen: modelData
            tip: tooltip
        }
    }

    SettingsPanel {}

    WallpaperPicker {}

    AppLauncher {}

    ToastStack {}

    NotificationCenter {}

    NetworkPanel {}

    BluetoothPanel {}

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            ShellState.toggleLauncher();
        }

        function open(): void {
            ShellState.openLauncher();
        }

        function close(): void {
            ShellState.closeLauncher();
        }
    }

    IpcHandler {
        target: "panel"

        function toggle(): void {
            console.log("[ipc] panel.toggle hit");
            ShellState.togglePanel();
        }

        function open(): void {
            console.log("[ipc] panel.open hit");
            ShellState.openPanel();
        }

        function close(): void {
            console.log("[ipc] panel.close hit");
            ShellState.closePanel();
        }
    }

    IpcHandler {
        target: "scheme"

        function set(name: string): void {
            Theme.setFollowWallpaper(false);
            Theme.applyPreset(String(name));
        }

        function list(): string {
            return Theme.presets.map(p => p.id).join(" ");
        }

        function wallpaper(): void {
            Theme.setFollowWallpaper(true);
        }
    }

    IpcHandler {
        target: "theme"

        function generate(image: string): void {
            Wallpaper.apply(String(image));
        }

        function dark(mode: string): void {
            const m = String(mode).toLowerCase();
            if (m === "on")
                Theme.setDark(true);
            else if (m === "off")
                Theme.setDark(false);
            else
                Theme.setDark(!Theme.dark);
        }

        function accent(color: string): void {
            Theme.setAccent(String(color));
        }
    }

    IpcHandler {
        target: "picker"

        function toggle(): void {
            ShellState.togglePicker();
        }

        function open(): void {
            ShellState.openPicker();
        }

        function close(): void {
            ShellState.closePicker();
        }
    }

    IpcHandler {
        target: "dnd"

        function toggle(): void {
            Notify.toggleDnd();
        }

        function on(): void {
            Notify.setDnd(true);
        }

        function off(): void {
            Notify.setDnd(false);
        }

        function status(): string {
            return (Notify.dnd ? "on" : "off") + " · suppressed " + Notify.suppressedCount + " · history " + Notify.history.length;
        }
    }

    IpcHandler {
        target: "notifycenter"

        function toggle(): void {
            ShellState.toggleNotifyCenter();
        }

        function open(): void {
            ShellState._exclusive("notifycenter");
        }

        function close(): void {
            ShellState.closeNotifyCenter();
        }

        function clear(): void {
            Notify.clearAll();
            Notify.clearHistory();
        }

        function test(urgency: string): void {
            const u = String(urgency).toLowerCase();
            const lvl = u === "critical" ? "critical" : u === "low" ? "low" : "normal";
            Quickshell.execDetached(["notify-send", "-a", "yutashell", "-u", lvl, u === "critical" ? "CRITICAL TEST" : "test toast", "body line for the " + u + " test notification"]);
        }
    }

    IpcHandler {
        target: "network"

        function toggle(): void {
            ShellState.toggleNet();
        }

        function open(): void {
            ShellState._exclusive("net");
        }

        function close(): void {
            ShellState.closeNet();
        }
    }

    IpcHandler {
        target: "bluetooth"

        function toggle(): void {
            ShellState.toggleBt();
        }

        function open(): void {
            ShellState._exclusive("bt");
        }

        function close(): void {
            ShellState.closeBt();
        }
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            Wallpaper.apply(String(path));
        }

        function next(): void {
            Wallpaper.applyNext();
        }

        function random(): void {
            Wallpaper.applyRandom();
        }

        function list(): string {
            return Wallpaper.entries.map(e => e.path).join("\n");
        }
    }

    IpcHandler {
        target: "templates"

        function list(): string {
            return Wallpaper.templatesList().map(t => (t.enabled ? "[x] " : "[ ] ") + t.id + " — " + t.label + " (" + t.group + ")").join("\n");
        }

        function on(name: string): void {
            Wallpaper.setTemplateEnabled(String(name), true);
        }

        function off(name: string): void {
            Wallpaper.setTemplateEnabled(String(name), false);
        }

        function add(id: string, input: string, output: string): void {
            Wallpaper.addTemplate(String(id), String(input), String(output), "");
        }

        function remove(name: string): void {
            Wallpaper.removeTemplate(String(name));
        }
    }
}
