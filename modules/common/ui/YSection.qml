import QtQuick
import qs.theme

// Section header: index glyph + title + flex rule + optional trailing chip.
Item {
    id: root

    property string index: ""
    property string label: ""
    property string chip: ""

    implicitWidth: 300
    implicitHeight: 22

    Text {
        id: idx

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        visible: root.index.length > 0
        text: root.index
        color: Theme.acid
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsMicro
        font.weight: Font.Bold
    }

    Text {
        id: title

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.index.length > 0 ? 18 : 0
        text: root.label.toUpperCase()
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
        font.weight: Font.Bold
        font.letterSpacing: 2.5
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: title.right
        anchors.leftMargin: Theme.sp2
        anchors.right: chipText.visible ? chipText.left : parent.right
        anchors.rightMargin: chipText.visible ? Theme.sp2 : 0
        height: 1
        color: Theme.hairline
    }

    Text {
        id: chipText

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        visible: root.chip.length > 0
        text: root.chip.toUpperCase()
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsMicro
        font.letterSpacing: 1
    }
}
