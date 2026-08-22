import QtQuick
import qs.theme
import qs.modules.common

Rectangle {
    id: root

    required property int index
    required property var modelData

    property bool active: false
    property bool cursor: false

    signal picked(string path)
    signal hoveredIndex(int index)

    implicitWidth: 140
    implicitHeight: 88
    color: Theme.bg
    border.width: root.active || root.cursor ? 1 : 1
    border.color: root.active ? Theme.acid : root.cursor ? Theme.ink : tileArea.containsMouse ? Theme.lineStrong : Theme.hairline

    Image {
        anchors.fill: parent
        anchors.margins: 2
        // thumbnail decode only — sourceSize caps the decode buffer; the open
        // gate defers loads until the picker is shown (OOM incident: full-res
        // decodes of every indexed wallpaper killed the session)
        source: root.modelData.path.length > 0 && ShellState.pickerOpen ? "file://" + root.modelData.path : ""
        sourceSize.width: 256
        sourceSize.height: 160
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        opacity: tileArea.containsMouse || root.active || root.cursor ? 1 : 0.72
    }

    // active corner tick
    Rectangle {
        visible: root.active
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 2
        width: 9
        height: 9
        color: Theme.acid
    }

    // keyboard cursor underline
    Rectangle {
        visible: root.cursor && !root.active
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 3
        color: Theme.acid
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: nameText.visible ? 16 : 0
        color: "#e6000000"
        visible: tileArea.containsMouse
    }

    Text {
        id: nameText

        visible: tileArea.containsMouse && !root.active
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 3
        text: root.modelData.label
        elide: Text.ElideRight
        color: Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsMicro
    }

    Text {
        visible: root.active
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
        text: "ACTIVE"
        color: Theme.acid
        font.family: Theme.fontFamily
        font.pixelSize: 6
        font.weight: Font.Bold
        font.letterSpacing: 1
    }

    MouseArea {
        id: tileArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onContainsMouseChanged: {
            if (containsMouse)
                root.hoveredIndex(root.index);
        }
        onClicked: root.picked(root.modelData.path)
    }
}
