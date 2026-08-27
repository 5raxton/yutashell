pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Hyprland
import qs.modules.common
import "../session"
import "../notify"

// ProfileService — project profiles (PH.02). One-switch workspace contexts:
// bundles wallpaper, apps, power profile, DND, bar layout, and night light
// into a single named profile that can be applied or saved from live state.
Singleton {
    id: root

    // parsed profile list from ShellState
    readonly property var profiles: {
        try {
            const p = JSON.parse(ShellState.profiles);
            return Array.isArray(p) ? p : [];
        } catch (e) { return []; }
    }

    // id of the currently active profile (persisted across applies within a
    // session, reset on boot)
    property string activeId: ""

    // the active profile object (or null)
    readonly property var activeProfile: {
        if (root.activeId.length === 0) return null;
        return root.profiles.find(p => p.id === root.activeId) ?? null;
    }

    // shortcut: current profile name for the bar chip
    readonly property string activeName: {
        const ap = root.activeProfile;
        return ap ? ap.name : "";
    }

    // apply a profile by id — switches wallpaper, launches apps, sets power
    // profile, DND, bar layout, and night light
    function apply(id) {
        const p = root.profiles.find(x => x.id === id);
        if (!p) return false;

        // 1. wallpaper
        if (p.wallpaper && p.wallpaper.length > 0)
            Wallpaper.apply(p.wallpaper);

        // 2. launch apps (DesktopEntries heuristic lookup → execute)
        if (Array.isArray(p.apps)) {
            for (let i = 0; i < p.apps.length; i++) {
                const entry = DesktopEntries.heuristicLookup(p.apps[i]);
                if (entry) entry.execute();
            }
        }

        // 3. power profile
        if (p.powerProfile && Session.ppdAvailable) {
            const names = { "saver": 0, "power-saver": 0, "balanced": 1, "performance": 2 };
            const idx = names[p.powerProfile];
            if (idx !== undefined) PowerProfiles.profile = idx;
        }

        // 4. DND
        if (typeof p.dnd === "boolean")
            Notify.setDnd(p.dnd);

        // 5. bar layout
        if (p.barPreset && p.barPreset.length > 0)
            BarSegments.applyPreset(p.barPreset);

        // 6. night light
        if (typeof p.nlActive === "boolean")
            NightLight.setActive(p.nlActive);

        root.activeId = id;
        return true;
    }

    // save current live state as a new profile (or overwrite an existing one)
    function save(id, name) {
        const profile = {
            id: id || _genId(),
            name: name || "Profile " + (root.profiles.length + 1),
            icon: "◆",
            wallpaper: Wallpaper.current || "",
            apps: _runningAppIds(),
            powerProfile: Session.ppdAvailable
                ? ["saver", "balanced", "performance"][PowerProfiles.profile] ?? "balanced"
                : "balanced",
            dnd: Notify.dnd,
            barPreset: "",
            nlActive: NightLight.active
        };

        let list = root.profiles.slice();
        const existing = list.findIndex(x => x.id === profile.id);
        if (existing >= 0)
            list[existing] = profile;
        else
            list.push(profile);

        ShellState.set("profiles", JSON.stringify(list));
        root.activeId = profile.id;
        return profile;
    }

    // delete a profile by id
    function deleteProfile(id) {
        const list = root.profiles.filter(x => x.id !== id);
        ShellState.set("profiles", JSON.stringify(list));
        if (root.activeId === id)
            root.activeId = "";
    }

    // rename a profile
    function rename(id, newName) {
        let list = root.profiles.slice();
        const p = list.find(x => x.id === id);
        if (p) {
            p.name = newName;
            ShellState.set("profiles", JSON.stringify(list));
        }
    }

    // cycle to the next profile (bar chip click)
    function cycle() {
        const list = root.profiles;
        if (list.length === 0) return;
        const curIdx = list.findIndex(x => x.id === root.activeId);
        const nextIdx = (curIdx + 1) % list.length;
        root.apply(list[nextIdx].id);
    }

    // internal: generate a unique profile id
    function _genId() {
        return "p" + Date.now().toString(36);
    }

    // internal: get desktop-entry ids of currently running apps
    function _runningAppIds() {
        const ids = [];
        const seen = {};
        const toplevels = Hyprland.toplevels.values ?? [];
        for (let i = 0; i < toplevels.length; i++) {
            const tl = toplevels[i];
            const appId = tl.wayland?.appId || tl.lastIpcObject?.class || "";
            if (appId.length > 0 && !seen[appId]) {
                seen[appId] = true;
                ids.push(appId);
            }
        }
        return ids;
    }
}
