import Quickshell
import Quickshell.Bluetooth
import QtQuick
import qs.theme
import qs.modules.common

Item {
    id: root

    implicitHeight: Theme.barHeight

    property var tip

    readonly property var adapter: Bluetooth.defaultAdapter

    // hidden entirely when there is nothing to show; the Bar also gates on barBt
    readonly property bool present: adapter !== null && adapter.enabled

    visible: present
    implicitWidth: present ? btRow.width : 0

    function showCol(item, text) {
        if (tip)
            tip.showFor(item, text);
    }

    function hideCol() {
        if (tip)
            tip.hide();
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.toggleBt()
    }

    Row {
        id: btRow

        anchors.verticalCenter: parent.verticalCenter

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "BT"
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }

        Item {
            width: 8
            height: 1
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.adapter && root.adapter.discovering ? "◦◦" : "◆"
            color: Theme.acid
            font.family: Theme.fontFamily
            font.pixelSize: 10
        }
    }

    Connections {
        function onPressedChanged() {
            if (area.pressed)
                ;
            else if (area.containsMouse)
                root.showCol(btRow, "bluetooth · " + (root.adapter ? root.adapter.devices.values.length + " devices" : "no adapter"));
            else
                root.hideCol();
        }

        target: area
    }
}
