// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Braxton
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import qs.theme
import qs.modules.common
import "modules/bar"
import "modules/bar/ui"
import "modules/settings"
import "modules/picker"
import "modules/launcher"
import "modules/notify"
import "modules/net"
import "modules/audio"

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

    AudioPanel {}

    MediaWidget {}

    Osd {}

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
        target: "audio"

        function toggle(): void {
            ShellState.toggleAudio();
        }

        function open(): void {
            ShellState._exclusive("audio");
        }

        function close(): void {
            ShellState.closeAudio();
        }

        function volup(): void {
            AudioService.stepPct(AudioService.sink, 5);
            AudioService.osdPing("volume");
        }

        function voldown(): void {
            AudioService.stepPct(AudioService.sink, -5);
            AudioService.osdPing("volume");
        }

        function mute(): void {
            const m = AudioService.toggleMute(AudioService.sink);
            AudioService.osdPing(m ? "mic" : "volume");
        }

        function micmute(): void {
            const m = AudioService.toggleMute(AudioService.source);
            AudioService.osdPing("mic");
            void m;
        }

        function status(): string {
            return (AudioService.sink ? AudioService.deviceLabel(AudioService.sink) : "no sink") + " · " + (AudioService.nodePct(AudioService.sink)) + "%" + (AudioService.sink && AudioService.sink.audio && AudioService.sink.audio.muted ? " MUTED" : "");
        }

        function nl(): void {
            NightLight.toggle();
        }

        function nltemp(t: int): void {
            NightLight.temp = t;
            if (!NightLight.active)
                NightLight.toggle();
        }
    }

    IpcHandler {
        target: "display"

        function bright(pct: int): void {
            DisplayService.setBright(Math.max(0, Math.min(100, pct)));
        }
    }

    IpcHandler {
        target: "media"

        function toggle(): void {
            ShellState.toggleMedia();
        }

        function close(): void {
            ShellState.closeMedia();
        }

        function playpause(): void {
            const p = (Mpris.players.values ?? []).find(p => p.isPlaying) ?? (Mpris.players.values ?? [])[0] ?? null;
            if (p && p.canTogglePlaying)
                p.togglePlaying();
        }

        function next(): void {
            const p = (Mpris.players.values ?? []).find(p => p.isPlaying) ?? (Mpris.players.values ?? [])[0] ?? null;
            if (p && p.canGoNext)
                p.next();
        }

        function previous(): void {
            const p = (Mpris.players.values ?? []).find(p => p.isPlaying) ?? (Mpris.players.values ?? [])[0] ?? null;
            if (p && p.canGoPrevious)
                p.previous();
        }
    }

    IpcHandler {
        target: "brightness"

        function up(): void {
            DisplayService.setBright(DisplayService.brightPct + 10);
            AudioService.osdPing("bright");
        }

        function down(): void {
            DisplayService.setBright(DisplayService.brightPct - 10);
            AudioService.osdPing("bright");
        }

        function set(v: string): void {
            DisplayService.setBright(parseInt(v));
            AudioService.osdPing("bright");
        }

        function status(): string {
            return DisplayService.available ? "ddcutil · " + DisplayService.displays.length + " display(s) · " + DisplayService.brightPct + "%" : "unavailable (install ddcutil)";
        }
    }

    IpcHandler {
        target: "nightlight"

        function toggle(): void {
            NightLight.toggle();
        }

        function on(): void {
            NightLight.start();
        }

        function off(): void {
            NightLight.stop();
        }

        function temp(k: string): void {
            NightLight.temp = Math.max(1000, Math.min(6500, parseInt(k)));
        }

        function status(): string {
            return NightLight.available ? (NightLight.active ? "active · " : "idle · ") + NightLight.temp + "K" : "unavailable (install hyprsunset)";
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
