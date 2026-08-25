import QtQuick
import qs.theme
import qs.modules.common
import "."

// StatCell — one standalone, individually toggleable and placeable bar stat
// segment (PH.14): cpu / mem / bat / cputemp / gpu / disk. Feeds from
// SystemStats, tints alert past threshold, honors the segment click-action
// (default → control center). Hover shows a tooltip.
Item {
    id: root

    property string kind: "cpu"
    property var tip

    readonly property string label: {
        switch (root.kind) {
        case "mem":
            return "MEM";
        case "bat":
            return "BAT";
        case "cputemp":
            return "TMP";
        case "gpu":
            return "GPU";
        case "disk":
            return "IO";
        }
        return "CPU";
    }

    function showCol(item, text) {
        if (tip)
            tip.showFor(item, text);
    }

    function hideCol() {
        if (tip)
            tip.hide();
    }

    // hottest CPU package temp from SystemStats.temps (label "CPU")
    // cached so the find() doesn't run on every binding evaluation
    property int _cpuTemp: -1
    readonly property int cpuTemp: root._cpuTemp

    Connections {
        target: SystemStats
        function onTempsChanged() {
            const s = SystemStats.temps.find(t => t.label === "CPU");
            root._cpuTemp = s ? s.temp : -1;
        }
    }
    Component.onCompleted: {
        const s = SystemStats.temps.find(t => t.label === "CPU");
        root._cpuTemp = s ? s.temp : -1;
    }

    readonly property string value: {
        switch (root.kind) {
        case "cpu":
            return SystemStats.cpuPct < 0 ? "--" : SystemStats.cpuPct + "%";
        case "mem":
            return SystemStats.memPct < 0 ? "--" : SystemStats.memPct + "%";
        case "bat":
            return SystemStats.batPct < 0 ? "--" : SystemStats.batPct + "%";
        case "cputemp":
            return root.cpuTemp < 0 ? "--" : root.cpuTemp + "°";
        case "gpu":
            return SystemStats.gpuUtil < 0 ? "--" : SystemStats.gpuUtil + "%" + (SystemStats.gpuTemp >= 0 ? " " + SystemStats.gpuTemp + "°" : "");
        case "disk":
            return SystemStats.diskRead < 0 ? "--" : SystemStats.fmtRate(SystemStats.diskRead) + "/" + SystemStats.fmtRate(SystemStats.diskWrite);
        }
        return "--";
    }

    readonly property bool hot: {
        switch (root.kind) {
        case "cpu":
            return SystemStats.cpuPct >= SystemStats.cpuCrit;
        case "mem":
            return SystemStats.memPct >= SystemStats.memWarn;
        case "bat":
            return !SystemStats.batCharging && SystemStats.batPct >= 0 && SystemStats.batPct <= SystemStats.batWarn;
        case "cputemp":
            return root.cpuTemp >= SystemStats.tempWarn;
        case "gpu":
            return SystemStats.gpuUtil >= 95 || SystemStats.gpuTemp >= SystemStats.tempCrit;
        }
        return false;
    }

    readonly property string tipText: {
        switch (root.kind) {
        case "cpu":
            return "LOAD " + (SystemStats.cpuPct < 0 ? "--" : SystemStats.cpuPct + "%");
        case "mem":
            return "USED " + (SystemStats.memPct < 0 ? "--" : SystemStats.memPct + "% · " + SystemStats.fmtBytes(SystemStats.memUsed));
        case "bat":
            return (SystemStats.batCharging ? "CHARGING " : "") + (SystemStats.batPct < 0 ? "--" : SystemStats.batPct + "%");
        case "cputemp":
            return "CPU " + (root.cpuTemp < 0 ? "--" : root.cpuTemp + "°C");
        case "gpu":
            // no sensor backend → don't advertise "-1°C" as a reading
            if (SystemStats.gpuUtil < 0 && SystemStats.gpuTemp < 0)
                return "GPU — no sensor";
            return "GPU " + (SystemStats.gpuUtil < 0 ? "--" : SystemStats.gpuUtil + "%") + " · " + (SystemStats.gpuTemp < 0 ? "--" : SystemStats.gpuTemp + "°C") + " · " + SystemStats.fmtBytes(SystemStats.gpuMemUsed * 1048576);
        case "disk":
            return "READ " + SystemStats.fmtRate(SystemStats.diskRead) + "/s · WRITE " + SystemStats.fmtRate(SystemStats.diskWrite) + "/s";
        }
        return "";
    }

    implicitWidth: valueText.width + 2
    implicitHeight: Theme.barHeight

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            // honor the segment click map; a cleared action falls back to CC
            if (BarActions.dispatch(BarSegments.clickFor(root.kind)))
                return;
            ShellState.toggleCc();
        }
        onContainsMouseChanged: {
            if (containsMouse)
                root.showCol(root, root.tipText);
            else
                root.hideCol();
        }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            text: root.label
            color: root.kind === "bat" && SystemStats.batCharging ? Theme.acid : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }

        Row {
            spacing: 4

            Text {
                visible: root.kind === "bat" && SystemStats.batCharging
                anchors.verticalCenter: parent.verticalCenter
                text: "\uF0E7"
                color: Theme.acid
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }

            Text {
                id: valueText

                text: root.value
                color: root.hot ? Theme.alert : Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLabel
                font.weight: Font.DemiBold
                scale: root.hot ? 1.06 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.movFast
                    }
                }

                Behavior on scale {
                    NumberAnimation {
                        duration: Theme.movSnap
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.3
                    }
                }
            }
        }
    }
}
