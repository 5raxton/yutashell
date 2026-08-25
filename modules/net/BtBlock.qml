import Quickshell
import Quickshell.Bluetooth
import QtQuick
import qs.theme
import qs.modules.bar
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
        // honor the segment click map; a cleared action falls back to the panel
        onClicked: {
            if (BarActions.dispatch(BarSegments.clickFor("bt")))
                return;
            ShellState.toggleBt();
        }
    }

    Row {
        id: btRow

        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "BT"
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.adapter && root.adapter.discovering ? "◦◦" : "◆"
            color: Theme.acid
            font.family: Theme.fontFamily
            font.pixelSize: 10

            // scanning: the glyph hunts — blinks while the radio sweeps
            SequentialAnimation on opacity {
                running: root.visible && root.adapter && root.adapter.discovering
                loops: Animation.Infinite

                NumberAnimation {
                    from: 1.0
                    to: 0.25
                    duration: 420
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 0.25
                    to: 1.0
                    duration: 420
                    easing.type: Easing.InOutSine
                }
            }

            Behavior on opacity {
                enabled: !(root.adapter && root.adapter.discovering)

                NumberAnimation {
                    duration: Theme.movMed
                }
            }
        }
    }

    Connections {
        function onPressedChanged() {
            if (!area.pressed && area.containsMouse)
                root.showCol(btRow, "bluetooth · " + (root.adapter ? root.adapter.devices.values.length + " devices" : "no adapter"));
            else if (!area.pressed)
                root.hideCol();
        }

        target: area
    }
}
