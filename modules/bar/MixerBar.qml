import Quickshell
import QtQuick
import qs.theme
import qs.modules.bar
import qs.modules.common
import qs.modules.audio

Item {
    id: root

    implicitWidth: mxRow.width
    implicitHeight: Theme.scaledBarHeight

    property var tip

    readonly property var sink: MixerService.currentSink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int pct: MixerService.volumePct(sink)
    readonly property int tiers: muted ? 0 : Math.max(pct > 0 ? 1 : 0, Math.round(AudioService.nodeFrac(sink) * 5))

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
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                MixerService.toggleMasterMute();
                return;
            }
            if (BarActions.dispatch(BarSegments.clickFor("mixer")))
                return;
            ShellState.toggleMixer();
        }
        onWheel: wheel => {
            MixerService.stepMaster(wheel.angleDelta.y > 0 ? 5 : -5);
        }
    }

    Row {
        id: mxRow

        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "MX"
            color: muted ? Theme.alert : Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFsMicro
            font.weight: Font.Bold
            font.letterSpacing: 1.5

            Behavior on color {
                ColorAnimation { duration: Theme.movFast }
            }
        }

        // output level bars
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: 5

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: 3
                    height: 3 + index * 3
                    color: {
                        if (root.muted) return Theme.lineStrong;
                        return root.tiers > index ? Theme.acid : Theme.lineStrong;
                    }

                    Behavior on color {
                        ColorAnimation { duration: Theme.movFast }
                    }
                }
            }
        }
    }

    Connections {
        function onPressedChanged() {
            if (!area.pressed && area.containsMouse) {
                const dev = MixerService.currentSink ? AudioService.deviceLabel(MixerService.currentSink) : "no device";
                root.showCol(mxRow, (root.muted ? "muted · " : "") + dev + " · " + root.pct + "%");
            } else if (!area.pressed) {
                root.hideCol();
            }
        }

        target: area
    }
}
