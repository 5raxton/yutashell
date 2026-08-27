pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Bluetooth
import QtQuick
import qs.theme
import qs.modules.common
import "../net"
import "../audio"
import "../session"
import "../widgets"
import "../profiles"
import "../automation"
import "../dev"
import "../focus"
import "../system"

// BarSegments — the bar's segment model (PH.14). Parses the persisted ordered
// array [{id, zone, enabled}] from ShellState and answers the bar's layout
// questions: which segments live in each zone, which are currently visible
// (enabled AND their runtime condition holds), and what click-action each
// carries. Settings' BAR tab drives the same functions for enable/reorder.
Singleton {
    id: root

    readonly property var meta: {
        const base = {
            "identity": { label: "Identity", jp: "識別" },
            "workspaces": { label: "Workspaces", jp: "作業場" },
            "taskbar": { label: "Taskbar", jp: "任務" },
            "activewindow": { label: "Active window", jp: "窓" },
            "tray": { label: "System tray", jp: "盤" },
            "media": { label: "Media ticker", jp: "媒" },
            "net": { label: "Network chip", jp: "網" },
            "bt": { label: "Bluetooth chip", jp: "歯" },
            "audio": { label: "Audio chip", jp: "音" },
            "stats": { label: "Stats (legacy)", jp: "計" },
            "cpu": { label: "CPU load", jp: "算" },
            "mem": { label: "Memory", jp: "憶" },
            "bat": { label: "Battery", jp: "電" },
            "cputemp": { label: "CPU temp", jp: "熱" },
            "gpu": { label: "GPU", jp: "画" },
            "disk": { label: "Disk IO", jp: "盤" },
            "nightlight": { label: "Night light chip", jp: "夜" },
            "session": { label: "Inhibit chip", jp: "阻" },
            "recording": { label: "Recording chip", jp: "録" },
            "mixer": { label: "Mixer", jp: "混" },
            "scratchpad": { label: "Scratchpad", jp: "隠" },
            "pluginwidgets": { label: "Plugin widgets", jp: "拡" },
            "clock": { label: "Clock", jp: "時" },
            "spacer": { label: "Spacer", jp: "余" },
            "pomodoro": { label: "Pomodoro timer", jp: "豆" },
            "cheatsheet": { label: "Keybind cheatsheet", jp: "鍵" },
            "profiles": { label: "Project profiles", jp: "継" },
            "automation": { label: "Automation rules", jp: "働" },
            "git": { label: "Git status", jp: "変" },
            "docker": { label: "Docker", jp: "容" },
            "cicd": { label: "CI/CD", jp: "統" },
            "focus": { label: "Focus & wellness", jp: "集中" },
            "systemmonitor": { label: "System monitor", jp: "監" },
            "snapshots": { label: "Session snapshots", jp: "写" }
        };
        // merge bar plugin segments
        const bps = PluginService.enabledBarPlugins;
        for (let i = 0; i < bps.length; i++) {
            const mf = bps[i];
            if (mf.barSegment && mf.barSegment.id)
                base[mf.barSegment.id] = {
                    label: mf.barSegment.label || mf.name,
                    jp: mf.barSegment.jp || ""
                };
        }
        return base;
    }

    // persisted model, parsed with fallback to the default order; legacy
    // monolithic "stats" segments are expanded into cpu/mem/bat in place
    readonly property var model: {
        let v = null;
        try {
            const p = JSON.parse(ShellState.barSegments);
            if (Array.isArray(p) && p.length > 0)
                v = p;
        } catch (e) {}
        if (!v)
            return defaultModel;
        const out = [];
        for (let i = 0; i < v.length; i++) {
            const s = v[i];
            if (s.id === "stats") {
                out.push({
                        id: "cpu",
                        zone: s.zone,
                        enabled: s.enabled !== false
                    }, {
                        id: "mem",
                        zone: s.zone,
                        enabled: s.enabled !== false
                    }, {
                        id: "bat",
                        zone: s.zone,
                        enabled: s.enabled !== false
                    });
            } else {
                out.push(s);
            }
        }
        return out;
    }

    readonly property var defaultModel: [
        { id: "identity", zone: "left", enabled: true },
        { id: "workspaces", zone: "left", enabled: true },
        { id: "taskbar", zone: "left", enabled: false },
        { id: "activewindow", zone: "center", enabled: true },
        { id: "tray", zone: "right", enabled: true },
        { id: "media", zone: "right", enabled: true },
        { id: "net", zone: "right", enabled: true },
        { id: "bt", zone: "right", enabled: true },
        { id: "audio", zone: "right", enabled: true },
        { id: "cpu", zone: "right", enabled: true },
        { id: "mem", zone: "right", enabled: true },
        { id: "bat", zone: "right", enabled: true },
        { id: "cputemp", zone: "right", enabled: false },
        { id: "gpu", zone: "right", enabled: false },
        { id: "disk", zone: "right", enabled: false },
        { id: "nightlight", zone: "right", enabled: true },
        { id: "session", zone: "right", enabled: true },
        { id: "recording", zone: "right", enabled: true },
        { id: "mixer", zone: "right", enabled: false },
        { id: "pluginwidgets", zone: "right", enabled: false },
        { id: "profiles", zone: "right", enabled: false },
        { id: "automation", zone: "right", enabled: false },
        { id: "git", zone: "right", enabled: false },
        { id: "docker", zone: "right", enabled: false },
        { id: "cicd", zone: "right", enabled: false },
        { id: "focus", zone: "right", enabled: false },
        { id: "systemmonitor", zone: "right", enabled: false },
        { id: "snapshots", zone: "right", enabled: false },
        { id: "clock", zone: "right", enabled: true }
    ]

    function enabled(id) {
        const s = root.model.find(x => x.id === id);
        return s ? s.enabled !== false : false;
    }

    // a segment's zone (its persisted zone, or its meta default)
    function zoneOf(id) {
        const s = root.model.find(x => x.id === id);
        return s ? s.zone : "right";
    }

    function zoneList(zone) {
        return root.model.filter(s => s.zone === zone);
    }

    // runtime visibility: enabled AND the underlying condition holds
    // compact mode restricts to identity + workspaces + clock
    function present(id) {
        if (!root.enabled(id))
            return false;
        if (ShellState.barCompact && root.compactIds.indexOf(id) < 0)
            return false;
        // bar plugin segments are always present when enabled
        if (PluginService._barPluginMap[id])
            return true;
        switch (id) {
        case "media":
            return (Mpris.players.values ?? []).length > 0;
        case "bt": {
            const a = Bluetooth.defaultAdapter;
            return a !== null && a.enabled;
        }
        case "nightlight":
            return NightLight.active;
        case "session":
            return Session.inhibitCount > 0 || IdleInhibitor.inhibited;
        case "recording":
            return Recording.active;
        case "mixer":
            return MixerService.ready;
        case "scratchpad":
            return Overview.scratchWindows.length > 0;
        case "pluginwidgets":
            return PluginService.enabledWidgets.length > 0;
        case "pomodoro":
            return Pomodoro.phase !== "idle";
        case "cheatsheet":
            return true;
        case "profiles":
            return ProfileService.activeName.length > 0;
        case "automation":
            return RuleService.rules.some(r => r.enabled);
        case "git":
            return GitService.isRepo && GitService.dirty > 0;
        case "docker":
            return DockerService.projects.length > 0;
        case "cicd":
            return CIService.runs.length > 0;
        case "focus":
            return FocusMode.phase !== "idle";
        default:
            return true;
        }
    }

    // compact mode: only identity, workspaces, clock
    readonly property var compactIds: ["identity", "workspaces", "clock", "pomodoro", "cheatsheet", "focus"]

    // the ordered list of visible segment ids for a zone
    readonly property var leftVisible: root._visible("left")
    readonly property var rightVisible: root._visible("right")
    readonly property var centerVisible: root._visible("center")

    function _visible(zone) {
        return root.zoneList(zone).filter(s => root.present(s.id));
    }

    // click action for a segment id, with defaults merged over the pref
    readonly property var defaultClick: ({
            "clock": "calendar",
            "net": "network",
            "bt": "bluetooth",
            "audio": "audio",
            "media": "media",
            "cpu": "controlcenter",
            "mem": "controlcenter",
            "bat": "controlcenter",
            "cputemp": "controlcenter",
            "gpu": "controlcenter",
            "disk": "controlcenter",
            "identity": "settings",
            "nightlight": "nightlight",
            "session": "power",
            "mixer": "mixer",
            "scratchpad": "scratchpad",
            "pomodoro": "pomodoro",
            "cheatsheet": "cheatsheet",
            "profiles": "profiles",
            "automation": "automation",
            "git": "dev",
            "docker": "dev",
            "cicd": "dev",
            "focus": "focus",
            "systemmonitor": "systemmonitor",
            "snapshots": "snapshots",
            "tray": "",
            "workspaces": "",
            "taskbar": ""
        })

    function clickFor(id) {
        try {
            const map = JSON.parse(ShellState.barClick);
            if (map[id])
                return map[id];
        } catch (e) {}
        return root.defaultClick[id] ?? "";
    }

    // ---- mutations (settings BAR tab drives these) ----
    function setEnabled(id, on) {
        const list = root.model.map(s => s.id === id ? {
                    id: s.id,
                    zone: s.zone,
                    enabled: on
                } : s);
        ShellState.set("barSegments", JSON.stringify(list));
    }

    function setZone(id, zone) {
        const list = root.model.map(s => s.id === id ? {
                    id: s.id,
                    zone: zone,
                    enabled: s.enabled !== false
                } : s);
        ShellState.set("barSegments", JSON.stringify(list));
    }

    // free reorder across the whole model — the segment's zone travels with
    // it, so stepping over a zone boundary relocates the segment too
    function move(id, delta) {
        const ids = root.model.map(s => s.id);
        const idx = ids.indexOf(id);
        const j = idx + delta;
        if (idx < 0 || j < 0 || j >= ids.length)
            return;
        ids.splice(idx, 1);
        ids.splice(j, 0, id);
        const byId = {};
        for (const s of root.model)
            byId[s.id] = s;
        ShellState.set("barSegments", JSON.stringify(ids.map(x => ({
                        id: x,
                        zone: byId[x].zone,
                        enabled: byId[x].enabled !== false
                    }))));
    }

    function reset() {
        ShellState.set("barSegments", JSON.stringify(root.defaultModel));
    }

    function setClick(id, action) {
        let map = {};
        try {
            map = JSON.parse(ShellState.barClick);
        } catch (e) {}
        if (action.length === 0)
            delete map[id];
        else
            map[id] = action;
        ShellState.set("barClick", JSON.stringify(map));
    }

    function addSpacer() {
        let maxN = 0;
        for (const s of root.model) {
            if (s.id.startsWith("spacer-")) {
                const n = parseInt(s.id.substring(7));
                if (!isNaN(n) && n > maxN)
                    maxN = n;
            }
        }
        const newId = "spacer-" + (maxN + 1);
        const list = [];
        for (const s of root.model)
            list.push({ id: s.id, zone: s.zone, enabled: s.enabled !== false });
        list.push({ id: newId, zone: "right", enabled: true });
        ShellState.set("barSegments", JSON.stringify(list));
    }

    function removeSpacer(id) {
        if (!id.startsWith("spacer-"))
            return;
        const list = [];
        for (const s of root.model) {
            if (s.id !== id)
                list.push({ id: s.id, zone: s.zone, enabled: s.enabled !== false });
        }
        ShellState.set("barSegments", JSON.stringify(list));
    }

    function labelFor(id) {
        if (id.startsWith("spacer-"))
            return "Spacer";
        return (root.meta[id] ?? {}).label ?? id;
    }

    // ---- layout presets (PH.07) ----
    readonly property var layoutPresets: [
        { id: "minimal", label: "MINIMAL", desc: "Identity + workspaces + clock", barScale: 0.8, barPosition: "top", wsMode: "default", segments: [{"id":"identity","zone":"left","enabled":true},{"id":"workspaces","zone":"left","enabled":true},{"id":"taskbar","zone":"left","enabled":false},{"id":"activewindow","zone":"center","enabled":false},{"id":"tray","zone":"right","enabled":false},{"id":"media","zone":"right","enabled":false},{"id":"net","zone":"right","enabled":false},{"id":"bt","zone":"right","enabled":false},{"id":"audio","zone":"right","enabled":false},{"id":"cpu","zone":"right","enabled":false},{"id":"mem","zone":"right","enabled":false},{"id":"bat","zone":"right","enabled":false},{"id":"cputemp","zone":"right","enabled":false},{"id":"gpu","zone":"right","enabled":false},{"id":"disk","zone":"right","enabled":false},{"id":"nightlight","zone":"right","enabled":false},{"id":"session","zone":"right","enabled":false},{"id":"recording","zone":"right","enabled":false},{"id":"mixer","zone":"right","enabled":false},{"id":"pluginwidgets","zone":"right","enabled":false},{"id":"profiles","zone":"right","enabled":false},{"id":"automation","zone":"right","enabled":false},{"id":"git","zone":"right","enabled":false},{"id":"docker","zone":"right","enabled":false},{"id":"cicd","zone":"right","enabled":false},{"id":"focus","zone":"right","enabled":false},{"id":"systemmonitor","zone":"right","enabled":false},{"id":"snapshots","zone":"right","enabled":false},{"id":"clock","zone":"right","enabled":true}] },
        { id: "classic", label: "CLASSIC", desc: "Full bar: all widgets visible", barScale: 1.0, barPosition: "top", wsMode: "default", segments: [{"id":"identity","zone":"left","enabled":true},{"id":"workspaces","zone":"left","enabled":true},{"id":"taskbar","zone":"left","enabled":true},{"id":"activewindow","zone":"center","enabled":true},{"id":"tray","zone":"right","enabled":true},{"id":"media","zone":"right","enabled":true},{"id":"net","zone":"right","enabled":true},{"id":"bt","zone":"right","enabled":true},{"id":"audio","zone":"right","enabled":true},{"id":"cpu","zone":"right","enabled":true},{"id":"mem","zone":"right","enabled":true},{"id":"bat","zone":"right","enabled":true},{"id":"cputemp","zone":"right","enabled":false},{"id":"gpu","zone":"right","enabled":false},{"id":"disk","zone":"right","enabled":false},{"id":"nightlight","zone":"right","enabled":true},{"id":"session","zone":"right","enabled":true},{"id":"recording","zone":"right","enabled":true},{"id":"mixer","zone":"right","enabled":false},{"id":"pluginwidgets","zone":"right","enabled":false},{"id":"profiles","zone":"right","enabled":false},{"id":"automation","zone":"right","enabled":false},{"id":"git","zone":"right","enabled":false},{"id":"docker","zone":"right","enabled":false},{"id":"cicd","zone":"right","enabled":false},{"id":"focus","zone":"right","enabled":false},{"id":"systemmonitor","zone":"right","enabled":false},{"id":"snapshots","zone":"right","enabled":false},{"id":"clock","zone":"right","enabled":true}] },
        { id: "macos", label: "MACOS", desc: "Centered dock-style layout", barScale: 1.0, barPosition: "top", wsMode: "pills", segments: [{"id":"identity","zone":"left","enabled":false},{"id":"workspaces","zone":"center","enabled":true},{"id":"taskbar","zone":"left","enabled":false},{"id":"activewindow","zone":"center","enabled":true},{"id":"tray","zone":"right","enabled":false},{"id":"media","zone":"right","enabled":false},{"id":"net","zone":"right","enabled":false},{"id":"bt","zone":"right","enabled":false},{"id":"audio","zone":"right","enabled":false},{"id":"cpu","zone":"right","enabled":false},{"id":"mem","zone":"right","enabled":false},{"id":"bat","zone":"right","enabled":false},{"id":"cputemp","zone":"right","enabled":false},{"id":"gpu","zone":"right","enabled":false},{"id":"disk","zone":"right","enabled":false},{"id":"nightlight","zone":"right","enabled":false},{"id":"session","zone":"right","enabled":false},{"id":"recording","zone":"right","enabled":false},{"id":"mixer","zone":"right","enabled":false},{"id":"pluginwidgets","zone":"right","enabled":false},{"id":"profiles","zone":"right","enabled":false},{"id":"automation","zone":"right","enabled":false},{"id":"git","zone":"right","enabled":false},{"id":"docker","zone":"right","enabled":false},{"id":"cicd","zone":"right","enabled":false},{"id":"focus","zone":"right","enabled":false},{"id":"systemmonitor","zone":"right","enabled":false},{"id":"snapshots","zone":"right","enabled":false},{"id":"clock","zone":"center","enabled":true}] },
        { id: "gnome", label: "GNOME", desc: "Workspaces + clock, right tray", barScale: 1.0, barPosition: "top", wsMode: "numbers", segments: [{"id":"identity","zone":"left","enabled":false},{"id":"workspaces","zone":"left","enabled":true},{"id":"taskbar","zone":"left","enabled":false},{"id":"activewindow","zone":"center","enabled":false},{"id":"tray","zone":"right","enabled":true},{"id":"media","zone":"right","enabled":true},{"id":"net","zone":"right","enabled":true},{"id":"bt","zone":"right","enabled":false},{"id":"audio","zone":"right","enabled":true},{"id":"cpu","zone":"right","enabled":false},{"id":"mem","zone":"right","enabled":false},{"id":"bat","zone":"right","enabled":true},{"id":"cputemp","zone":"right","enabled":false},{"id":"gpu","zone":"right","enabled":false},{"id":"disk","zone":"right","enabled":false},{"id":"nightlight","zone":"right","enabled":false},{"id":"session","zone":"right","enabled":false},{"id":"recording","zone":"right","enabled":false},{"id":"mixer","zone":"right","enabled":false},{"id":"pluginwidgets","zone":"right","enabled":false},{"id":"profiles","zone":"right","enabled":false},{"id":"automation","zone":"right","enabled":false},{"id":"git","zone":"right","enabled":false},{"id":"docker","zone":"right","enabled":false},{"id":"cicd","zone":"right","enabled":false},{"id":"focus","zone":"right","enabled":false},{"id":"systemmonitor","zone":"right","enabled":false},{"id":"snapshots","zone":"right","enabled":false},{"id":"clock","zone":"right","enabled":true}] },
        { id: "developer", label: "DEVELOPER", desc: "Stats: CPU, mem, net, disk, temp", barScale: 1.0, barPosition: "top", wsMode: "default", segments: [{"id":"identity","zone":"left","enabled":true},{"id":"workspaces","zone":"left","enabled":true},{"id":"taskbar","zone":"left","enabled":true},{"id":"activewindow","zone":"center","enabled":true},{"id":"tray","zone":"right","enabled":true},{"id":"media","zone":"right","enabled":false},{"id":"net","zone":"right","enabled":true},{"id":"bt","zone":"right","enabled":false},{"id":"audio","zone":"right","enabled":false},{"id":"cpu","zone":"right","enabled":true},{"id":"mem","zone":"right","enabled":true},{"id":"bat","zone":"right","enabled":true},{"id":"cputemp","zone":"right","enabled":true},{"id":"gpu","zone":"right","enabled":true},{"id":"disk","zone":"right","enabled":true},{"id":"nightlight","zone":"right","enabled":false},{"id":"session","zone":"right","enabled":true},{"id":"recording","zone":"right","enabled":false},{"id":"mixer","zone":"right","enabled":false},{"id":"pluginwidgets","zone":"right","enabled":false},{"id":"profiles","zone":"right","enabled":false},{"id":"automation","zone":"right","enabled":false},{"id":"git","zone":"right","enabled":false},{"id":"docker","zone":"right","enabled":false},{"id":"cicd","zone":"right","enabled":false},{"id":"focus","zone":"right","enabled":false},{"id":"systemmonitor","zone":"right","enabled":false},{"id":"snapshots","zone":"right","enabled":false},{"id":"clock","zone":"right","enabled":true}] },
        { id: "gaming", label: "GAMING", desc: "Workspaces + media + session + clock", barScale: 1.0, barPosition: "top", wsMode: "default", segments: [{"id":"identity","zone":"left","enabled":false},{"id":"workspaces","zone":"left","enabled":true},{"id":"taskbar","zone":"left","enabled":false},{"id":"activewindow","zone":"center","enabled":false},{"id":"tray","zone":"right","enabled":false},{"id":"media","zone":"right","enabled":true},{"id":"net","zone":"right","enabled":false},{"id":"bt","zone":"right","enabled":false},{"id":"audio","zone":"right","enabled":false},{"id":"cpu","zone":"right","enabled":false},{"id":"mem","zone":"right","enabled":false},{"id":"bat","zone":"right","enabled":true},{"id":"cputemp","zone":"right","enabled":false},{"id":"gpu","zone":"right","enabled":false},{"id":"disk","zone":"right","enabled":false},{"id":"nightlight","zone":"right","enabled":false},{"id":"session","zone":"right","enabled":true},{"id":"recording","zone":"right","enabled":true},{"id":"mixer","zone":"right","enabled":false},{"id":"pluginwidgets","zone":"right","enabled":false},{"id":"profiles","zone":"right","enabled":false},{"id":"automation","zone":"right","enabled":false},{"id":"git","zone":"right","enabled":false},{"id":"docker","zone":"right","enabled":false},{"id":"cicd","zone":"right","enabled":false},{"id":"focus","zone":"right","enabled":false},{"id":"systemmonitor","zone":"right","enabled":false},{"id":"snapshots","zone":"right","enabled":false},{"id":"clock","zone":"right","enabled":true}] },
        { id: "ultraminimal", label: "ULTRA-MINIMAL", desc: "Clock only", barScale: 0.8, barPosition: "top", wsMode: "default", segments: [{"id":"identity","zone":"left","enabled":false},{"id":"workspaces","zone":"left","enabled":false},{"id":"taskbar","zone":"left","enabled":false},{"id":"activewindow","zone":"center","enabled":false},{"id":"tray","zone":"right","enabled":false},{"id":"media","zone":"right","enabled":false},{"id":"net","zone":"right","enabled":false},{"id":"bt","zone":"right","enabled":false},{"id":"audio","zone":"right","enabled":false},{"id":"cpu","zone":"right","enabled":false},{"id":"mem","zone":"right","enabled":false},{"id":"bat","zone":"right","enabled":false},{"id":"cputemp","zone":"right","enabled":false},{"id":"gpu","zone":"right","enabled":false},{"id":"disk","zone":"right","enabled":false},{"id":"nightlight","zone":"right","enabled":false},{"id":"session","zone":"right","enabled":false},{"id":"recording","zone":"right","enabled":false},{"id":"mixer","zone":"right","enabled":false},{"id":"pluginwidgets","zone":"right","enabled":false},{"id":"profiles","zone":"right","enabled":false},{"id":"automation","zone":"right","enabled":false},{"id":"git","zone":"right","enabled":false},{"id":"docker","zone":"right","enabled":false},{"id":"cicd","zone":"right","enabled":false},{"id":"focus","zone":"right","enabled":false},{"id":"systemmonitor","zone":"right","enabled":false},{"id":"snapshots","zone":"right","enabled":false},{"id":"clock","zone":"center","enabled":true}] }
    ]

    function applyPreset(id) {
        const p = root.layoutPresets.find(x => x.id === id);
        if (!p) {
            let customs = [];
            try { customs = JSON.parse(ShellState.customPresets); if (!Array.isArray(customs)) customs = []; } catch (e) {}
            const c = customs.find(x => x.id === id);
            if (!c) return false;
            ShellState.set("barSegments", JSON.stringify(c.segments));
            ShellState.set("barScale", c.barScale);
            ShellState.set("barPosition", c.barPosition);
            ShellState.set("wsMode", c.wsMode);
            return true;
        }
        ShellState.set("barSegments", JSON.stringify(p.segments));
        ShellState.set("barScale", p.barScale);
        ShellState.set("barPosition", p.barPosition);
        ShellState.set("wsMode", p.wsMode);
        return true;
    }

    function presetIds() {
        return root.layoutPresets.map(p => p.id);
    }

    function abbrFor(id) {
        const map = {
            "identity": "ID", "workspaces": "WS", "taskbar": "TB",
            "activewindow": "AW", "tray": "TR", "media": "MD", "net": "NT",
            "bt": "BT", "audio": "AU", "cpu": "C", "mem": "M", "bat": "B",
            "cputemp": "T", "gpu": "G", "disk": "D", "nightlight": "NL",
            "session": "INK",         "recording": "REC",
        "mixer": "MX",
        "pluginwidgets": "PW",
        "profiles": "PR",
        "automation": "AU",
        "git": "GIT",
        "docker": "DKR",
        "cicd": "CI",
        "focus": "FOC",
        "systemmonitor": "SYS",
        "snapshots": "SNP",
            "clock": "CK"
        };
        if (id.startsWith("spacer-"))
            return "···";
        return map[id] ?? id.substring(0, 3).toUpperCase();
    }
}
