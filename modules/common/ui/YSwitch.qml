import QtQuick
import qs.theme

// Square brutalist switch. Track 30×14, sliding block, acid when on.
Rectangle {
    id: root

    property bool checked: false
    signal toggled()

    implicitWidth: 30
    implicitHeight: 14
    color: Theme.bg
    border.width: 1
    border.color: root.checked ? Theme.acid : area.containsMouse ? Theme.ink : Theme.lineStrong

    Rectangle {
        x: root.checked ? parent.width - width - 2 : 2
        anchors.verticalCenter: parent.verticalCenter
        width: 10
        height: 10
        color: root.checked ? Theme.acid : area.containsMouse ? Theme.ink : Theme.faint

        Behavior on x {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: 0
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
