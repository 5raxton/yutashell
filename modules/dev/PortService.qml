pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// PortService — reads listening ports via `ss -tlnp` (PH.04). 15s refresh.
// Exposes port list with address, process, pid, protocol.
Singleton {
    id: root

    readonly property bool available: true
    property var ports: []
    property string status: ""
    property var _exposed: [] // non-localhost listeners

    signal portsRefreshed()

    function refresh() {
        ssProc.running = true;
    }

    function _parsePorts(text) {
        const lines = text.trim().split("\n");
        const ports = [];
        const exposed = [];
        for (let i = 1; i < lines.length; i++) { // skip header
            const parts = lines[i].trim().split(/\s+/);
            if (parts.length < 5) continue;
            const state = parts[0];
            const recv = parts[1];
            const send = parts[2];
            const local = parts[3];
            // extract port from local address (last :NNNN)
            const colonIdx = local.lastIndexOf(":");
            const port = colonIdx >= 0 ? parseInt(local.slice(colonIdx + 1)) || 0 : 0;
            const addr = colonIdx >= 0 ? local.slice(0, colonIdx) : local;
            const processInfo = parts.length >= 6 ? parts[5] : "";
            const processMatch = processInfo.match(/users:\(\("([^"]+)"/);
            const processName = processMatch ? processMatch[1] : processInfo;
            const pidMatch = processInfo.match(/pid=(\d+)/);
            const pid = pidMatch ? parseInt(pidMatch[1]) : 0;

            const entry = {
                port: port,
                addr: addr,
                process: processName,
                pid: pid,
                protocol: "tcp",
                listening: state === "LISTEN"
            };

            if (entry.listening) {
                ports.push(entry);
                // flag non-localhost listeners
                if (addr !== "127.0.0.1" && addr !== "::1" && addr !== "*" && addr !== "[::]") {
                    exposed.push(entry);
                }
            }
        }
        root.ports = ports;
        root._exposed = exposed;
        root.status = ports.length + " ports" + (exposed.length > 0 ? " (" + exposed.length + " exposed)" : "");
        root.portsRefreshed();
    }

    Process {
        id: ssProc
        command: ["ss", "-tlnp"]
        stdout: StdioCollector {
            onStreamFinished: root._parsePorts(this.text);
        }
        stderr: StdioCollector {}
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: root.refresh()
    }

    Component.onCompleted: {
        refresh();
    }
}
