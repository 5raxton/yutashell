// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Braxton
import QtQuick
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
import "modules/session"
import "modules/dock"
import "modules/overview"
import "modules/widgets"
import "modules/control"

ShellRoot {
    Tooltip {
        id: tooltip
    }

    // Warm the lazy singleton services at boot so their binary probes run now
    // rather than on the first IPC call (which would race the async probe and
    // report "unavailable" for a beat).
    Timer {
        interval: 0
        running: true
        repeat: false
        onTriggered: {
            void Updates.available;
            void Recording.available;
            void ColorPicker.available;
            void Weather.available;
            void Clipboard.available;
            void SystemStats.hostname;
        }
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

    LockScreen {}

    PowerMenu {}

    PolkitDialog {}

    // one dock per connected screen (PH.09 — OFF by default, enables via IPC
    // or the PH.16 dock tab); each instance shows only its own screen's windows
    Variants {
        model: Quickshell.screens

        DockBar {
            required property var modelData
        }
    }

    OverviewGrid {}

    AltTab {}

    // PH.11 widgets — each degrades gracefully when its backend is absent
    Calendar {}

    ClipboardPanel {}

    WeatherPanel {}

    ShotFlash {}

    Emoji {}

    ControlCenter {}

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
        target: "overview"

        function toggle(): void {
            Overview.toggleGrid();
        }

        function open(): void {
            Overview.openGrid();
        }

        function close(): void {
            Overview.closeGrid();
            Overview.cancelAltTab();
        }

        function alttab(): void {
            Overview.cycleAltTab(1);
        }

        function scratchpad(): void {
            Overview.toggleScratchpad();
        }

        function scratchsend(): void {
            Overview.sendToScratchpad();
        }

        function tile(preset: string): void {
            Overview.tile(String(preset));
        }

        function status(): string {
            return "windows " + Overview.windows.length + " · workspaces " + Overview.workspaces.length;
        }
    }

    IpcHandler {
        target: "dock"

        function toggle(): void {
            Dock.toggleEnabled();
        }

        function enable(): void {
            ShellState.set("dockEnabled", true);
        }

        function disable(): void {
            ShellState.set("dockEnabled", false);
        }

        function pin(id: string): void {
            Dock.pin(String(id));
        }

        function unpin(id: string): void {
            Dock.unpin(String(id));
        }

        function hide(mode: string): string {
            const m = String(mode).toLowerCase();
            if (["never", "dodge", "always"].indexOf(m) < 0)
                return "bad mode: never|dodge|always";
            ShellState.set("dockHide", m);
            return "hide " + m;
        }

        function mode(m: string): string {
            const m2 = String(m).toLowerCase();
            if (["overlay", "exclusive"].indexOf(m2) < 0)
                return "bad mode: overlay|exclusive";
            ShellState.set("dockMode", m2);
            return "mode " + m2;
        }

        function status(): string {
            return (ShellState.dockEnabled ? "on" : "off") + " · " + ShellState.dockMode + " · hide " + ShellState.dockHide + " · pins " + Dock.pins.length;
        }
    }

    IpcHandler {
        target: "notify"

        function show(app: string, sum: string, body: string): void {
            Notify.announce(String(sum), String(body), 1);
            void app;
        }
    }

    IpcHandler {
        target: "session"

        function toggle(): void {
            ShellState.toggleSession();
        }

        function open(): void {
            ShellState._exclusive("session");
        }

        function close(): void {
            ShellState.closeSession();
        }

        function lock(): void {
            Session.lock();
        }

        function logout(): void {
            Session.fire("logout");
        }

        function suspend(): void {
            Session.fire("suspend");
        }

        function hibernate(): void {
            Session.fire("hibernate");
        }

        function reboot(): void {
            Session.fire("reboot");
        }

        function poweroff(): void {
            Session.fire("poweroff");
        }

        function profile(name: string): string {
            if (!name || String(name).toLowerCase() === "cycle") {
                Session.cycleProfile();
            } else {
                Session.setProfile(String(name));
            }
            return Session.ppdAvailable ? Session.profileName : "unavailable (power-profiles-daemon)";
        }

        function idle(action: string, secs: string): string {
            const a = String(action).toLowerCase();
            if (["none", "lock", "suspend", "shutdown"].indexOf(a) < 0)
                return "bad action: use none|lock|suspend|shutdown";
            ShellState.set("idleAction", a);
            const n = parseInt(secs);
            if (n > 0)
                ShellState.set("idleSecs", n);
            return a + " after " + ShellState.idleSecs + "s";
        }

        function status(): string {
            return (Session.locked ? "LOCKED" : "unlocked") + " · inhibitors " + Session.inhibitCount + " · profile " + (Session.ppdAvailable ? Session.profileName : "n/a") + " · idle " + ShellState.idleAction + "/" + ShellState.idleSecs + "s";
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

    IpcHandler {
        target: "calendar"

        function toggle(): void {
            ShellState.toggleCalendar();
        }

        function open(): void {
            ShellState.openCalendar();
        }

        function close(): void {
            ShellState.closeCalendar();
        }
    }

    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            ShellState.toggleClipboard();
        }

        function open(): void {
            ShellState.openClipboard();
        }

        function close(): void {
            ShellState.closeClipboard();
        }

        function status(): string {
            return Clipboard.available ? Clipboard.entries.length + " entries" : "unavailable (install cliphist)";
        }
    }

    IpcHandler {
        target: "weather"

        function toggle(): void {
            ShellState.toggleWeather();
        }

        function open(): void {
            ShellState.openWeather();
        }

        function close(): void {
            ShellState.closeWeather();
        }

        function set(lat: string, lon: string, label: string): void {
            ShellState.set("weatherLat", String(lat));
            ShellState.set("weatherLon", String(lon));
            ShellState.set("weatherLabel", String(label ?? ""));
            Weather.refresh();
        }

        function refresh(): void {
            Weather.refresh();
        }

        function status(): string {
            return Weather.configured ? "configured · " + (Weather.current ? Weather.current.temp + "°" : "no data") : "no location set";
        }
    }

    IpcHandler {
        target: "shot"

        function region(): void {
            Screenshot.capture("region");
        }

        function full(): void {
            Screenshot.capture("full");
        }

        function window(): void {
            Screenshot.capture("window");
        }

        function copy(): void {
            Screenshot.copyLast();
        }

        function dir(): string {
            return Screenshot.status();
        }
    }

    IpcHandler {
        target: "updates"

        function check(): void {
            Updates.refresh();
        }

        function list(): string {
            return Updates.available ? (Updates.packages.length > 0 ? Updates.packages.join("\n") : "up to date") : "unavailable (install pacman-contrib)";
        }

        function open(): void {
            Updates.openTerminal();
        }

        function status(): string {
            return Updates.status();
        }
    }

    IpcHandler {
        target: "recording"

        function stop(): void {
            Recording.stop();
        }

        function status(): string {
            return Recording.available ? (Recording.active ? "recording" : "idle") : "unavailable (install gpu-screen-recorder)";
        }
    }

    IpcHandler {
        target: "colorpicker"

        function pick(): void {
            ColorPicker.pick();
        }
    }

    IpcHandler {
        target: "emoji"

        function toggle(): void {
            ShellState.toggleEmoji();
        }

        function open(): void {
            ShellState.openEmoji();
        }

        function close(): void {
            ShellState.closeEmoji();
        }
    }

    IpcHandler {
        target: "bar"

        function seg(id: string, op: string): string {
            const sid = String(id);
            const o = String(op).toLowerCase();
            if (["on", "off"].indexOf(o) >= 0)
                BarSegments.setEnabled(sid, o === "on");
            else if (["left", "center", "right"].indexOf(o) >= 0)
                BarSegments.setZone(sid, o);
            else
                return "usage: bar seg <id> on|off|left|center|right";
            return o + " " + sid;
        }

        function move(id: string, dir: string): void {
            BarSegments.move(String(id), String(dir) === "up" ? -1 : 1);
        }

        function scale(v: string): string {
            const s = Math.max(0.8, Math.min(1.4, parseFloat(v) || 1.0));
            ShellState.set("barScale", s);
            return "scale " + s;
        }

        function position(p: string): string {
            const v = String(p).toLowerCase();
            ShellState.set("barPosition", v === "bottom" ? "bottom" : "top");
            return "position " + (v === "bottom" ? "bottom" : "top");
        }

        function click(id: string, action: string): void {
            BarSegments.setClick(String(id), String(action ?? ""));
        }

        function status(): string {
            return "scale " + ShellState.barScale + " · " + ShellState.barPosition + " · " + BarSegments.leftVisible.length + "/" + BarSegments.rightVisible.length + " visible";
        }
    }

    IpcHandler {
        target: "cc"

        function toggle(): void {
            ShellState.toggleCc();
        }

        function open(): void {
            ShellState.openCc();
        }

        function close(): void {
            ShellState.closeCc();
        }
    }
}
