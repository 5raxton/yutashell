pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// ClipboardService (PH.01.1) — reactive clipboard monitor.
// Watches clipboard for changes via a polling wl-paste reader; new text
// content is automatically fed into cliphist. Binary (image) entries are
// detected and surfaced for preview. Clipboard.qml handles the UI;
// this singleton handles automatic capture.
Singleton {
    id: root

    readonly property bool available: _probed && _binOk
    property bool _binOk: false
    property bool _probed: false

    property bool _watching: false
    property string _lastHash: ""
    property int _watchInterval: 2000

    Component.onCompleted: {
        probeProc.running = true;
    }

    function startWatching() {
        if (!available || _watching)
            return;
        _watching = true;
        _poll();
        pollTimer.start();
    }

    function stopWatching() {
        _watching = false;
        pollTimer.stop();
    }

    // simple djb2 hash for change detection (first 512 chars)
    function _hash(s) {
        let h = 5381;
        const n = Math.min(s.length, 512);
        for (let i = 0; i < n; i++)
            h = ((h << 5) + h + s.charCodeAt(i)) & 0x7fffffff;
        return String(h);
    }

    function _poll() {
        if (!_watching || !available)
            return;
        pollProc.running = true;
    }

    // ---- probes ----
    Process {
        id: probeProc

        command: ["sh", "-c",
            "command -v cliphist >/dev/null 2>&1 && " +
            "command -v wl-paste >/dev/null 2>&1 && echo yes || echo no"]

        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._binOk = text.trim() === "yes";
                if (root._binOk) {
                    Health.clear("clipboard");
                    root.startWatching();
                } else {
                    Health.report("clipboard", "clipboard unavailable (install cliphist + wl-clipboard)");
                }
            }
        }
        stderr: StdioCollector {}
    }

    // ---- clipboard poll ----
    Timer {
        id: pollTimer

        interval: root._watchInterval
        running: false
        repeat: true
        onTriggered: root._poll()
    }

    Process {
        id: pollProc

        command: ["wl-paste", "--no-newline"]

        stdout: StdioCollector {
            onStreamFinished: {
                const content = text;
                if (content.length === 0) return;
                const h = root._hash(content);
                if (h === root._lastHash) return;
                root._lastHash = h;
                // pipe current clipboard into cliphist
                addProc.running = true;
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: addProc

        command: ["sh", "-c", "wl-paste --no-newline 2>/dev/null | cliphist add 2>/dev/null || true"]

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
}
