import QtQuick
import qs.theme

Item {
    id: root

    property string label: ""

    implicitWidth: labelGlyph.width + 8 + labelText.width + 8 + rule.width
    implicitHeight: 14

    Text {
        id: labelGlyph

        anchors.verticalCenter: parent.verticalCenter
        text: "+"
        color: Theme.acid
        font.family: Theme.fontFamily
        font.pixelSize: 9
        font.weight: Font.Bold
    }

    Text {
        id: labelText

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: labelGlyph.right
        anchors.leftMargin: 5
        text: root.label.toUpperCase()
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 7
        font.letterSpacing: 2
    }

    Rectangle {
        id: rule

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: labelText.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        height: 1
        color: Theme.hairline
    }
}
