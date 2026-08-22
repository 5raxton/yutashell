import QtQuick
import qs.theme

// Single-line input. Focus = acid left bar + stronger border.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    signal accepted()

    function forceFocus() {
        input.forceActiveFocus();
    }

    readonly property bool focused: input.activeFocus

    implicitWidth: 180
    implicitHeight: Theme.ctlH
    color: Theme.bg
    border.width: 1
    border.color: root.focused ? Theme.lineStrong : Theme.hairline

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: Theme.sp2 + 2
        anchors.rightMargin: Theme.sp2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsBody
        clip: true
        selectByMouse: true
        cursorVisible: activeFocus
        onAccepted: root.accepted()
        Keys.onEscapePressed: input.focus = false

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0 && !input.activeFocus
            text: root.placeholder
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsLabel
            font.letterSpacing: 0.5
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: root.focused ? Theme.acid : "transparent"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }
}
