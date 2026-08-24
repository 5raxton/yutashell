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
    property bool active: ShellState.nlActive
    property int temp: ShellState.nlTemp

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
        active = true;
        restartProc();
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
        binProbe.command = ["sh", "-c", "command -v hyprsunset >/dev/null 2>&1 && echo yes || echo no"];
        binProbe.running = true;
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
