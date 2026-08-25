pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.common

// Overview — compositor navigation superpowers (PH.10): workspace grid,
// alt-tab switcher, scratchpad control and quick-tile presets. Window MRU
// order is tracked from Hyprland `activewindow` events; the visual surfaces
// live in OverviewGrid.qml and AltTab.qml.
Singleton {
    id: root

    // ---- MRU window order (most-recent-first) ----------------------------
    property var mru: []

    function _bump(addr) {
        const a = String(addr);
        if (!a)
            return;
        root.mru = [a].concat(root.mru.filter(x => x !== a));
        if (root._live)
            root._refresh();
    }

    // windows/workspaces are rebuilt IMPERATIVELY (never as bindings): a
    // binding over Hyprland.toplevels re-runs O(windows × desktop-entry
    // lookups) on every title churn — every keystroke in a browser — even
    // with no surface open. While closed we simply stop refreshing.
    property var windows: []
    property var workspaces: []

    // live while any consumer surface can see the data
    readonly property bool _live: ShellState.overviewOpen || ShellState.altTabOpen

    on_LiveChanged: _refresh()

    function _refresh() {
        const vals = Hyprland.toplevels.values;
        const byAddr = {};
        for (let i = 0; i < vals.length; i++)
            byAddr[String(vals[i].address)] = vals[i];
        const out = [];
        const seen = {};
        // mru order first
        for (let i = 0; i < root.mru.length; i++) {
            const tl = byAddr[root.mru[i]];
            if (!tl)
                continue;
            seen[String(tl.address)] = true;
            out.push(root._desc(tl));
        }
        // then anything the model knows that we haven't seen
        for (let i = 0; i < vals.length; i++) {
            if (seen[String(vals[i].address)])
                continue;
            out.push(root._desc(vals[i]));
        }
        root.windows = out;

        const wvals = Hyprland.workspaces.values;
        const wsOut = [];
        for (let i = 0; i < wvals.length; i++) {
            const ws = wvals[i];
            if (ws.id < 1)
                continue;
            wsOut.push({
                "id": ws.id,
                "name": ws.name,
                "focused": ws.focused === true,
                "windows": root._wsWindows(ws.id)
            });
        }
        wsOut.sort((a, b) => a.id - b.id);
        root.workspaces = wsOut;
    }

    function _desc(tl) {
        const appId = tl.wayland?.appId || tl.lastIpcObject?.class || "";
        const e = root._entry(appId);
        return {
            "address": String(tl.address),
            "title": tl.title || appId,
            "appId": appId,
            "name": e ? e.name : (appId || "window"),
            "iconSrc": e ? (e.icon || "") : "",
            "workspace": tl.workspace ? tl.workspace.id : -1,
            "workspaceName": tl.workspace ? tl.workspace.name : "",
            "activated": tl.activated === true
        };
    }

    function _entry(appId) {
        // desktop-entry resolution is the expensive half of _desc — memoize
        // per app id for the session
        if (root._entryCache.hasOwnProperty(appId))
            return root._entryCache[appId];
        let e = DesktopEntries.byId(appId);
        if (!e)
            e = DesktopEntries.heuristicLookup(appId);
        root._entryCache[appId] = e;
        return e;
    }

    property var _entryCache: ({})

    // ---- workspaces -------------------------------------------------------
    function _wsWindows(id) {
        const out = [];
        const vals = Hyprland.toplevels.values;
        for (let i = 0; i < vals.length; i++) {
            if (vals[i].workspace && vals[i].workspace.id === id) {
                const d = root._desc(vals[i]);
                out.push(d);
            }
        }
        return out;
    }

    // ---- grid state -------------------------------------------------------
    function toggleGrid() {
        ShellState.toggleOverview();
    }

    function openGrid() {
        ShellState._exclusive("overview");
    }

    function closeGrid() {
        ShellState.closeOverview();
    }

    function jumpWorkspace(id) {
        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })');
        root.closeGrid();
    }

    function moveWindowToWorkspace(addr, id) {
        root.focusAddress(addr);
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + id + '" })');
    }

    // ---- alt-tab ----------------------------------------------------------
    readonly property int altTabIdx: root._altTabIndex

    property int _altTabIndex: 0

    function openAltTab() {
        ShellState._exclusive("alttab");
        root._altTabIndex = root.windows.length > 1 ? 1 : 0;
    }

    function cycleAltTab(dir) {
        if (!ShellState.altTabOpen) {
            root.openAltTab();
            return;
        }
        const n = root.windows.length;
        if (n < 2)
            return;
        root._altTabIndex = (root._altTabIndex + (dir > 0 ? 1 : -1) + n) % n;
    }

    function commitAltTab() {
        const n = root.windows.length;
        if (n === 0) {
            ShellState.closeAltTab();
            return;
        }
        const idx = ((root._altTabIndex % n) + n) % n;
        const w = root.windows[idx];
        if (w)
            root.focusAddress(w.address);
        ShellState.closeAltTab();
    }

    function selectAltTab(idx) {
        root._altTabIndex = idx;
        root.commitAltTab();
    }

    function cancelAltTab() {
        ShellState.closeAltTab();
    }

    // ---- scratchpad (special:magic) --------------------------------------
    // NOTE (PH.07 live verification): hl.dsp.workspace.toggle_special(),
    // focus({ workspace = "special:*" }) and raw 'togglespecialworkspace'
    // are ALL inert under this Helmsman build — the ONLY working channel
    // into/out of special:magic is window.move(). Toggle therefore acts on
    // the focused window: hide it to magic, or pull it back out.
    function toggleScratchpad() {
        const focused = Hyprland.toplevels.values.find(t => t.activated);
        if (!focused)
            return;
        const onMagic = Number(focused.workspace?.id ?? 0) < 0
                || String(focused.workspace?.name ?? "") === "magic";
        Hyprland.dispatch(onMagic
            ? 'hl.dsp.window.move({ workspace = "previous" })'
            : 'hl.dsp.window.move({ workspace = "special:magic" })');
    }

    function sendToScratchpad() {
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "special:magic" })');
    }

    // ---- focus helpers ----------------------------------------------------
    function focusAddress(addr) {
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + String(addr) + '" })');
    }

    function closeAddress(addr) {
        root.focusAddress(addr);
        Hyprland.dispatch('hl.dsp.window.close()');
    }

    // ---- quick-tile presets (floating-layout helpers) ---------------------
    function tile(preset) {
        switch (String(preset).toLowerCase()) {
        case "float":
            Hyprland.dispatch('hl.dsp.window.float({ action = "toggle" })');
            break;
        case "fullscreen":
            Hyprland.dispatch('hl.dsp.window.fullscreen()');
            break;
        case "pseudo":
            Hyprland.dispatch('hl.dsp.window.pseudo()');
            break;
        case "center":
            Hyprland.dispatch('hl.dsp.window.float({ action = "toggle" })');
            Hyprland.dispatch('hl.dsp.window.center()');
            break;
        case "left":
        case "right":
        case "top":
        case "bottom":
            root._halfTile(String(preset).toLowerCase());
            break;
        }
    }

    // half-tile: float the focused window then move+resize into a screen half
    function _halfTile(edge) {
        const m = Hyprland.focusedMonitor;
        const w = m ? m.width : 1920;
        const h = m ? m.height : 1080;
        const halfW = Math.round(w / 2);
        const halfH = Math.round(h / 2);
        const pos = {
            "left": [0, 0, halfW, h],
            "right": [halfW, 0, halfW, h],
            "top": [0, 0, w, halfH],
            "bottom": [0, halfH, w, halfH]
        }[edge];
        Hyprland.dispatch('hl.dsp.window.float({ action = "set" })');
        Hyprland.dispatch('hl.dsp.window.resize({ x = ' + pos[2] + ', y = ' + pos[3] + ' })');
        Hyprland.dispatch('hl.dsp.window.move({ x = ' + pos[0] + ', y = ' + pos[1] + ' })');
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
        Hyprland.rawEvent.connect(evt => {
            const n = String(evt.name || "");
            if (n === "activewindow" || n === "activewindowv2") {
                const data = String(evt.data || "").trim();
                const addr = data.split(",")[0]?.trim();
                if (addr)
                    root._bump(addr);
            }
        });
    }
}
