pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// BatteryService (PH.06) — battery intelligence: reads sysfs for health/wear/
// time-remaining, supports charge threshold write for ThinkPad/Lenovo. Extends
// SystemStats basic battery data with derived health metrics.
Singleton {
    id: root

    // derived from SystemStats
    readonly property real healthPct: SystemStats.batEnergyDesign > 0
        ? (SystemStats.batEnergyFull / SystemStats.batEnergyDesign) * 100 : 0
    readonly property real wearPct: 100 - healthPct
    readonly property real timeLeft: SystemStats.batTimeLeft
    readonly property real timeToFull: SystemStats.batTimeToFull
    readonly property real chargeRate: SystemStats.batEnergyRate
    readonly property bool present: SystemStats.batPresent
    readonly property int pct: SystemStats.batPct
    readonly property bool charging: SystemStats.batCharging

    // charge threshold (write support)
    property int chargeThreshold: -1
    property string _batPath: ""

    // thresholds for bar coloring
    readonly property bool warn: pct <= 20 && !charging
    readonly property bool crit: pct <= 10 && !charging

    function setChargeThreshold(pct) {
        if (_batPath.length === 0) return;
        thresholdWrite.command = ["sh", "-c", "echo " + Math.round(pct) + " | sudo tee " + _batPath + "/charge_control_end_threshold"];
        thresholdWrite.running = true;
        chargeThreshold = pct;
    }

    Process {
        id: thresholdWrite
        stdout: StdioCollector {}
    }

    Process {
        id: thresholdRead
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/charge_control_end_threshold 2>/dev/null || echo -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(this.text.trim());
                if (!isNaN(v) && v >= 0) root.chargeThreshold = v;
            }
        }
    }

    Process {
        id: batPathProbe
        command: ["sh", "-c", "ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim();
                if (p.length > 0) {
                    root._batPath = p;
                    thresholdRead.running = true;
                }
            }
        }
    }

    Component.onCompleted: {
        if (SystemStats.batPresent)
            batPathProbe.running = true;
    }

    Connections {
        target: SystemStats
        function onBatPresentChanged() {
            if (SystemStats.batPresent && root._batPath.length === 0)
                batPathProbe.running = true;
        }
    }
}
