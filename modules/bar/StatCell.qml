import QtQuick
import qs.theme
import qs.modules.common
import "."

// StatCell — a single toggleable bar stat (PH.14): cputemp / gpu / disk.
// Feeds from SystemStats, tints alert past threshold, and honors the segment
// click-action (default → control center). Hover shows a tooltip.
Item {
    id: root

    property string kind: "gpu"
    property var tip

    readonly property string label: root.kind === "cputemp" ? "TMP" : root.kind === "gpu" ? "GPU" : "IO"

    function showCol(item, text) {
        if (tip)
            tip.showFor(item, text);
    }

    function hideCol() {
        if (tip)
            tip.hide();
    }

    // value + alert state
    readonly property string value: {
        switch (root.kind) {
        case "cputemp":
            return root.cpuTemp < 0 ? "--" : root.cpuTemp + "°";
        case "gpu":
            return SystemStats.gpuUtil < 0 ? "--" : SystemStats.gpuUtil + "%" + (SystemStats.gpuTemp >= 0 ? " " + SystemStats.gpuTemp + "°" : "");
        case "disk":
            return SystemStats.diskRead < 0 ? "--" : "R" + SystemStats.fmtRate(SystemStats.diskRead) + " W" + SystemStats.fmtRate(SystemStats.diskWrite);
        }
        return "--";
    }

    readonly property bool hot: {
        switch (root.kind) {
        case "cputemp":
            return root.cpuTemp >= 80;
        case "gpu":
            return SystemStats.gpuUtil >= 95 || SystemStats.gpuTemp >= 90;
        case "disk":
            return false;
        }
        return false;
    }

    readonly property string tipText: {
        switch (root.kind) {
        case "cputemp":
            return "CPU " + root.cpuTemp + "°C";
        case "gpu":
            return "GPU " + SystemStats.gpuUtil + "% · " + SystemStats.gpuTemp + "°C · " + SystemStats.fmtBytes(SystemStats.gpuMemUsed * 1048576);
        case "disk":
            return "READ " + SystemStats.fmtRate(SystemStats.diskRead) + "/s · WRITE " + SystemStats.fmtRate(SystemStats.diskWrite) + "/s";
        }
        return "";
    }

    // hottest CPU package temp from SystemStats.temps (label "CPU")
    readonly property int cpuTemp: {
        const s = SystemStats.temps.find(t => t.label === "CPU");
        return s ? s.temp : -1;
    }

    implicitWidth: valueText.width + 2
    implicitHeight: Theme.barHeight

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: BarActions.dispatch(BarSegments.clickFor(root.kind))
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
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 7
            font.letterSpacing: 1.5
        }

        Text {
            id: valueText

            text: root.value
            color: root.hot ? Theme.alert : Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 10

            Behavior on color {
                ColorAnimation {
                    duration: Theme.movFast
                }
            }
        }
    }
}
