import QtQuick
import qs.theme
import "."

Rectangle {
    id: root

    property string tplId: ""
    property string output: ""
    property bool enabled_: false

    signal toggled(bool on)
    signal removed()

    implicitWidth: 300
    implicitHeight: 34
    color: area.containsMouse ? Theme.surface : Theme.bg
    border.width: 1
    border.color: root.enabled_ ? Theme.hairline : Theme.hairline

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: root.enabled_ ? Theme.acid : Theme.faint
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 10
        spacing: 2
        width: parent.width - 90

        Text {
            text: root.tplId.toUpperCase()
            color: root.enabled_ ? Theme.ink : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 1
        }

        Text {
            width: parent.width
            text: root.output
            elide: Text.ElideMiddle
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: 7
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: switchBox.left
        anchors.rightMargin: 10
        text: "×"
        color: delArea.containsMouse ? Theme.alert : Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 12

        MouseArea {
            id: delArea
            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.removed()
        }
    }

    SwitchBox {
        id: switchBox
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: 8
        checked: root.enabled_
        onToggled: root.toggled(!root.enabled_)
    }
}
