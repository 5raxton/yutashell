import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."

// Calendar popup (PH.11, reworked) — drops from behind the bar: hero today
// block up top, month nav + grid below. Wheel or arrows page months; today
// is a solid acid square in the grid. JP glyphs when a CJK font is present.
// Opens from the clock click and `qs ipc call calendar toggle`.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: ShellState.calendarOpen || hideDelay.running
    mask: Region {
        item: ShellState.calendarOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.calendarOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: 400
    readonly property int padX: Theme.sp4

    // viewed month — initialized to today on open
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property date now: new Date()
    readonly property string monthLabel: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"][viewMonth]
    readonly property string heroWeekday: Theme.jpEnabled ? ["日曜日", "月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日"][now.getDay()] : ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"][(now.getDay() + 6) % 7]

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    // open resets the view to today; close lingers so YSurface's exit renders
    Connections {
        target: ShellState

        function onCalendarOpenChanged() {
            if (ShellState.calendarOpen) {
                const n = new Date();
                root.viewYear = n.getFullYear();
                root.viewMonth = n.getMonth();
            } else {
                hideDelay.restart();
            }
        }
    }

    function shiftMonth(delta) {
        let m = viewMonth + delta;
        let y = viewYear;
        if (m < 0) {
            m = 11;
            y -= 1;
        } else if (m > 11) {
            m = 0;
            y += 1;
        }
        viewMonth = m;
        viewYear = y;
    }

    function goToday() {
        const n = new Date();
        root.viewYear = n.getFullYear();
        root.viewMonth = n.getMonth();
    }

    // month pages crossfade — opacity-only, never layout
    SequentialAnimation {
        id: monthFade

        NumberAnimation {
            target: bodyCol
            property: "opacity"
            from: 0.25
            to: 1
            duration: Theme.movFast
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        function onViewMonthChanged() {
            monthFade.restart();
        }

        function onViewYearChanged() {
            monthFade.restart();
        }

        target: root
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeCalendar()
        Keys.onLeftPressed: root.shiftMonth(-1)
        Keys.onRightPressed: root.shiftMonth(1)
        Keys.onPressed: event => {
            if (event.key === Qt.Key_T)
                root.goToday();
        }

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeCalendar()
        }

        YSurface {
            id: surface

            open: ShellState.calendarOpen
            anchorX: "center"
            cardW: root.cardW
            cardH: 452

            // ---- header ----
            Item {
                x: root.padX
                y: 0
                width: surface.width - root.padX * 2 - 1
                height: Theme.headH

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    text: "CALENDAR"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 96
                    visible: Theme.jpEnabled
                    text: "暦"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                }

                YButton {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    width: 30
                    label: "×"
                    onClicked: ShellState.closeCalendar()
                }
            }

            Rectangle {
                x: root.padX
                y: Theme.headH
                width: surface.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            // ---- hero: today ----
            Item {
                x: root.padX
                y: Theme.headH + 1
                width: surface.width - root.padX * 2 - 1
                height: 66

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Text {
                        text: (Theme.jpEnabled ? "今日 · " : "TODAY · ") + root.heroWeekday
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        font.weight: Font.Bold
                        font.letterSpacing: 2
                    }

                    Row {
                        spacing: Theme.sp2

                        Text {
                            anchors.baseline: parent.bottom
                            text: String(root.now.getDate())
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 38
                            font.weight: Font.ExtraBold
                        }

                        Column {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 7
                            spacing: 0

                            Rectangle {
                                width: 34
                                height: 3
                                color: Theme.acid
                            }

                            Text {
                                text: root.monthLabel + " " + root.now.getFullYear()
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                                font.weight: Font.Bold
                                font.letterSpacing: 1
                            }
                        }
                    }
                }

                YButton {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    label: Theme.jpEnabled ? "今日" : "TODAY"
                    tone: "acid"
                    onClicked: root.goToday()
                }
            }

            // ---- month nav + grid (crossfades on page change) ----
            Item {
                id: bodyCol

                x: root.padX
                y: Theme.headH + 1 + 66
                width: surface.width - root.padX * 2 - 1
                height: 44 + Theme.sp1 + grid.height

                Item {
                    id: navRow

                    width: parent.width
                    height: 36

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.sp3

                        YButton {
                            width: 34
                            label: "◀"
                            onClicked: root.shiftMonth(-1)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (Theme.jpEnabled ? root.viewMonth + 1 + "月" : root.monthLabel) + " " + root.viewYear
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsTitle
                            font.weight: Font.ExtraBold
                            font.letterSpacing: 2
                        }

                        YButton {
                            width: 34
                            label: "▶"
                            onClicked: root.shiftMonth(1)
                        }
                    }
                }

                CalendarGrid {
                    id: grid

                    y: navRow.height + Theme.sp1
                    width: parent.width
                    year: root.viewYear
                    month: root.viewMonth
                    onDayPicked: d => {
                        // day picks currently just close (no event system yet)
                        ShellState.closeCalendar();
                    }
                    onMonthShifted: delta => root.shiftMonth(delta)
                }

                // wheel pages months without stealing cell clicks
                MouseArea {
                    anchors.fill: grid
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                    onWheel: wheel => root.shiftMonth(wheel.angleDelta.y > 0 ? -1 : 1)
                }
            }

            // ---- footer ----
            Rectangle {
                x: root.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.sp2 + 12
                width: surface.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            Text {
                x: root.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                text: "ESC CLOSE · ←→ MONTH · SCROLL MONTH"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.letterSpacing: 1.5
            }
        }
    }
}
