import QtQuick
import qs.theme

Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    signal accepted()

    implicitWidth: 180
    implicitHeight: 24
    color: Theme.bg
    border.width: 1
    border.color: input.activeFocus ? Theme.acid : Theme.hairline

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: 9
        clip: true
        selectByMouse: true
        cursorVisible: activeFocus
        onAccepted: root.accepted()

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0 && !input.activeFocus
            text: root.placeholder.toUpperCase()
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.letterSpacing: 1
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: input.activeFocus ? Theme.acid : "transparent"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }
}
