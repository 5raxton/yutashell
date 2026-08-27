import Quickshell
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui
import "../focus"

// FocusPanel (PH.05) — YSurface panel showing focus stats, today's summary,
// and recent history. Controls for start/pause/reset.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    readonly property bool open: ShellState.focusOpen

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.open || hideDelay.running
    mask: Region { item: root.open ? clickAway : null }

    WlrLayershell.layer: WlrLayer.Top

    Timer { id: hideDelay; interval: Theme.lingerMs }
    onOpenChanged: if (!root.open) hideDelay.restart()

    YClickAway { id: clickAway; onOutsideClicked: ShellState.closeFocus() }

    property var _hist: FocusMode.history
    property date _today: new Date()
    property int _todayMin: 0
    property int _weekMin: 0
    property int _streak: 0

    function _refresh() {
        _hist = FocusMode.history;
        const today = new Date().toISOString().slice(0, 10);
        const todayEntry = _hist.find(h => h.date === today);
        _todayMin = todayEntry ? todayEntry.totalMin : 0;

        // week total + streak
        let weekTotal = 0;
        let streak = 0;
        const now = new Date();
        for (let i = 0; i < 7; i++) {
            const d = new Date(now);
            d.setDate(d.getDate() - i);
            const ds = d.toISOString().slice(0, 10);
            const e = _hist.find(h => h.date === ds);
            if (e) {
                weekTotal += e.totalMin;
                if (i === streak) streak++;
            } else if (i === 0) {
                // today with no data yet is ok for streak
            } else {
                break;
            }
        }
        _weekMin = weekTotal;
        _streak = streak;
    }

    Timer {
        interval: 5000
        running: root.open
        repeat: true
        onTriggered: _refresh()
    }
    onOpenChanged: { if (open) _refresh(); }

    Item {
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: ShellState.closeFocus()

        YSurface {
            id: card
            open: root.open
            anchorX: "center"
            cardW: Math.min(520, Math.round(parent.width * 0.4))
            cardH: Math.min(580, Math.round(parent.height * 0.65))

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 20

                // header
                Text {
                    text: "FOCUS & WELLNESS"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                }

                // status
                Rectangle {
                    width: parent.width
                    height: 64
                    radius: 8
                    color: FocusMode.focusing ? Theme.acid + "18" : Theme.surface

                    Row {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 16

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2

                            Text {
                                text: FocusMode.label
                                color: FocusMode.focusing ? Theme.acid : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.weight: Font.Bold
                                font.letterSpacing: 2
                            }
                            Text {
                                text: FocusMode.display
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsTitle
                                font.weight: Font.Light
                            }
                        }

                        Item { width: 1; height: 1; Layout.fillWidth: true }

                        // controls
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            YButton {
                                label: FocusMode.running ? "Pause" : (FocusMode.phase === "idle" ? "Start" : "Resume")
                                tone: "acid"
                                onClicked: FocusMode.toggle()
                            }

                            YButton {
                                label: "Reset"
                                onClicked: FocusMode.reset()
                            }
                        }
                    }
                }

                // stats row
                Row {
                    width: parent.width
                    spacing: 12

                    Rectangle {
                        width: (parent.width - 24) / 3
                        height: 56
                        radius: 6
                        color: Theme.surface

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root._todayMin + "m"
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsTitle
                                font.weight: Font.Bold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "TODAY"
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.letterSpacing: 1
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 24) / 3
                        height: 56
                        radius: 6
                        color: Theme.surface

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root._weekMin + "m"
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsTitle
                                font.weight: Font.Bold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "THIS WEEK"
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.letterSpacing: 1
                            }
                        }
                    }

                    Rectangle {
                        width: (parent.width - 24) / 3
                        height: 56
                        radius: 6
                        color: Theme.surface

                        Column {
                            anchors.centerIn: parent
                            spacing: 2
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: root._streak + "d"
                                color: root._streak >= 3 ? Theme.acid : Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsTitle
                                font.weight: Font.Bold
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "STREAK"
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.letterSpacing: 1
                            }
                        }
                    }
                }

                // history
                Text {
                    text: "RECENT HISTORY"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }

                Column {
                    width: parent.width
                    spacing: 4

                    Repeater {
                        model: {
                            const out = [];
                            const hist = root._hist;
                            const start = Math.max(0, hist.length - 7);
                            for (let i = hist.length - 1; i >= start; i--)
                                out.push(hist[i]);
                            return out;
                        }

                        delegate: Rectangle {
                            required property var modelData
                            width: parent.width
                            height: 32
                            radius: 4
                            color: index === 0 ? Theme.acid + "12" : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.date
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                    width: 100
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.totalMin + " min"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                    width: 80
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.sessions + " sessions"
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                }
                            }
                        }
                    }

                    Text {
                        visible: root._hist.length === 0
                        text: "No focus sessions yet. Start one!"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBody
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
