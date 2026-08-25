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
        Keys.onUpPressed: event => {
            if (root.navKeys) {
                event.accepted = true;
                root.navUp();
            }
        }
        Keys.onDownPressed: event => {
            if (root.navKeys) {
                event.accepted = true;
                root.navDown();
            }
        }
        Keys.onLeftPressed: event => {
            if (root.navKeys) {
                event.accepted = true;
                root.navLeft();
            }
        }
        Keys.onRightPressed: event => {
            if (root.navKeys) {
                event.accepted = true;
                root.navRight();
            }
        }
        Keys.onTabPressed: event => {
            if (root.navKeys) {
                event.accepted = true;
                root.navTab();
            }
        }
        Keys.onEscapePressed: event => {
            if (root.navKeys) {
                event.accepted = true;
                root.navEscape();
            } else {
                // blur only — the surface's own ESC handler closes it on a
                // second press; one ESC must not do both at once
                event.accepted = true;
                input.focus = false;
            }
        }
        Keys.onDeletePressed: event => {
            if (root.navKeys && (event.modifiers & Qt.ShiftModifier)) {
                event.accepted = true;
                root.navShiftDel();
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text.length === 0 && !input.activeFocus
            text: root.placeholder
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBody
            font.letterSpacing: 0.5
            opacity: 0.7
            x: Theme.sp2 + 2

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.movFast
                }
            }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: root.focused ? Theme.acid : "transparent"
    }

    // Focus/caret helper while unfocused. Once the field has focus this must
    // yield to the TextInput so native caret placement and drag-selection
    // work — an always-on overlay eats every press.
    MouseArea {
        anchors.fill: parent
        enabled: !input.activeFocus
        cursorShape: Qt.IBeamCursor
        onClicked: input.forceActiveFocus()
    }
}
