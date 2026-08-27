pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// LogTailer — reads journalctl/system logs for the developer log panel (PH.04).
// Streams journalctl output and exposes recent log lines.
Singleton {
    id: root

    readonly property bool available: true

    property var lines: []
    property int maxLines: 500
    property string filter: ""
    property bool paused: false

    // which source is active: "system" | "hyprland" | "custom"
    property string source: "system"
    property string customCommand: ""

    signal newLine(string text)

    function clear() {
        root.lines = [];
    }

    function setFilter(f) {
        root.filter = f;
    }

    function setSource(src, cmd) {
        root.source = src || "system";
        root.customCommand = cmd || "";
        root.lines = [];
        _restart();
    }

    function _restart() {
        logProc.running = false;
        if (root.source === "system") {
            logProc.command = ["journalctl", "-f", "-p", "warning", "--no-pager", "-o", "short-iso"];
        } else if (root.source === "hyprland") {
            const home = Quickshell.env("HOME") ?? "";
            logProc.command = ["tail", "-f", "-n", "50", home + "/.hyprland.log"];
        } else if (root.source === "custom" && root.customCommand.length > 0) {
            logProc.command = ["sh", "-c", root.customCommand];
        } else {
            return;
        }
        logProc.running = true;
    }

    Process {
        id: logProc
        stdout: Splitter {
            onReceived: function(text) {
                if (root.paused) return;
                const trimmed = text.trim();
                if (trimmed.length === 0) return;
                // apply filter
                if (root.filter.length > 0) {
                    try {
                        const re = new RegExp(root.filter, "i");
                        if (!re.test(trimmed)) return;
                    } catch (e) {
                        if (trimmed.indexOf(root.filter) < 0) return;
                    }
                }
                let newLines = root.lines.slice();
                newLines.push({ text: trimmed, time: Date.now() });
                if (newLines.length > root.maxLines)
                    newLines = newLines.slice(newLines.length - root.maxLines);
                root.lines = newLines;
                root.newLine(trimmed);
            }
        }
        stderr: Splitter {}
    }

    Component.onCompleted: {
        _restart();
    }
}
