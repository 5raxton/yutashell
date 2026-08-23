pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Recording (PH.11) — detects a running gpu-screen-recorder and exposes a stop
// action. The bar shows a REC chip while active; clicking it stops recording.
// `available` = the binary exists; `active` = a recorder process is live.
Singleton {
    id: root

    readonly property bool available: _probed && _binOk
    property bool _binOk: false
    property bool _probed: false

    property bool active: false

    function stop() {
        stopProc.command = ["sh", "-c", "pkill -INT -x gpu-screen-recorder 2>/dev/null || true"];
        stopProc.running = true;
    }

    Component.onCompleted: {
        binProbe.command = ["sh", "-c", "command -v gpu-screen-recorder >/dev/null 2>&1 && echo yes || echo no"];
        binProbe.running = true;
    }

    Process {
        id: binProbe

        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._binOk = text.trim() === "yes";
            }
        }
    }

    Process {
        id: probe

        stdout: StdioCollector {
            onStreamFinished: root.active = text.trim() === "yes"
        }
    }

    Process {
        id: stopProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // poll the recorder process state every 5s
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root._binOk)
                return;
            probe.command = ["sh", "-c", "pgrep -x gpu-screen-recorder >/dev/null 2>&1 && echo yes || echo no"];
            probe.running = true;
        }
    }
}
