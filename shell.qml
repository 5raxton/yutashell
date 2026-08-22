import Quickshell
import Quickshell.Io
import qs.theme
import qs.modules.common
import "modules/bar"
import "modules/bar/ui"
import "modules/settings"

ShellRoot {
    Tooltip {
        id: tooltip
    }

    Bar {
        tip: tooltip
    }

    SettingsPanel {}

    IpcHandler {
        target: "panel"

        function toggle(): void {
            ShellState.togglePanel();
        }

        function open(): void {
            ShellState.openPanel();
        }

        function close(): void {
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
    }

    IpcHandler {
        target: "wallpaper"

        function set(path: string): void {
            Wallpaper.apply(String(path));
        }

        function next(): void {
            Wallpaper.applyNext();
        }

        function list(): string {
            return Wallpaper.entries.map(e => e.path).join("\n");
        }
    }

    IpcHandler {
        target: "templates"

        function list(): string {
            return Wallpaper.templatesList().map(t => (t.enabled ? "[x] " : "[ ] ") + t.id).join("\n");
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
