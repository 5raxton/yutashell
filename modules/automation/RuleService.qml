pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import QtQuick
import qs.modules.common
import "../session"
import "../notify"
import "../net"
import "../widgets"
import "../audio"
import "../profiles"

// RuleService — automation rules engine (PH.03). Declarative triggers + actions:
// "When X happens, do Y." Rules are persisted in ShellState and evaluated via a
// 30-second timer for time-based triggers and event-driven Connections for
// reactive triggers (battery, network, temperature, recording, focused app).
Singleton {
    id: root

    // persisted rules
    readonly property var rules: {
        try {
            const r = JSON.parse(ShellState.automationRules);
            return Array.isArray(r) ? r : [];
        } catch (e) { return []; }
    }

    // last time each rule was fired (id → timestamp), prevents re-fire within 60s
    property var _lastFired: ({})

    // focused app state for focusedApp triggers
    property string _focusedApp: ""

    // idle tracker
    property real _lastActivity: Date.now()

    signal ruleFired(string ruleId, string ruleName)

    // ---- CRUD ----

    function create(name, trigger, actions) {
        const rule = {
            id: "r" + Date.now().toString(36),
            name: name || "New Rule",
            trigger: trigger || { type: "time", config: { hour: 9, minute: 0, days: [] } },
            actions: actions || [],
            enabled: true
        };
        let list = root.rules.slice();
        list.push(rule);
        ShellState.set("automationRules", JSON.stringify(list));
        return rule;
    }

    function update(id, patch) {
        let list = root.rules.slice();
        const idx = list.findIndex(r => r.id === id);
        if (idx < 0) return null;
        const old = list[idx];
        list[idx] = Object.assign({}, old, patch);
        if (patch.trigger) list[idx].trigger = Object.assign({}, old.trigger, patch.trigger);
        if (patch.trigger && patch.trigger.config)
            list[idx].trigger.config = Object.assign({}, old.trigger?.config ?? {}, patch.trigger.config);
        if (patch.actions) list[idx].actions = patch.actions.slice();
        ShellState.set("automationRules", JSON.stringify(list));
        return list[idx];
    }

    function remove(id) {
        const list = root.rules.filter(r => r.id !== id);
        ShellState.set("automationRules", JSON.stringify(list));
        delete root._lastFired[id];
    }

    function toggleEnabled(id) {
        let list = root.rules.slice();
        const r = list.find(x => x.id === id);
        if (!r) return;
        r.enabled = !r.enabled;
        ShellState.set("automationRules", JSON.stringify(list));
    }

    function setEnabled(id, on) {
        let list = root.rules.slice();
        const r = list.find(x => x.id === id);
        if (!r || r.enabled === on) return;
        r.enabled = on;
        ShellState.set("automationRules", JSON.stringify(list));
    }

    // test: immediately execute a rule's actions
    function testRule(id) {
        const r = root.rules.find(x => x.id === id);
        if (!r) return false;
        _executeActions(r.actions);
        root.ruleFired(r.id, r.name);
        return true;
    }

    // ---- evaluation engine ----

    function _shouldFire(rule) {
        if (!rule.enabled) return false;
        // cooldown: don't re-fire the same rule within 60 seconds
        const last = root._lastFired[rule.id] ?? 0;
        if (Date.now() - last < 60000) return false;
        const t = rule.trigger;
        if (!t || !t.type) return false;
        const cfg = t.config || {};
        switch (t.type) {
        case "time": return _evalTime(cfg);
        case "battery": return _evalBattery(cfg);
        case "network": return _evalNetwork(cfg);
        case "recording": return _evalRecording(cfg);
        case "temperature": return _evalTemperature(cfg);
        case "focusedApp": return _evalFocusedApp(cfg);
        case "mpris": return _evalMpris(cfg);
        case "idle": return _evalIdle(cfg);
        default: return false;
        }
    }

    function _evalTime(cfg) {
        const now = new Date();
        const h = now.getHours();
        const m = now.getMinutes();
        if (h !== (cfg.hour ?? -1) || m !== (cfg.minute ?? -1)) return false;
        if (Array.isArray(cfg.days) && cfg.days.length > 0) {
            const dow = now.getDay();
            if (cfg.days.indexOf(dow) < 0) return false;
        }
        return true;
    }

    function _evalBattery(cfg) {
        if (!SystemStats.batPresent) return false;
        const pct = SystemStats.batPct;
        const threshold = cfg.threshold ?? 20;
        if (cfg.op === "below") return pct <= threshold;
        if (cfg.op === "above") return pct >= threshold;
        return false;
    }

    function _evalNetwork(cfg) {
        if (cfg.event === "connected") return Connectivity.wifiOn || Connectivity.wiredUp;
        if (cfg.event === "disconnected") return !Connectivity.wifiOn && !Connectivity.wiredUp;
        return false;
    }

    function _evalRecording(cfg) {
        if (cfg.event === "started") return Recording.active;
        if (cfg.event === "stopped") return !Recording.active;
        return false;
    }

    function _evalTemperature(cfg) {
        const temps = SystemStats.temps ?? [];
        let max = 0;
        for (let i = 0; i < temps.length; i++) {
            if (temps[i].temp > max) max = temps[i].temp;
        }
        if (SystemStats.gpuTemp > max) max = SystemStats.gpuTemp;
        const threshold = cfg.threshold ?? 85;
        if (cfg.op === "above") return max >= threshold;
        if (cfg.op === "below") return max <= threshold;
        return false;
    }

    function _evalFocusedApp(cfg) {
        const target = String(cfg.appId ?? "").toLowerCase();
        if (target.length === 0) return false;
        const current = root._focusedApp.toLowerCase();
        if (cfg.event === "gained") return current === target;
        if (cfg.event === "lost") return current !== target;
        if (cfg.event === "changed") return current !== target;
        return false;
    }

    function _evalMpris(cfg) {
        const players = Mpris.players?.values ?? [];
        const playing = players.some(p => p.isPlaying);
        if (cfg.event === "started") return playing;
        if (cfg.event === "stopped") return !playing;
        return false;
    }

    function _evalIdle(cfg) {
        const idleMs = Date.now() - root._lastActivity;
        const thresholdMs = (cfg.seconds ?? 300) * 1000;
        return idleMs >= thresholdMs;
    }

    // ---- action execution ----

    function _executeActions(actions) {
        if (!Array.isArray(actions)) return;
        for (let i = 0; i < actions.length; i++) {
            _execAction(actions[i]);
        }
    }

    function _execAction(action) {
        if (!action || !action.type) return;
        const cfg = action.config || {};
        switch (action.type) {
        case "setProfile":
            ProfileService.apply(String(cfg.id ?? ""));
            break;
        case "setPowerProfile":
            Session.setProfile(String(cfg.name ?? "balanced"));
            break;
        case "toggleDnd":
            Notify.setDnd(cfg.enabled === true);
            break;
        case "runCommand":
            if (cfg.cmd && cfg.cmd.length > 0) {
                _shellProc.command = ["sh", "-c", cfg.cmd];
                _shellProc.running = true;
            }
            break;
        case "notify":
            Notify.announce(String(cfg.title ?? "Automation"), String(cfg.body ?? ""));
            break;
        case "setWallpaper":
            if (cfg.path && cfg.path.length > 0)
                Wallpaper.apply(cfg.path);
            break;
        case "togglePanel":
            BarActions.dispatch(String(cfg.target ?? ""));
            break;
        case "setNightLight":
            NightLight.active = cfg.active === true;
            break;
        case "setBarPreset":
            BarSegments.applyPreset(String(cfg.id ?? ""));
            break;
        }
    }

    // ---- event-driven connections ----

    Connections {
        target: SystemStats
        function onBatPctChanged() { root._tick("battery"); }
        function onBatChargingChanged() { root._tick("battery"); }
        function onThermalWarning() { root._tick("temperature"); }
        function onThermalCritical() { root._tick("temperature"); }
    }

    Connections {
        target: Connectivity
        function onWifiOnChanged() { root._tick("network"); }
        function onWiredUpChanged() { root._tick("network"); }
    }

    Connections {
        target: Recording
        function onActiveChanged() { root._tick("recording"); }
    }

    Connections {
        target: NightLight
        function onActiveChanged() { root._tick("nightlight"); }
    }

    Connections {
        target: Pomodoro
        function onPhaseChanged() { root._tick("pomodoro"); }
    }

    Connections {
        target: Hyprland
        function onRawEvent(evt) {
            if (evt.name === "activewindow") {
                const d = String(evt.data ?? "");
                const idx = d.indexOf(",");
                root._focusedApp = idx > 0 ? d.slice(0, idx) : "";
                root._tick("focusedApp");
            } else if (evt.name === "activewindowv2" && !evt.data) {
                root._focusedApp = "";
                root._tick("focusedApp");
            }
            // any user activity resets the idle timer
            root._lastActivity = Date.now();
        }
    }

    // ---- timer-based evaluation (30s) ----

    function _tick(triggerType) {
        const list = root.rules;
        for (let i = 0; i < list.length; i++) {
            const r = list[i];
            if (!r.enabled) continue;
            if (triggerType && r.trigger?.type !== triggerType) continue;
            if (root._shouldFire(r)) {
                root._lastFired[r.id] = Date.now();
                root._executeActions(r.actions);
                root.ruleFired(r.id, r.name);
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root._tick(null)
    }

    // boot: evaluate once after singletons warm up
    Timer {
        interval: 3000
        running: true
        repeat: false
        onTriggered: root._tick(null)
    }

    // shell command runner
    Process {
        id: _shellProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // ---- starter rules (disabled by default) ----

    Component.onCompleted: {
        if (root.rules.length > 0) return;
        const starters = [
            {
                id: "r_starter_lowsaver",
                name: "Low Battery Saver",
                trigger: { type: "battery", config: { op: "below", threshold: 20 } },
                actions: [
                    { type: "setPowerProfile", config: { name: "saver" } },
                    { type: "toggleDnd", config: { enabled: true } },
                    { type: "notify", config: { title: "Low Battery", body: "Switched to power saver + DND" } }
                ],
                enabled: false
            },
            {
                id: "r_starter_workhours",
                name: "Work Hours",
                trigger: { type: "time", config: { hour: 9, minute: 0, days: [1, 2, 3, 4, 5] } },
                actions: [
                    { type: "setProfile", config: { id: "work" } },
                    { type: "setPowerProfile", config: { name: "balanced" } }
                ],
                enabled: false
            },
            {
                id: "r_starter_nightmode",
                name: "Night Mode",
                trigger: { type: "time", config: { hour: 22, minute: 0, days: [] } },
                actions: [
                    { type: "setNightLight", config: { active: true } },
                    { type: "toggleDnd", config: { enabled: true } }
                ],
                enabled: false
            },
            {
                id: "r_starter_gaming",
                name: "Gaming Mode",
                trigger: { type: "focusedApp", config: { appId: "steam", event: "gained" } },
                actions: [
                    { type: "toggleDnd", config: { enabled: false } },
                    { type: "setNightLight", config: { active: false } },
                    { type: "setPowerProfile", config: { name: "performance" } }
                ],
                enabled: false
            },
            {
                id: "r_starter_recfocus",
                name: "Recording Focus",
                trigger: { type: "recording", config: { event: "started" } },
                actions: [
                    { type: "toggleDnd", config: { enabled: true } }
                ],
                enabled: false
            },
            {
                id: "r_starter_thermal",
                name: "Thermal Throttle",
                trigger: { type: "temperature", config: { op: "above", threshold: 85 } },
                actions: [
                    { type: "setPowerProfile", config: { name: "balanced" } },
                    { type: "notify", config: { title: "Thermal Warning", body: "CPU temp high — switched to balanced" } }
                ],
                enabled: false
            },
            {
                id: "r_starter_morning",
                name: "Morning Wake",
                trigger: { type: "time", config: { hour: 7, minute: 0, days: [1, 2, 3, 4, 5] } },
                actions: [
                    { type: "setPowerProfile", config: { name: "balanced" } },
                    { type: "toggleDnd", config: { enabled: false } },
                    { type: "setNightLight", config: { active: false } }
                ],
                enabled: false
            },
            {
                id: "r_starter_mpris_pause",
                name: "Mute on Media Stop",
                trigger: { type: "mpris", config: { event: "stopped" } },
                actions: [
                    { type: "toggleDnd", config: { enabled: false } }
                ],
                enabled: false
            }
        ];
        ShellState.set("automationRules", JSON.stringify(starters));
    }
}
