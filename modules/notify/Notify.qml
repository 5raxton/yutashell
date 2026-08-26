pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import qs.modules.common

Singleton {
    id: root

    // ---- runtime (not persisted) ----
    property int suppressedCount: 0
    property var live: [] // ToastEntry objects, newest first
    property var history: []
    property int seq: 1

    // PH.03.3: snooze — suppresses non-critical toasts for N minutes
    property real _snoozeUntil: 0 // timestamp (ms); 0 = not snoozed
    readonly property bool snoozed: Date.now() < _snoozeUntil
    readonly property int snoozeRemaining: Math.max(0, Math.round((_snoozeUntil - Date.now()) / 60000))

    // PH.03.1: toast dedup — same-app toasts within 3s window update existing card
    property var _recentApps: ({}) // { appName: { count, lastId, timestamp } }

    // PH.03.1: grouped history — expanded state for notification center
    property var _expandedApps: ({})

    function toggleGroup(app) {
        const copy = Object.assign({}, _expandedApps);
        copy[app] = !copy[app];
        _expandedApps = copy;
    }

    function isGroupExpanded(app) {
        return _expandedApps[app] === true;
    }

    // incremental stack sync — ToastStack mirrors these into an ObjectModel so
    // cards are created/removed individually instead of every array identity
    // change resetting the whole Repeater (which replayed entrances and broke
    // hover-pause under a stationary cursor)
    signal toastAdded(var vm)
    signal toastRemoved(var vm)
    signal toastUpdated(var vmId, var count)

    readonly property bool dnd: ShellState.notifyDnd
    readonly property int maxVisible: Math.max(1, Math.min(6, ShellState.notifyMaxVisible))

    readonly property var fields: {
        try {
            const f = JSON.parse(ShellState.notifyFields);
            return {
                "app": f.app !== false,
                "body": f.body !== false,
                "icon": f.icon !== false,
                "time": f.time !== false
            };
        } catch (e) {
            return {
                "app": true,
                "body": true,
                "icon": true,
                "time": true
            };
        }
    }

    readonly property var overrides: {
        try {
            const o = JSON.parse(ShellState.notifyPerApp);
            return Array.isArray(o) ? o : [];
        } catch (e) {
            return [];
        }
    }

    onDndChanged: if (!root.dnd)
        root.suppressedCount = 0;

    Component.onCompleted: root._loadHistory()

    component Entry: QtObject {
        property var n: null // live Notification ref (null for replays)
        property bool dead: false // server-side close already happened
        property bool alive: true // cleared right before destroy() in Notify
        property bool leaving: false // exit ceremony playing; hard close queued
        property int id: 0
        property string app: ""
        property string icon: ""
        property string sum: ""
        property string body: ""
        property int urg: 1
        property real durMs: -1
        property real remainMs: -1
        property var acts: []
        property bool paused: false
        property int count: 1 // PH.03.1: dedup badge count
        readonly property bool persistent: durMs <= 0
        readonly property bool hasInlineReply: n ? n.hasInlineReply : false
        readonly property string inlineReplyPlaceholder: n ? n.inlineReplyPlaceholder : ""
    }

    function _loadHistory() {
        try {
            const h = JSON.parse(ShellState.notifyHistory);
            root.history = Array.isArray(h) ? h : [];
        } catch (e) {
            root.history = [];
        }
    }

    function setFields(patch) {
        const f = Object.assign({}, root.fields);
        for (const k in patch)
            f[k] = patch[k] === true;
        ShellState.set("notifyFields", JSON.stringify(f));
    }

    function addOverride(match, mode) {
        const m = String(match).replace(/^\s+/, "").replace(/\s+$/, "");
        if (m.length === 0)
            return false;
        const list = root.overrides.filter(o => o.match.toLowerCase() !== m.toLowerCase());
        list.push({
            "match": m,
            "mode": mode === "block" ? "block" : "quiet"
        });
        ShellState.set("notifyPerApp", JSON.stringify(list));
        return true;
    }

    function removeOverride(index) {
        const list = root.overrides.filter((_, i) => i !== index);
        ShellState.set("notifyPerApp", JSON.stringify(list));
    }

    function setOverrideMode(index, mode) {
        const list = root.overrides.map((o, i) => i === index ? {
                    "match": o.match,
                    "mode": mode === "block" ? "block" : "quiet"
                } : o);
        ShellState.set("notifyPerApp", JSON.stringify(list));
    }

    function setDnd(on_) {
        ShellState.set("notifyDnd", on_ === true);
    }

    function toggleDnd() {
        root.setDnd(!root.dnd);
    }

    function setTimeoutSec(s) {
        ShellState.set("notifyTimeout", Math.max(0, Math.min(120, Math.round(s))));
    }

    function setMaxVisible(n) {
        ShellState.set("notifyMaxVisible", Math.max(1, Math.min(6, Math.round(n))));
        root._trimLive();
    }

    function setCorner(c) {
        ShellState.set("notifyCorner", c === "tl" ? "tl" : "tr");
    }

    // mode resolution: app-name / desktop-entry substring, case-insensitive
    function modeFor(appName, desktopEntry) {
        for (let i = 0; i < root.overrides.length; i++) {
            const m = String(root.overrides[i].match || "").toLowerCase();
            if (m.length === 0)
                continue;
            if ((String(appName).toLowerCase().indexOf(m) >= 0) || (String(desktopEntry).toLowerCase().indexOf(m) >= 0))
                return root.overrides[i].mode;
        }
        return "";
    }

    function _urgencyOf(n) {
        return n.urgency === NotificationUrgency.Critical ? 2 : n.urgency === NotificationUrgency.Low ? 0 : 1;
    }

    function effectiveTimeoutMs(n, urg) {
        if (urg === 2)
            return -1; // critical persists until dismissed
        const cfgMs = ShellState.notifyTimeout * 1000;
        const clientMs = n.expireTimeout > 0 ? n.expireTimeout : -1;
        let eff;
        if (cfgMs <= 0)
            eff = clientMs;
        else if (clientMs < 0)
            eff = cfgMs;
        else
            eff = Math.min(clientMs, cfgMs);
        // close ourselves slightly before the server-side timer does —
        // losing the race means expiring an already-destroyed object
        return eff > 400 ? eff - 300 : eff;
    }

    function _receive(n) {
        const app = String(n.appName.length > 0 ? n.appName : n.desktopEntry.length > 0 ? n.desktopEntry : "unknown");
        const urg = root._urgencyOf(n);
        const mode = root.modeFor(app, n.desktopEntry);

        if (mode === "block")
            return; // never tracked -> closed immediately

        const acts = [];
        for (let i = 0; i < n.actions.length; i++) {
            const a = n.actions[i];
            acts.push({
                "id": a.identifier,
                "text": a.text,
                "ref": null
            });
        }

        const suppressed = urg < 2 && (root.dnd || mode === "quiet");

        // PH.03.3: snooze suppresses non-critical toasts
        if (suppressed || (root.snoozed && urg < 2)) {
            root.suppressedCount += 1;
            return;
        }

        root._record({
            "t": Date.now(),
            "app": app,
            "icon": String(n.appIcon),
            "sum": String(n.summary),
            "body": String(n.body),
            "urg": urg,
            "acts": acts.map(a => ({
                        "id": a.id,
                        "text": a.text
                    })),
            "sup": suppressed
        });

        if (suppressed) {
            root.suppressedCount += 1;
            return;
        }

        n.tracked = true;

        // PH.03.1: toast dedup — same-app within 3s window bumps count
        const now = Date.now();
        const recent = root._recentApps[app];
        if (recent && (now - recent.timestamp) < 3000) {
            recent.count += 1;
            recent.timestamp = now;
            root._recentApps = Object.assign({}, root._recentApps);
            root.toastUpdated(recent.lastId, recent.count);
            return;
        }
        const entryId = root.seq++;
        root._recentApps = Object.assign({}, root._recentApps, {
            [app]: { count: 1, lastId: entryId, timestamp: now }
        });

        const vm = entryComp.createObject(root, {
                "n": n,
                "id": entryId,
                "app": app,
                "icon": String(n.appIcon),
                "sum": String(n.summary),
                "body": String(n.body),
                "urg": urg,
                "durMs": root.effectiveTimeoutMs(n, urg)
            });
        vm.remainMs = vm.durMs > 0 ? vm.durMs : -1;
        for (let i = 0; i < n.actions.length && i < vm.acts.length; i++)
            vm.acts[i].ref = n.actions[i];
        // the server may close its side first (client timeout) — mark dead so
        // we never expire/dismiss a closed object. The wrapper can already be
        // destroyed by _trimLive by the time this fires; guard against that.
        // (no `destroyed` signal access: this build doesn't expose it on
        // inline-component QtObjects — aliveness is tracked explicitly)
        n.closed.connect(() => {
            if (!vm.alive)
                return;
            vm.dead = true;
        });
        root.live = [vm].concat(root.live).slice();
        root.toastAdded(vm);
        root._trimLive();
    }

    function replay(entry) {
        const urg = entry.urg === undefined ? 1 : entry.urg;
        const durMs = urg === 2 ? -1 : (ShellState.notifyTimeout * 1000 || -1);
        const vm = entryComp.createObject(root, {
                "n": null,
                "id": root.seq++,
                "app": entry.app || "history",
                "icon": entry.icon || "",
                "sum": entry.sum || "",
                "body": entry.body || "",
                "urg": urg,
                "durMs": durMs
            });
        vm.remainMs = vm.durMs > 0 ? vm.durMs : -1;
        root.live = [vm].concat(root.live).slice();
        root.toastAdded(vm);
        root._trimLive();
    }

    // shell-internal announcement (connectivity changes, service states).
    // The machine speaking about itself: bypasses DND, never enters history.
    function announce(sum, body, urg) {
        const vm = entryComp.createObject(root, {
                "n": null,
                "id": root.seq++,
                "app": "YUTA",
                "icon": "",
                "sum": String(sum || ""),
                "body": String(body || ""),
                "urg": urg === 2 ? 2 : 1,
                "durMs": 4000
            });
        vm.remainMs = vm.durMs;
        root.live = [vm].concat(root.live).slice();
        root.toastAdded(vm);
        root._trimLive();
    }

    function _closeVm(vm, expire_) {
        if (!vm.n || vm.dead || !vm.n.tracked)
            return;
        vm.dead = true; // set first: close destroys the object
        try {
            if (expire_)
                vm.n.expire();
            else
                vm.n.dismiss();
        } catch (e) {
            // wrapper outlived the C++ object — nothing to close
        }
    }

    function dismiss(id, expire_) {
        const idx = root.live.findIndex(v => v.id === id);
        if (idx < 0)
            return;
        const vm = root.live[idx];
        root.live = root.live.filter(v => v.id !== id).slice();
        root.toastRemoved(vm);
        root._closeVm(vm, expire_ === true);
        vm.alive = false;
        vm.destroy();
    }

    // visible exit path: flag the card so its delegate plays the send-off,
    // then hard-close after the animation window
    function retire(id, expire_) {
        const vm = root.live.find(v => v.id === id);
        if (!vm || vm.leaving)
            return;
        vm.leaving = true;
        root._retireQueue.push({
            "id": id,
            "expire": expire_ === true
        });
        retireTimer.restart();
    }

    property var _retireQueue: []

    Timer {
        id: retireTimer

        interval: 280
        onTriggered: {
            const q = root._retireQueue;
            root._retireQueue = [];
            q.forEach(r => root.dismiss(r.id, r.expire));
        }
    }

    Timer {
        id: snoozeTimer
        interval: 60000
        repeat: true
        onTriggered: {
            if (Date.now() >= root._snoozeUntil) {
                root.clearSnooze();
                root.announce("Snooze ended", "Notifications restored", 1);
            }
        }
    }

    function invokeAction(id, actId) {
        const vm = root.live.find(v => v.id === id);
        if (!vm)
            return;
        const a = vm.acts.find(x => x.id === actId);
        if (a && a.ref)
            a.ref.invoke();
        root.retire(id);
    }

    function clearAll() {
        const ids = root.live.map(v => v.id);
        ids.forEach(id => root.retire(id));
    }

    function snooze(minutes) {
        root._snoozeUntil = Date.now() + minutes * 60000;
        snoozeTimer.restart();
        console.log("[notify] snoozed for " + minutes + " min until " + new Date(root._snoozeUntil).toLocaleTimeString());
    }

    function clearSnooze() {
        root._snoozeUntil = 0;
        snoozeTimer.stop();
    }

    function _trimLive() {
        while (root.live.length > root.maxVisible) {
            const old = root.live[root.live.length - 1];
            root.live = root.live.slice(0, root.maxVisible).slice();
            root.toastRemoved(old);
            root._closeVm(old, true);
            old.alive = false;
            old.destroy();
        }
    }

    // ---- history ring ----
    function _record(entry) {
        root.history = [entry].concat(root.history).slice(0, 50);
        persistTimer.restart();
    }

    function clearHistory() {
        root.history = [];
        ShellState.set("notifyHistory", "[]");
    }

    function removeHistory(index) {
        root.history = root.history.filter((_, i) => i !== index);
        persistTimer.restart();
    }

    Timer {
        id: persistTimer

        interval: 400
        onTriggered: ShellState.set("notifyHistory", JSON.stringify(root.history.slice(0, 30)))
    }

    // timeout tick: decrements remainMs of every visible card unless paused/persistent
    Timer {
        interval: 100
        running: root.live.some(v => !v.persistent)
        repeat: true
        onTriggered: {
            const due = [];
            root.live.forEach(vm => {
                if (vm.persistent || vm.paused)
                    return;
                vm.remainMs = vm.remainMs - 100;
                if (vm.remainMs <= 0)
                    due.push(vm.id);
            });
            // retire after the scan — retire mutates state via the queue
            due.forEach(id => root.retire(id, true));
        }
    }

    NotificationServer {
        keepOnReload: false
        persistenceSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        bodyImagesSupported: true
        actionsSupported: true
        actionIconsSupported: true
        imageSupported: true

        onNotification: n => {
            // toast stack lands where attention was at arrival, then stays put
            FocusMonitor.latch();
            root._receive(n);
        }
    }

    Component {
        id: entryComp

        Entry {}
    }
}
