import QtQuick
import qs.theme
import qs.modules.common

// Bar stats cluster — a pure consumer of the SystemStats singleton (PH.13).
// No FileViews or Timers here anymore; all sampling lives in SystemStats so
// the bar, control center and threshold alerts share one source of truth.
//
// TMP / GPU / IO are no longer standalone bar segments — they render as
// columns inside this box, gated on BarSegments.enabled() of their ids, so
// users toggle them from settings like any other segment.
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

    // hottest CPU package temp from SystemStats.temps (label "CPU")
    readonly property int cpuTemp: {
        const s = SystemStats.temps.find(t => t.label === "CPU");
        return s ? s.temp : -1;
    }

    component StatColumn: Item {
        id: colWrap

        default property alias content: innerCol.data
        property string tipText
        property string segId: "stats"
        signal hovered(Item item, string text)
        signal unhovered()
        signal clicked()

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
            cursorShape: Qt.PointingHandCursor
            onContainsMouseChanged: {
                if (containsMouse)
                    colWrap.hovered(colWrap, colWrap.tipText);
                else
                    colWrap.unhovered();
            }
            onClicked: colWrap.clicked()
        }
    }

    // label-over-value pair used by every simple column
    component KV: Column {
        id: kv

        property string kLabel
        property string kValue
        property bool hot: false
        spacing: 3

        Text {
            text: kv.kLabel
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }

        Text {
            text: kv.kValue
            color: kv.hot ? Theme.alert : Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsLabel
            font.weight: Font.DemiBold

            Behavior on color {
                ColorAnimation {
                    duration: Theme.movFast
                }
            }
        }
    }

    // every stat cell routes through the segment click map; a cleared action
    // still falls back to the control center so no cell is ever dead
    function dispatchFor(segId) {
        if (!BarActions.dispatch(BarSegments.clickFor(segId)))
            ShellState.toggleCc();
    }

    Row {
        id: colRow
        anchors.centerIn: parent
        spacing: 16

        StatColumn {
            tipText: "DOWN " + SystemStats.fmtRate(SystemStats.netDown) + " / UP " + SystemStats.fmtRate(SystemStats.netUp)
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()
            onClicked: root.dispatchFor("stats")

            Text {
                text: "NET"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.weight: Font.Bold
                font.letterSpacing: 1.5
            }

            Row {
                spacing: 9

                Row {
                    spacing: 2

                    Text {
                        text: "↓"
                        color: SystemStats.netDown > 2048 ? Theme.acid : Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.movMed
                            }
                        }
                    }

                    Text {
                        // capped so gigabit bursts can't push into the up-rate cell
                        width: 38
                        elide: Text.ElideRight
                        text: SystemStats.fmtRate(SystemStats.netDown)
                        color: SystemStats.netDown > 2048 ? Theme.ink : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        font.weight: Font.DemiBold

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.movMed
                            }
                        }
                    }
                }

                Row {
                    spacing: 2

                    Text {
                        text: "↑"
                        color: SystemStats.netUp > 2048 ? Theme.acid : Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.movMed
                            }
                        }
                    }

                    Text {
                        width: 38
                        elide: Text.ElideRight
                        text: SystemStats.fmtRate(SystemStats.netUp)
                        color: SystemStats.netUp > 2048 ? Theme.ink : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        font.weight: Font.DemiBold

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.movMed
                            }
                        }
                    }
                }
            }
        }

        StatColumn {
            tipText: "LOAD " + (SystemStats.cpuPct < 0 ? "--" : SystemStats.cpuPct + "%")
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()
            onClicked: root.dispatchFor("stats")

            Text {
                text: "CPU"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.weight: Font.Bold
                font.letterSpacing: 1.5
            }

            Row {
                spacing: 7

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemStats.cpuPct < 0 ? "--" : SystemStats.cpuPct + "%"
                    color: SystemStats.cpuPct >= SystemStats.cpuCrit ? Theme.alert : Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.weight: Font.DemiBold
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
                            visible: SystemStats.cpuPct >= 0
                            color: {
                                const filled = Math.round(SystemStats.cpuPct / 100 * 6);
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
            tipText: "USED " + (SystemStats.memPct < 0 ? "--" : SystemStats.memPct + "% · " + SystemStats.fmtBytes(SystemStats.memUsed))
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()
            onClicked: root.dispatchFor("stats")

            KV {
                kLabel: "MEM"
                kValue: SystemStats.memPct < 0 ? "--" : SystemStats.memPct + "%"
                hot: SystemStats.memPct >= SystemStats.memWarn
            }
        }

        StatColumn {
            visible: SystemStats.batPresent
            tipText: (SystemStats.batCharging ? "CHARGING " : "") + (SystemStats.batPct < 0 ? "--" : SystemStats.batPct + "%")
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()
            onClicked: root.dispatchFor("stats")

            Column {
                spacing: 3

                Text {
                    text: "BAT"
                    color: SystemStats.batCharging ? Theme.acid : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }

                Row {
                    spacing: 4

                    Text {
                        visible: SystemStats.batCharging
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uF0E7"
                        color: Theme.acid
                        font.family: Theme.fontFamily
                        font.pixelSize: 9
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: SystemStats.batPct < 0 ? "--" : SystemStats.batPct + "%"
                        color: !SystemStats.batCharging && SystemStats.batPct >= 0 && SystemStats.batPct <= SystemStats.batWarn ? Theme.alert : Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        // ---- embedded optional stats (toggle via segments settings) ----

        StatColumn {
            visible: BarSegments.enabled("cputemp")
            tipText: "CPU " + (root.cpuTemp < 0 ? "--" : root.cpuTemp + "°C")
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()
            onClicked: root.dispatchFor("cputemp")

            KV {
                kLabel: "TMP"
                kValue: root.cpuTemp < 0 ? "--" : root.cpuTemp + "°"
                hot: root.cpuTemp >= SystemStats.tempWarn
            }
        }

        StatColumn {
            visible: BarSegments.enabled("gpu")
            tipText: {
                // no sensor backend → don't advertise "-1°C" as a reading
                if (SystemStats.gpuUtil < 0 && SystemStats.gpuTemp < 0)
                    return "GPU — no sensor";
                return "GPU " + (SystemStats.gpuUtil < 0 ? "--" : SystemStats.gpuUtil + "%") + " · " + (SystemStats.gpuTemp < 0 ? "--" : SystemStats.gpuTemp + "°C") + " · " + SystemStats.fmtBytes(SystemStats.gpuMemUsed * 1048576);
            }
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()
            onClicked: root.dispatchFor("gpu")

            KV {
                kLabel: "GPU"
                kValue: SystemStats.gpuUtil < 0 ? "--" : SystemStats.gpuUtil + "%" + (SystemStats.gpuTemp >= 0 ? " " + SystemStats.gpuTemp + "°" : "")
                hot: SystemStats.gpuUtil >= 95 || SystemStats.gpuTemp >= SystemStats.tempCrit
            }
        }

        StatColumn {
            visible: BarSegments.enabled("disk")
            tipText: "READ " + SystemStats.fmtRate(SystemStats.diskRead) + "/s · WRITE " + SystemStats.fmtRate(SystemStats.diskWrite) + "/s"
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()
            onClicked: root.dispatchFor("disk")

            KV {
                kLabel: "IO"
                kValue: SystemStats.diskRead < 0 ? "--" : SystemStats.fmtRate(SystemStats.diskRead) + "/" + SystemStats.fmtRate(SystemStats.diskWrite)
            }
        }
    }
}
