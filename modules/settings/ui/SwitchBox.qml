import QtQuick
import qs.theme

Rectangle {
    id: root

    property bool checked: false

    signal toggled()

    implicitWidth: 26
    implicitHeight: 13
    color: "transparent"
    border.width: 1
    border.color: root.checked ? Theme.acid : Theme.lineStrong

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Rectangle {
        x: root.checked ? parent.width - width - 2 : 2
        anchors.verticalCenter: parent.verticalCenter
        width: 9
        height: 9
        color: root.checked ? Theme.acid : Theme.faint

        Behavior on x {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 0
        }
    }
}
