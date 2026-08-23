import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."

// Calendar popup (PH.11) — drops from behind the bar, month grid with today
// boxed in acid, month/year nav, JP weekday glyphs when a CJK font is present.
// Opens from the clock click and `qs ipc call calendar toggle`.
PanelWindow {
    id: root

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

    readonly property int cardW: 320
    readonly property int padX: Theme.sp4

    // viewed month — initialized to today on open
    property int viewYear: new Date().getFullYear()
    property int viewMonth: new Date().getMonth()

    readonly property string monthLabel: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"][viewMonth]

    Timer {
        id: hideDelay

        interval: 190
    }

    Connections {
        target: ShellState

        function onCalendarOpenChanged() {
            if (ShellState.calendarOpen) {
                const n = new Date();
                root.viewYear = n.getFullYear();
                root.viewMonth = n.getMonth();
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

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeCalendar()
        Keys.onLeftPressed: root.shiftMonth(-1)
        Keys.onRightPressed: root.shiftMonth(1)

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeCalendar()
        }

        YSurface {
            id: surface

            open: ShellState.calendarOpen
            anchorX: "center"
            cardW: root.cardW
            cardH: 316

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

            // ---- month nav ----
            Item {
                x: root.padX
                y: Theme.headH + 1
                width: surface.width - root.padX * 2 - 1
                height: 44

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp2

                    YButton {
                        width: 34
                        label: "◀"
                        onClicked: root.shiftMonth(-1)
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.monthLabel + " " + root.viewYear
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

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    text: Theme.jpEnabled ? "今日" : "TODAY"
                    color: Theme.acid
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 1
                }
            }

            // ---- grid ----
            CalendarGrid {
                id: grid

                x: root.padX
                y: Theme.headH + 1 + 44 + Theme.sp2
                width: surface.width - root.padX * 2 - 1
                year: root.viewYear
                month: root.viewMonth
                onDayPicked: d => {
                    // day picks currently just close (no event system yet)
                    ShellState.closeCalendar();
                }
            }

            // ---- footer ----
            Rectangle {
                x: root.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.sp2
                width: surface.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            Text {
                x: root.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                text: "ESC CLOSE · ◀▶ MONTH"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.letterSpacing: 1.5
            }
        }
    }
}
