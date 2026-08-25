import QtQuick
import qs.theme

// Square brutalist switch. Track 30×14, sliding block with OutBack snap,
// acid fill wiping in when ON — the knob rides the current.
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 30
    implicitHeight: 14
    activeFocusOnTab: true
    color: Theme.bg
    border.width: 1
    border.color: activeFocus ? Theme.acid : root.checked ? Theme.acid : area.containsMouse ? Theme.ink : Theme.lineStrong

    Keys.onReturnPressed: event => {
        event.accepted = true;
        root.toggled();
    }
    Keys.onSpacePressed: event => {
        event.accepted = true;
        root.toggled();
    }

    // acid fill wipes toward the knob side when on
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 2
        width: root.checked ? parent.width - 4 : 0
        height: parent.height - 4
        color: Theme.acid
        opacity: 0.28

        Behavior on width {
            NumberAnimation {
                duration: Theme.movSnap
                easing.type: Easing.OutCubic
            }
        }
    }

    Rectangle {
        id: knob

        x: root.checked ? parent.width - width - 2 : 2
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 10
        color: root.checked ? Theme.acid : area.containsMouse ? Theme.ink : Theme.faint
        scale: root.checked ? 1.15 : 1

        Behavior on x {
            NumberAnimation {
                duration: Theme.movMed
                easing.type: Easing.OutBack
                easing.overshoot: 0.45
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.movSnap
                easing.type: Easing.OutBack
                easing.overshoot: 0.6
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.movSnap
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }
}
