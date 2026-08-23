import QtQuick
import qs.theme

// Single-line input. Focus = acid left bar + stronger border.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property int echoMode: TextInput.Normal
    signal accepted()

    // Nav-keys model for surfaces driving a list from the field (launcher):
    // arrows/tab/esc/shift-del surface as signals instead of moving focus.
    // Default off — existing consumers see zero behavior change.
    property bool navKeys: false
    signal navUp()
    signal navDown()
    signal navLeft()
    signal navRight()
    signal navTab()
    signal navEscape()
    signal navShiftDel()

    function forceFocus() {
        input.forceActiveFocus();
    }

    readonly property bool focused: input.activeFocus

    implicitWidth: 180
    implicitHeight: Theme.ctlH
    color: Theme.bg
    border.width: 1
    border.color: root.focused ? Theme.lineStrong : Theme.hairline

    // focus underline draws in — the field is live
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        height: 2
        width: root.focused ? parent.width : 0
        color: Theme.acid

        Behavior on width {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }
    }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: Theme.sp2 + 2
        anchors.rightMargin: Theme.sp2
        verticalAlignment: TextInput.AlignVCenter
        echoMode: root.echoMode
        color: Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsBody
        clip: true
        selectByMouse: true
        cursorVisible: activeFocus
        onAccepted: root.accepted()
        Keys.onUpPressed: if (root.navKeys) {
            event.accepted = true;
            root.navUp();
        }
        Keys.onDownPressed: if (root.navKeys) {
            event.accepted = true;
            root.navDown();
        }
        Keys.onLeftPressed: if (root.navKeys) {
            event.accepted = true;
            root.navLeft();
        }
        Keys.onRightPressed: if (root.navKeys) {
            event.accepted = true;
            root.navRight();
        }
        Keys.onTabPressed: if (root.navKeys) {
            event.accepted = true;
            root.navTab();
        }
        Keys.onEscapePressed: if (root.navKeys) {
            event.accepted = true;
            root.navEscape();
        } else {
            input.focus = false;
        }
        Keys.onDeletePressed: if (root.navKeys && (event.modifiers & Qt.ShiftModifier)) {
            event.accepted = true;
            root.navShiftDel();
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0 && !input.activeFocus
            text: root.placeholder
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBody
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
