import QtQuick
import qs.theme
import qs.modules.common

// Bar stats cluster — a pure consumer of the SystemStats singleton (PH.13).
// No FileViews or Timers here anymore; all sampling lives in SystemStats so
// the bar, control center and threshold alerts share one source of truth.
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

    component StatColumn: Item {
        id: colWrap

        default property alias content: innerCol.data
        property string tipText
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

    // every stat cell routes through the segment click map (default → control
    // center); a cleared action still falls back so no cell is ever dead
    function dispatchClick() {
        if (!BarActions.dispatch(BarSegments.clickFor("stats")))
            ShellState.toggleCc();
    }

    Row {
        id: colRow
        anchors.centerIn: parent
        spacing: 16

        StatColumn {
            id: netCol
            width: 92
            tipText: "DOWN " + SystemStats.fmtRate(SystemStats.netDown) + " / UP " + SystemStats.fmtRate(SystemStats.netUp)
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()
            onClicked: root.dispatchClick()

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
                        font.pixelSize: 10

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
                        font.pixelSize: 10

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
                        font.pixelSize: 10

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
                        font.pixelSize: 10

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
            id: cpuCol
            width: 80
            tipText: "LOAD " + (SystemStats.cpuPct < 0 ? "--" : SystemStats.cpuPct + "%")
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()
            onClicked: root.dispatchClick()

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
            id: memCol
            width: 46
            tipText: "USED " + (SystemStats.memPct < 0 ? "--" : SystemStats.memPct + "% · " + SystemStats.fmtBytes(SystemStats.memUsed))
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()
            onClicked: root.dispatchClick()

            Text {
                text: "MEM"
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.weight: Font.Bold
                font.letterSpacing: 1.5
            }

            Text {
                text: SystemStats.memPct < 0 ? "--" : SystemStats.memPct + "%"
                color: SystemStats.memPct >= SystemStats.memWarn ? Theme.alert : Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: 10
            }
        }

        StatColumn {
            id: batCol
            visible: SystemStats.batPresent
            width: 54
            tipText: (SystemStats.batCharging ? "CHARGING " : "") + (SystemStats.batPct < 0 ? "--" : SystemStats.batPct + "%")
            onHovered: (item, text) => root.showCol(item, text)
            onUnhovered: root.hideCol()
            onClicked: root.dispatchClick()

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
                    font.pixelSize: 10
                }
            }
        }
    }
}
