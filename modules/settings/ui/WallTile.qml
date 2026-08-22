import QtQuick
import qs.theme

Item {
    id: root

    property string path: ""
    property string label: ""
    property bool active: false

    signal picked(string path)

    implicitWidth: 104
    implicitHeight: 64

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
        border.width: root.active ? 1 : (area.containsMouse ? 1 : 0)
        border.color: root.active ? Theme.acid : Theme.lineStrong

        Image {
            anchors.fill: parent
            anchors.margins: 2
            source: root.path.length > 0 ? "file://" + root.path : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            opacity: area.containsMouse || root.active ? 1 : 0.75
        }

        Rectangle {
            visible: root.active
            anchors.left: parent.left
            anchors.top: parent.top
            width: 8
            height: 8
            color: Theme.acid
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: nameText.visible ? 14 : 0
            color: "#e0000000"
            visible: area.containsMouse && !root.active
        }

        Text {
            id: nameText
            visible: area.containsMouse && !root.active
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: 3
            text: root.label
            elide: Text.ElideRight
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 7
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.picked(root.path)
    }
}
