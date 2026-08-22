import QtQuick
import qs.theme

Rectangle {
    id: root

    property string label: "ACTION"

    signal clicked()

    implicitWidth: innerText.width + 22
    implicitHeight: 24
    color: area.containsMouse ? Theme.ink : Theme.bgAlt
    border.width: 1
    border.color: area.containsMouse ? Theme.ink : Theme.lineStrong

    Text {
        id: innerText

        anchors.centerIn: parent
        text: root.label.toUpperCase()
        color: area.containsMouse ? Theme.bg : Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: 9
        font.weight: Font.DemiBold
        font.letterSpacing: 1.5
    }

    MouseArea {
        id: area

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
