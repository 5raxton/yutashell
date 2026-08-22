import QtQuick
import qs.theme

Rectangle {
    id: root

    // scheme preview map: { id, label, bg, ink, acid, alert }
    property var data_: null
    property bool active: false

    signal picked(string id)

    readonly property string sId: data_?.id ?? ""
    readonly property string sLabel: String(data_?.label ?? "").toUpperCase()
    readonly property color sBg: data_ ? data_.bg : Theme.bg
    readonly property color sInk: data_ ? data_.ink : Theme.ink
    readonly property color sAcid: data_ ? data_.acid : Theme.acid
    readonly property color sAlert: data_ ? data_.alert : Theme.alert

    implicitWidth: 150
    implicitHeight: 62
    color: area.containsMouse && !root.active ? Theme.surface : Theme.bg
    border.width: root.active ? 1 : (area.containsMouse ? 1 : 0)
    border.color: root.active ? Theme.acid : Theme.lineStrong

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
        height: parent.height - 18
        color: root.sBg

        Rectangle {
            x: 8
            y: 8
            width: 12
            height: 12
            color: root.sInk
        }

        Rectangle {
            x: 8
            y: 26
            width: 44
            height: 5
            color: root.sAcid
        }

        Rectangle {
            x: 58
            y: 26
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
            font.pixelSize: 10
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
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 4
        text: root.sLabel
        color: root.active ? Theme.acid : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 7
        font.letterSpacing: 2
    }
}
