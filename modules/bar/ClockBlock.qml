import QtQuick
import qs.theme

Item {
    id: root

    implicitWidth: timeBlock.width + 14 + dateCol.width
    implicitHeight: Theme.barHeight

    property date now: new Date()
    property bool colonOn: true

    readonly property var weekdayKanji: ["月", "火", "水", "木", "金", "土", "日"]

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
            text: String(root.now.getHours()).padStart(2, "0")
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            id: colonText
            anchors.baseline: hhText.baseline
            anchors.left: hhText.right
            text: ":"
            opacity: root.colonOn ? 1 : 0.2
            color: Theme.acid
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            id: mmText
            anchors.baseline: hhText.baseline
            anchors.left: colonText.right
            text: String(root.now.getMinutes()).padStart(2, "0")
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 15
            font.weight: Font.DemiBold
        }

        Text {
            id: ssText
            anchors.baseline: hhText.baseline
            anchors.left: mmText.right
            anchors.leftMargin: 5
            text: ":" + String(root.now.getSeconds()).padStart(2, "0")
            color: Theme.acid
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }

    Column {
        id: dateCol
        anchors.left: timeBlock.right
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            text: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][root.now.getDay()] + " " + Qt.formatDate(root.now, "MM.dd")
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 8
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
            font.pixelSize: 8
            font.letterSpacing: 1
        }
    }
}
