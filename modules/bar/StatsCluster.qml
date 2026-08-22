import Quickshell.Io
import QtQuick
import qs.theme

Item {
    id: root

    implicitWidth: colRow.width
    implicitHeight: Theme.barHeight

    property var tip

    function showCol(item, text) {
        if (tip)
            tip.showFor(item, text);
    }

    function hideCol() {
        if (tip)
            tip.hide();
    }

    property real cpuPct: -1
    property real memPct: -1
    property real downBps: -1
    property real upBps: -1
    property int batPct: -1
    property bool batCharging: false
    property bool batPresent: false
    property bool batteryTriedFallback: false

    property double prevCpuTotal: -1
    property double prevCpuIdle: -1
    property double prevNetRx: -1
    property double prevNetTx: -1
    property date prevStamp: new Date()

    function sampleCpu(t) {
        const nums = t.split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
        const total = nums.reduce((a, b) => a + b, 0);
        const idle = (nums[3] || 0) + (nums[4] || 0);
        if (prevCpuTotal >= 0 && total > prevCpuTotal)
            cpuPct = Math.max(0, Math.min(100, Math.round((1 - (idle - prevCpuIdle) / (total - prevCpuTotal)) * 100)));
        prevCpuTotal = total;
        prevCpuIdle = idle;
    }

    function sampleMem(t) {
        const total = Number((t.match(/MemTotal:\s+(\d+)/) || [])[1]);
        const avail = Number((t.match(/MemAvailable:\s+(\d+)/) || [])[1]);
        if (total > 0 && !isNaN(avail))
            memPct = Math.round((1 - avail / total) * 100);
    }

    function sampleNet(t) {
        let rx = 0;
        let tx = 0;
        for (const ln of t.split("\n").slice(2)) {
            const idx = ln.indexOf(":");
            if (idx < 0)
                continue;
            if (ln.slice(0, idx).trim() === "lo")
                continue;
            const f = ln.slice(idx + 1).trim().split(/\s+/).map(Number);
            rx += f[0] || 0;
            tx += f[8] || 0;
        }
        const now = new Date();
        if (prevNetRx >= 0) {
            const dt = (now - prevStamp) / 1000;
            if (dt > 0) {
                downBps = Math.max(0, (rx - prevNetRx) / dt);
                upBps = Math.max(0, (tx - prevNetTx) / dt);
            }
        }
        prevNetRx = rx;
        prevNetTx = tx;
        prevStamp = now;
    }

    function fmtRate(v) {
        if (v < 0)
            return "--";
        if (v < 1024)
            return Math.round(v) + "B";
        if (v < 1048576)
            return (v / 1024).toFixed(v < 10240 ? 1 : 0) + "K";
        if (v < 1073741824)
            return (v / 1048576).toFixed(v < 10485760 ? 1 : 0) + "M";
        return (v / 1073741824).toFixed(1) + "G";
    }

    FileView {
        id: cpuFile
        path: "/proc/stat"
        watchChanges: false
        onLoaded: root.sampleCpu(cpuFile.text())
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        watchChanges: false
        onLoaded: root.sampleMem(memFile.text())
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"
        watchChanges: false
        onLoaded: root.sampleNet(netFile.text())
    }

    FileView {
        id: batCapFile
        path: "/sys/class/power_supply/BAT1/capacity"
        watchChanges: false
        printErrors: false
        preload: true
        onLoaded: {
            root.batPresent = true;
            const v = parseInt(batCapFile.text());
            if (!isNaN(v))
                root.batPct = v;
        }
        onLoadFailed: {
            if (!root.batteryTriedFallback) {
                root.batteryTriedFallback = true;
                batCapFile.path = "/sys/class/power_supply/BAT0/capacity";
                batStatFile.path = "/sys/class/power_supply/BAT0/status";
            } else {
                root.batPresent = false;
            }
        }
    }

    FileView {
        id: batStatFile
        path: "/sys/class/power_supply/BAT1/status"
        watchChanges: false
        printErrors: false
        preload: true
        onLoaded: {
            const s = batStatFile.text().trim();
            root.batCharging = s.startsWith("Charging") || s.startsWith("Full");
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuFile.reload();
            memFile.reload();
            netFile.reload();
            if (root.batPresent || !root.batteryTriedFallback) {
                batCapFile.reload();
                batStatFile.reload();
            }
        }
    }

    component StatColumn: Item {
        id: colWrap

        default property alias content: innerCol.data
        property string tipText
        signal hovered(Item item, string text)
        signal unhovered()

        width: innerCol.width
        height: Theme.barHeight

        Column {
            id: innerCol
            anchors.centerIn: parent
            spacing: 3
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            onContainsMouseChanged: {
                if (containsMouse)
                    colWrap.hovered(colWrap, colWrap.tipText);
                else
                    colWrap.unhovered();
            }
        }
    }

    Row {
        id: colRow
        anchors.centerIn: parent
        spacing: 16

        StatColumn {
            id: netCol
            width: 92
            tipText: "DOWN " + root.fmtRate(root.downBps) + " / UP " + root.fmtRate(root.upBps)
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()

            Text {
                text: "NET"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 7
                font.letterSpacing: 1.5
            }

            Row {
                spacing: 9

                Row {
                    spacing: 2

                    Text {
                        text: "↓"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        text: root.fmtRate(root.downBps)
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }

                Row {
                    spacing: 2

                    Text {
                        text: "↑"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }

                    Text {
                        text: root.fmtRate(root.upBps)
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }
        }

        StatColumn {
            id: cpuCol
            width: 80
            tipText: "LOAD " + (root.cpuPct < 0 ? "--" : root.cpuPct + "%")
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()

            Text {
                text: "CPU"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 7
                font.letterSpacing: 1.5
            }

            Row {
                spacing: 7

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.cpuPct < 0 ? "--" : root.cpuPct + "%"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }

                Item {
                    width: 23
                    height: 9
                    anchors.verticalCenter: parent.verticalCenter

                    Repeater {
                        model: 6

                        delegate: Rectangle {
                            required property int index

                            x: index * 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 9
                            visible: root.cpuPct >= 0
                            color: {
                                const filled = Math.round(root.cpuPct / 100 * 6);
                                if (index >= filled)
                                    return Theme.hairline;
                                return index === 5 ? Theme.alert : Theme.acid;
                            }
                        }
                    }
                }
            }
        }

        StatColumn {
            id: memCol
            width: 46
            tipText: "USED " + (root.memPct < 0 ? "--" : root.memPct + "%")
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()

            Text {
                text: "MEM"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 7
                font.letterSpacing: 1.5
            }

            Text {
                text: root.memPct < 0 ? "--" : root.memPct + "%"
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }

        StatColumn {
            id: batCol
            visible: root.batPresent
            width: 54
            tipText: (root.batCharging ? "CHARGING " : "") + (root.batPct < 0 ? "--" : root.batPct + "%")
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()

            Text {
                text: "BAT"
                color: root.batCharging ? Theme.acid : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 7
                font.letterSpacing: 1.5
            }

            Row {
                spacing: 4

                Text {
                    visible: root.batCharging
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uF0E7"
                    color: Theme.acid
                    font.family: Theme.fontFamily
                    font.pixelSize: 9
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.batPct < 0 ? "--" : root.batPct + "%"
                    color: !root.batCharging && root.batPct >= 0 && root.batPct <= 15 ? Theme.alert : Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 10
                }
            }
        }
    }
}
