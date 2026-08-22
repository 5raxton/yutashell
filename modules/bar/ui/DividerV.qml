import QtQuick
import qs.theme

Item {
    id: root

    implicitWidth: 13
    implicitHeight: Theme.barHeight

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 20
        color: Theme.lineStrong
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8
        width: 7
        height: 1
        color: Theme.faint
    }

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 5
        width: 1
        height: 7
        color: Theme.faint
    }
}
