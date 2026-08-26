import QtQuick
import qs.theme
import qs.modules.common
import "."

Item {
    id: root

    implicitWidth: timeBlock.width + 14 + dateCol.width
    implicitHeight: Theme.scaledBarHeight

    property var now: new Date()
    property bool colonOn: true

    readonly property var weekdayKanji: ["月", "火", "水", "木", "金", "土", "日"]

    // 12h mode folds into the hour text; 24h stays zero-padded
    readonly property int hour12: {
        const h = now.getHours() % 12;
        return h === 0 ? 12 : h;
    }
    readonly property string ampm: now.getHours() < 12 ? "AM" : "PM"

    // click honors the segment action (default → calendar)
    Rectangle {
        anchors.fill: parent
        color: clockArea.containsMouse ? Theme.surface : "transparent"
        radius: Theme.sp1

        Behavior on color {
            ColorAnimation { duration: Theme.movFast }
        }
    }

    MouseArea {
        id: clockArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: BarActions.dispatch(BarSegments.clickFor("clock"))
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: root.colonOn = !root.colonOn
    }

    Item {
        id: timeBlock
        anchors.verticalCenter: parent.verticalCenter
        width: ssText.x + ssText.width

        Text {
            id: hhText
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            text: ShellState.clock24h ? String(root.now.getHours()).padStart(2, "0") : String(root.hour12)
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFsTitle
            font.weight: Font.Bold
        }

        Text {
            id: colonText
            anchors.baseline: hhText.baseline
            anchors.left: hhText.right
            text: ":"
            opacity: root.colonOn ? 1 : 0.2
            color: root.colonOn ? Theme.acid : Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFsTitle
            font.weight: Font.Bold

            // breathe, don't strobe
            Behavior on opacity {
                NumberAnimation {
                    duration: 340
                    easing.type: Easing.InOutSine
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: 340
                    easing.type: Easing.InOutSine
                }
            }
        }

        Text {
            id: mmText
            anchors.baseline: hhText.baseline
            anchors.left: colonText.right
            text: String(root.now.getMinutes()).padStart(2, "0")
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFsTitle
            font.weight: Font.Bold
        }

        Text {
            id: ssText
            anchors.baseline: hhText.baseline
            anchors.left: mmText.right
            anchors.leftMargin: 5
            text: ShellState.clock24h ? ":" + String(root.now.getSeconds()).padStart(2, "0") : " " + root.ampm
            color: Theme.acid
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFsLabel
        }
    }

    Column {
        id: dateCol
        anchors.left: timeBlock.right
        anchors.leftMargin: Theme.sp3
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            text: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][root.now.getDay()] + " " + Qt.formatDate(root.now, "MM.dd")
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFsMicro
            font.letterSpacing: 1
        }

        Text {
            text: {
                const y = String(root.now.getFullYear());
                if (!Theme.jpEnabled)
                    return y;
                return y + " // " + root.weekdayKanji[(root.now.getDay() + 6) % 7];
            }
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFsMicro
            font.letterSpacing: 1
        }
    }
}
