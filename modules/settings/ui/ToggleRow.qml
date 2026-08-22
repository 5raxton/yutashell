import QtQuick
import qs.theme
import "."

Item {
    id: root

    property string label: ""
    property string sub: ""
    property bool checked: false

    signal toggled()

    implicitWidth: labelCol.width + 12 + switchBox.width
    implicitHeight: Math.max(34, labelCol.height + 8)

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Rectangle {
        anchors.fill: parent
        color: area.containsMouse ? Theme.surface : "transparent"
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: root.checked ? Theme.acid : "transparent"
    }

    Column {
        id: labelCol

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        spacing: 3

        Text {
            text: root.label.toUpperCase()
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1
        }

        Text {
            visible: root.sub.length > 0
            text: root.sub.toUpperCase()
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 7
            font.letterSpacing: 1.5
        }
    }

    SwitchBox {
        id: switchBox

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        checked: root.checked
        onToggled: root.toggled()
    }
}
