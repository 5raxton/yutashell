pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// PowerBudget (PH.06) — power budget visualizer: aggregates per-app CPU usage,
// screen brightness, and battery discharge rate into a unified view. Shows
// estimated battery time based on current draw.
Singleton {
    id: root

    property var topApps: []
    property real screenBrightness: 0
    property real screenBrightnessMax: 100
    property real dischargeRate: 0
    property real estimatedMinutes: -1
    property bool available: false

    Process {
        id: topProc
        command: ["sh", "-c", "ps aux --sort=-%cpu 2>/dev/null | head -6 | tail -5"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                const apps = [];
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].trim().split(/\s+/);
                    if (parts.length >= 11) {
                        const cpu = parseFloat(parts[2]);
                        const mem = parseFloat(parts[3]);
                        const cmd = parts[10];
                        if (!isNaN(cpu) && cpu > 0.1)
                            apps.push({ name: _shortName(cmd), cpu: cpu, mem: mem });
                    }
                }
                root.topApps = apps;
            }
        }
    }

    function _shortName(cmd) {
        let n = cmd;
        if (n.indexOf("/") >= 0) n = n.substring(n.lastIndexOf("/") + 1);
        if (n.length > 18) n = n.substring(0, 16) + "..";
        return n;
    }

    Process {
        id: brightProc
        command: ["sh", "-c", "cat /sys/class/backlight/*/brightness 2>/dev/null || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: { root.screenBrightness = parseFloat(this.text.trim()) || 0; }
        }
    }

    Process {
        id: brightMaxProc
        command: ["sh", "-c", "cat /sys/class/backlight/*/max_brightness 2>/dev/null || echo 100"]
        stdout: StdioCollector {
            onStreamFinished: { root.screenBrightnessMax = parseFloat(this.text.trim()) || 100; }
        }
    }

    function _updateDischarge() {
        if (!SystemStats.batPresent || SystemStats.batCharging) {
            dischargeRate = 0;
            estimatedMinutes = -1;
            return;
        }
        // energy rate is in microwatts, convert to mW
        dischargeRate = SystemStats.batEnergyRate / 1000;
        if (dischargeRate > 0) {
            // time left in minutes
            estimatedMinutes = SystemStats.batTimeLeft;
        } else {
            estimatedMinutes = -1;
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            topProc.running = true;
            brightProc.running = true;
            brightMaxProc.running = true;
            root._updateDischarge();
        }
    }

    Connections {
        target: SystemStats
        function onBatPctChanged() { root._updateDischarge(); }
    }

    Component.onCompleted: { available = true; }
}
