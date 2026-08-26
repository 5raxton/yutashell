pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland._IdleNotify
import Quickshell.Services.UPower
import qs.modules.common

// Session — power menu state, system power ops, lock handshake, idle
// management and logind inhibit awareness. All user-facing actions land here
// so the IPC surface, keybinds, power menu tiles and idle timers share one
// implementation.
Singleton {
    id: root

    // ---- runtime state ----
    property bool locked: false
    property bool authBusy: false
    property int authAttempts: 0

    // ---- power-profiles-daemon availability (probed once at boot) ----
    property bool ppdAvailable: false

    // ---- logind inhibitors (bar indicator) ----
    property int inhibitCount: 0

    readonly property var destructiveTiles: new Set(["logout", "suspend", "hibernate", "reboot", "poweroff"])

    // persisted tile order → parsed with sane fallback
    readonly property var tiles: {
        try {
            const arr = JSON.parse(ShellState.sessionTiles);
            if (Array.isArray(arr) && arr.length > 0)
                return arr.filter(id => knownTiles.has(id));
        } catch (e) {}
        return ["lock", "suspend", "hibernate", "reboot", "poweroff", "logout"];
    }
    readonly property var knownTiles: new Set(["lock", "logout", "suspend", "hibernate", "reboot", "poweroff"])

    // lock-screen monitor selection: "all" | "primary" | JSON name array
    readonly property var lockScreens: {
        const mode = ShellState.lockMonitors;
        if (mode === "all" || mode === "primary")
            return mode;
        try {
            const arr = JSON.parse(mode);
            if (Array.isArray(arr))
                return arr.map(String);
        } catch (e) {}
        return "all";
    }

    function lockScreenSelected(screenName) {
        const sel = root.lockScreens;
        if (sel === "primary")
            return Quickshell.screens.length > 0 && Quickshell.screens[0].name === screenName;
        if (Array.isArray(sel))
            return sel.indexOf(screenName) >= 0;
        return true; // all
    }

    // ---- power profile (string-facing convenience over PowerProfiles) ----
    readonly property string profileName: {
        if (!root.ppdAvailable)
            return "";
        return ["saver", "balanced", "performance"][PowerProfiles.profile] ?? "balanced";
    }

    function setProfile(name) {
        const n = String(name).toLowerCase();
        const idx = {
            "saver": 0,
            "power-saver": 0,
            "balanced": 1,
            "performance": 2
        }[n];
        if (idx === undefined || !root.ppdAvailable)
            return false;
        PowerProfiles.profile = idx;
        return true;
    }

    function cycleProfile() {
        const next = (PowerProfiles.profile + 1) % 3;
        const names = ["saver", "balanced", "performance"];
        return root.setProfile(names[next]);
    }

    // ---- actions ----
    function lock() {
        root.authAttempts = 0;
        root.locked = true;
    }

    // LockScreen drives these through its PamContext
    function lockSubmit(password) {
        if (!root.locked || root.authBusy || !authBridge)
            return;
        root.authBusy = true;
        authBridge.submit(String(password));
    }

    function _authDone(ok) {
        root.authBusy = false;
        if (ok) {
            root.authAttempts = 0;
            root.locked = false;
        } else {
            root.authAttempts++;
        }
    }

    // bridge target assigned by LockScreen (keeps PamContext out of the
    // singleton but the handshake state in one place)
    property var authBridge: null

    function openMenu() {
        ShellState._exclusive("session");
    }

    function closeMenu() {
        ShellState.closeSession();
    }

    function toggleMenu() {
        ShellState.toggleSession();
    }

    function fire(tileId) {
        switch (String(tileId)) {
        case "lock":
            closeMenu();
            lock();
            break;
        case "logout":
            logout();
            break;
        case "suspend":
            sysOp("suspend");
            break;
        case "hibernate":
            sysOp("hibernate");
            break;
        case "reboot":
            sysOp("reboot");
            break;
        case "poweroff":
            sysOp("poweroff");
            break;
        }
    }

    // systemctl one-shot; reboot/poweroff go through polkit (agent dialog
    // handles the prompt), suspend/hibernate usually allowed for the seat.
    Process {
        id: sysProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    function sysOp(op) {
        sysProc.command = ["systemctl", op];
        sysProc.running = true;
    }

    // Logout: flush persisted state first (respect coalescing — stop the
    // timer, write now), then quit the shell cleanly.
    function logout() {
        ShellState.flushNow();
        quitTimer.restart();
    }

    Timer {
        id: quitTimer

        interval: 200
        onTriggered: Quickshell.quit()
    }

    // ---- idle management -------------------------------------------------
    // One IdleMonitor for the whole shell. respectInhibitors keeps apps that
    // hold a Wayland idle inhibitor (videos, games) exempt. The action fires
    // once per idle episode; unlocking / activity re-arms it.
    property bool _idleArmed: true

    IdleMonitor {
        enabled: ShellState.idleAction !== "none"
        timeout: Math.max(30, ShellState.idleSecs) * 1000
        respectInhibitors: true

        onIsIdleChanged: {
            if (!isIdle) {
                root._idleArmed = true;
                return;
            }
            if (!root._idleArmed)
                return;
            root._idleArmed = false;
            const act = ShellState.idleAction;
            if (act === "lock")
                root.lock();
            else if (act === "suspend")
                root.sysOp("suspend");
            else if (act === "shutdown")
                root.sysOp("poweroff");
        }
    }

    // ---- logind inhibitor poll (bar indicator) ---------------------------
    Process {
        id: inhibProbe

        command: ["loginctl", "list-inhibitors", "--no-legend"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().length ? text.trim().split("\n").filter(l => l.length > 0) : [];
                root.inhibitCount = lines.length;
            }
        }
    }

    // Only worth a systemd-inhibit spawn every 20s while its bar chip is on
    // or the session surface needs the data; otherwise skip the tick.
    readonly property bool _inhibitWanted: {
        try {
            const segs = JSON.parse(ShellState.barSegments);
            for (let i = 0; i < segs.length; i++)
                if (segs[i].id === "session" && segs[i].enabled === true)
                    return true;
        } catch (e) {}
        return false;
    }

    Timer {
        running: true
        repeat: true
        interval: 20000
        triggeredOnStart: true
        onTriggered: {
            if (root._inhibitWanted || ShellState.sessionOpen)
                inhibProbe.running = true;
        }
    }

    // ---- ppd probe --------------------------------------------------------
    // power-profiles-daemon is DBus-activatable; introspect succeeds if the
    // service is installed and reachable (whether running yet or not).
    Process {
        id: ppdProbe

        command: ["busctl", "--system", "introspect", "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles"]

        onExited: code => root.ppdAvailable = code === 0
    }

    Component.onCompleted: ppdProbe.running = true
}
