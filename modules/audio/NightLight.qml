pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.notify
import qs.modules.common

// Night light over hyprsunset. Absent binary = feature hides everywhere.
// The temperature slider lives in the settings AUDIO page (PH.16 will
// absorb it); the bar shows a chip while the filter is active.
Singleton {
    id: root

    readonly property bool available: _probed && _binOk

    property bool _binOk: false
    property bool _probed: false
    // initialize-once from prefs (NOT a binding): start()/stop() assign these
    // imperatively, which would silently destroy a ShellState binding and
    // leave the property orphaned from persisted state forever after
    property bool active: false
    property int temp: 3000

    onActiveChanged: {
        ShellState.set("nlActive", active);
        if (active && available)
            restartProc();
    }

    onTempChanged: {
        ShellState.set("nlTemp", temp);
        if (active)
            restartProc();
    }

    function toggle() {
        if (!available) {
            Notify.announce("NIGHT LIGHT", "hyprsunset not installed", 1);
            return;
        }
        active ? stop() : start();
    }

    function start() {
        // guard: IPC can call start() directly — never latch active (and
        // persist it, lighting the bar's ghost moon chip) without the binary
        if (!available) {
            Notify.announce("NIGHT LIGHT", "hyprsunset not installed", 1);
            return;
        }
        active = true;
    }

    function stop() {
        active = false;
        try {
            sunsetProc.terminate();
        } catch (e) {
        }
    }

    function restartProc() {
        // running stays true until the old process actually exits — relaunch
        // from onExited instead of forcing the edge (which would be a no-op)
        if (sunsetProc.running) {
            _relaunch = true;
            try {
                sunsetProc.terminate();
            } catch (e) {
            }
            return;
        }
        _launch();
    }

    function _launch() {
        sunsetProc.command = ["hyprsunset", "-t", String(temp)];
        sunsetProc.running = true;
    }

    property bool _relaunch: false

    Process {
        id: sunsetProc

        onExited: {
            if (_relaunch) {
                _relaunch = false;
                _launch();
            }
        }
    }

    Component.onCompleted: {
        // seed from prefs before anything binds to us
        active = ShellState.nlActive;
        temp = ShellState.nlTemp;
        binProbe.command = ["sh", "-c", "command -v hyprsunset >/dev/null 2>&1 && echo yes || echo no"];
        binProbe.running = true;
        _loadSchedule();
    }

    // --- schedule: auto enable/disable based on time of day ---
    property bool scheduleEnabled: false
    property string scheduleOn: "21:00"
    property string scheduleOff: "07:00"
    property bool _scheduleActive: false  // whether schedule is currently keeping NL on

    function _loadSchedule() {
        try {
            const s = JSON.parse(ShellState.nlSchedule);
            scheduleEnabled = !!s.enabled;
            scheduleOn = s.on || "21:00";
            scheduleOff = s.off || "07:00";
        } catch (e) {}
        if (available && scheduleEnabled) _checkSchedule();
    }

    function setSchedule(onTime, offTime, enabled) {
        scheduleOn = onTime;
        scheduleOff = offTime;
        scheduleEnabled = enabled;
        ShellState.set("nlSchedule", JSON.stringify({
            on: onTime, off: offTime, enabled: enabled
        }));
        if (enabled && available) _checkSchedule();
        else if (!enabled && _scheduleActive) {
            _scheduleActive = false;
            stop();
        }
    }

    function _parseHM(hm) {
        const p = hm.split(":");
        return (parseInt(p[0], 10) || 0) * 60 + (parseInt(p[1], 10) || 0);
    }

    function _checkSchedule() {
        if (!available || !scheduleEnabled) return;
        const now = new Date();
        const mins = now.getHours() * 60 + now.getMinutes();
        const onM = _parseHM(scheduleOn);
        const offM = _parseHM(scheduleOff);
        // determine if "now" is in the night window
        let inNight;
        if (onM <= offM) {
            // same-day window (e.g. 07:00–21:00)
            inNight = mins >= onM && mins < offM;
        } else {
            // overnight window (e.g. 21:00–07:00)
            inNight = mins >= onM || mins < offM;
        }
        if (inNight && !_scheduleActive) {
            _scheduleActive = true;
            start();
        } else if (!inNight && _scheduleActive) {
            _scheduleActive = false;
            stop();
        }
    }

    Timer {
        id: scheduleTimer
        interval: 60000
        repeat: true
        running: root.scheduleEnabled
        onTriggered: root._checkSchedule()
    }

    Process {
        id: binProbe

        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._binOk = text.trim() === "yes";
                if (!root._binOk)
                    Health.report("hyprsunset", "night light unavailable (install hyprsunset)");
                else
                    Health.clear("hyprsunset");
                // resume a persisted session once we know the binary exists
                if (root.active && root.available)
                    root.restartProc();
            }
        }
    }
}
