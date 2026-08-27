pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.common

// Dock — logic layer for the bottom dock (PH.09). The per-screen visuals live
// in DockBar.qml; everything user-facing funnels through here so keybinds,
// CLI and the dock UI share one implementation. Runs OFF by default
// (ShellState.dockEnabled); the dock only spawns when enabled.
Singleton {
    id: root

    // pinned desktop-entry ids, parsed with fallback
    readonly property var pins: {
        try {
            const arr = JSON.parse(ShellState.dockPins);
            if (Array.isArray(arr))
                return arr.map(String);
        } catch (e) {}
        return [];
    }

    function pin(id) {
        const i = String(id);
        if (root.pins.indexOf(i) >= 0)
            return;
        ShellState.set("dockPins", JSON.stringify(root.pins.concat([i])));
    }

    function unpin(id) {
        const i = String(id);
        ShellState.set("dockPins", JSON.stringify(root.pins.filter(p => p !== i)));
    }

    function isPinned(id) {
        return root.pins.indexOf(String(id)) >= 0;
    }

    function toggleEnabled() {
        ShellState.set("dockEnabled", !ShellState.dockEnabled);
    }

    // ---- window <-> app mapping ----------------------------------------
    function appIdOf(tl) {
        if (!tl)
            return "";
        return tl.wayland?.appId || tl.lastIpcObject?.class || "";
    }

    // PH.04.3: pinned windows (visible on all workspaces)
    readonly property var pinnedWindows: {
        try {
            const arr = JSON.parse(ShellState.pinnedWindows);
            if (Array.isArray(arr))
                return arr.map(String);
        } catch (e) {}
        return [];
    }

    function pinWindow(addr) {
        const a = String(addr);
        if (root.pinnedWindows.indexOf(a) >= 0)
            return;
        ShellState.set("pinnedWindows", JSON.stringify(root.pinnedWindows.concat([a])));
    }

    function unpinWindow(addr) {
        const a = String(addr);
        ShellState.set("pinnedWindows", JSON.stringify(root.pinnedWindows.filter(x => x !== a)));
    }

    function isWindowPinned(addr) {
        return root.pinnedWindows.indexOf(String(addr)) >= 0;
    }

    function toggleWindowPin(addr) {
        if (root.isWindowPinned(addr))
            root.unpinWindow(addr);
        else
            root.pinWindow(addr);
    }

    // active app id = the class/appId of the focused toplevel (activeToplevel
    // never populates on this build — use per-toplevel `activated`)
    function activeAppId() {
        const vals = Hyprland.toplevels.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].activated)
                return root.appIdOf(vals[i]);
        }
        return "";
    }

    // windows (addresses) of an app, in stable order
    function windowsOf(appId) {
        const out = [];
        const vals = Hyprland.toplevels.values;
        for (let i = 0; i < vals.length; i++) {
            if (root.appIdOf(vals[i]) === appId)
                out.push(vals[i]);
        }
        return out;
    }

    // resolve a desktop entry for an app id; null when none exists
    function entryFor(appId) {
        let e = DesktopEntries.byId(appId);
        if (!e)
            e = DesktopEntries.heuristicLookup(appId);
        return e;
    }

    // merged model: pinned apps (order preserved) then running-only apps.
    // Each entry: { id, name, iconUrl, pinned, running, windows: int }
    readonly property var apps: {
        const out = [];
        const seen = {};
        const pinArr = root.pins;
        for (let i = 0; i < pinArr.length; i++) {
            const id = pinArr[i];
            const e = root.entryFor(id);
            const wins = root.windowsOf(id);
            seen[id] = true;
            out.push({
                "id": id,
                "name": e ? e.name : id,
                "iconSrc": e ? (e.icon || "") : "",
                "pinned": true,
                "running": wins.length > 0,
                "windows": wins.length
            });
        }
        // running apps not already pinned
        const vals = Hyprland.toplevels.values;
        for (let i = 0; i < vals.length; i++) {
            const appId = root.appIdOf(vals[i]);
            if (!appId || seen[appId])
                continue;
            seen[appId] = true;
            const e = root.entryFor(appId);
            const wins = root.windowsOf(appId);
            out.push({
                "id": appId,
                "name": e ? e.name : appId,
                "iconSrc": e ? (e.icon || "") : "",
                "pinned": false,
                "running": true,
                "windows": wins.length
            });
        }
        return out;
    }

    function isActive(appId) {
        return root.activeAppId() === appId;
    }

    function isRunning(appId) {
        return root.windowsOf(appId).length > 0;
    }

    // ---- actions ---------------------------------------------------------
    // focus a specific window by address
    function focusAddress(addr) {
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + String(addr) + '" })');
    }

    // launch the app fresh
    function launch(appId) {
        const e = root.entryFor(appId);
        if (e)
            e.execute();
    }

    // left-click cycle: launch → focus → minimize (hide to special:magic)
    function click(appId) {
        const wins = root.windowsOf(appId);
        if (wins.length === 0) {
            root.launch(appId);
            return;
        }
        if (!root.isActive(appId)) {
            root.focusAddress(wins[0].address);
            return;
        }
        // active → minimize (hide to the special:magic workspace); with several
        // windows, stash them ALL — otherwise every click just swaps which
        // window is visible in a focus/minimize loop
        if (wins.length > 1) {
            for (let i = 0; i < wins.length; i++) {
                root.focusAddress(wins[i].address);
                Hyprland.dispatch('hl.dsp.window.move({ workspace = "special:magic" })');
            }
            return;
        }
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "special:magic" })');
    }

    // middle-click: always a fresh instance
    function newInstance(appId) {
        root.launch(appId);
    }

    // scroll: cycle focus across the app's windows
    function cycle(appId, dir) {
        const wins = root.windowsOf(appId);
        if (wins.length < 2)
            return;
        const cur = root.activeAppId() === appId ? wins.find(w => w.activated) : null;
        let idx = 0;
        if (cur) {
            idx = wins.indexOf(cur);
            idx = (idx + (dir > 0 ? 1 : -1) + wins.length) % wins.length;
        } else if (dir < 0) {
            idx = wins.length - 1;
        }
        root.focusAddress(wins[idx].address);
    }

    // close every window of an app (focus + close, one address at a time)
    function closeAll(appId) {
        const wins = root.windowsOf(appId);
        for (let i = 0; i < wins.length; i++) {
            root.focusAddress(wins[i].address);
            Hyprland.dispatch('hl.dsp.window.close()');
        }
    }

    // keyboard/CLI focus-next-window for alt-tab style switching (PH.10 shares this)
    function focusNextWindow() {
        const vals = Hyprland.toplevels.values;
        if (vals.length < 2)
            return;
        const cur = vals.find(v => v.activated);
        const idx = cur ? vals.indexOf(cur) : -1;
        const next = vals[(idx + 1) % vals.length];
        root.focusAddress(next.address);
    }

    Component.onCompleted: {
        // Quickshell's Hyprland models auto-update from the event socket once
        // populated; force the initial population so the dock renders on boot.
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
    }
}
