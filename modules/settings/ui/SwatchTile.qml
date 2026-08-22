import QtQuick
import qs.theme
import "../../common/ui"

// Scheme preset swatch: palette preview strip + label bar.
Rectangle {
    id: root

    // preview map: { id, label, bg, ink, acid, alert }
    property var data_: null
    property bool active: false

    signal picked(string id)

    readonly property string sId: data_?.id ?? ""
    readonly property string sLabel: String(data_?.label ?? "")
    readonly property color sBg: data_ ? data_.bg : Theme.bg
    readonly property color sInk: data_ ? data_.ink : Theme.ink
    readonly property color sAcid: data_ ? data_.acid : Theme.acid
    readonly property color sAlert: data_ ? data_.alert : Theme.alert

    implicitWidth: 150
    implicitHeight: 72
    color: root.active ? Theme.bgAlt : area.containsMouse ? Theme.surface : Theme.bg
    border.width: 1
    border.color: root.active ? Theme.acid : area.containsMouse ? Theme.lineStrong : Theme.hairline

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(root.sId)
    }

    // palette preview block
    Rectangle {
        id: preview

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 3
        height: parent.height - 26
        color: root.sBg

        Rectangle {
            x: 8
            y: 7
            width: 11
            height: 11
            color: root.sInk
        }

        Rectangle {
            x: 8
            y: 25
            width: 46
            height: 5
            color: root.sAcid
        }

        Rectangle {
            x: 60
            y: 25
            width: 14
            height: 5
            color: root.sAlert
        }

        Text {
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 6
            text: "Aa"
            color: root.sInk
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBody
            font.weight: Font.Bold
        }

        Rectangle {
            visible: root.active
            anchors.right: parent.right
            anchors.top: parent.top
            width: 10
            height: 10
            color: root.sAcid
        }
    }

    // label bar
    Item {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 20

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.sp2
            text: root.sLabel.toUpperCase()
            color: root.active ? Theme.acid : area.containsMouse ? Theme.ink : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.weight: Font.Bold
            font.letterSpacing: 2
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            anchors.rightMargin: Theme.sp2
            visible: root.active
            text: "ACTIVE"
            color: Theme.acid
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.weight: Font.Bold
            font.letterSpacing: 1
        }
    }
}
