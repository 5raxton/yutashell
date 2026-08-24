import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import qs.theme
import qs.modules.common
import "."

Item {
    id: root

    implicitWidth: audRow.width
    implicitHeight: Theme.barHeight

    property var tip

    readonly property var sink: AudioService.sink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int pct: AudioService.nodePct(sink)
    readonly property bool overdriven: pct > 100
    // five bars across the FULL ceiling
    readonly property int tiers: muted ? 0 : Math.max(pct > 0 ? 1 : 0, Math.round(AudioService.volToFrac(pct / 100) * 5))
    readonly property var src: AudioService.source
    readonly property bool micMuted: src && src.audio ? src.audio.muted : true

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
                AudioService.toggleMute(root.sink);
                return;
            }
            // honor the segment click map (default → audio panel)
            const a = BarSegments.clickFor("audio");
            if (a.length > 0 && BarActions.dispatch(a))
                return;
            ShellState.toggleAudio();
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0)
                AudioService.stepPct(root.sink, 5);
            else
                AudioService.stepPct(root.sink, -5);
            AudioService.osdPing("volume");
        }
    }

    Row {
        id: audRow

        anchors.verticalCenter: parent.verticalCenter

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "VOL"
            color: root.muted ? Theme.alert : root.overdriven ? Theme.acid : Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.weight: Font.Bold
            font.letterSpacing: 1.5

            Behavior on color {
                ColorAnimation {
                    duration: Theme.movFast
                }
            }
        }

        Item {
            width: 8
            height: 1
        }

        // output level bars — the fifth tier only exists past 100 %
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
                        if (root.muted)
                            return Theme.lineStrong;
                        if (index >= 4 && !root.overdriven)
                            return Theme.hairline;
                        return root.tiers > index ? (root.overdriven && index >= 4 ? Theme.alert : Theme.acid) : Theme.lineStrong;
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.movFast
                        }
                    }
                }
            }
        }

        Item {
            width: 8
            height: 1
        }

        // mic state: slashed ring when muted, acid dot when live
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            color: root.micMuted ? "transparent" : Theme.acid
            border.width: 1
            border.color: root.micMuted ? Theme.alert : Theme.acid

            Rectangle {
                visible: root.micMuted
                anchors.verticalCenter: parent.verticalCenter
                x: -3
                width: parent.width + 6
                height: 1
                color: Theme.alert
                rotation: -35
            }
        }
    }

    Connections {
        function onPressedChanged() {
            if (area.pressed)
                ;
            else if (area.containsMouse) {
                const dev = AudioService.sink ? AudioService.deviceLabel(AudioService.sink) : "no device";
                root.showCol(audRow, (root.muted ? "muted · " : "") + dev + " · " + root.pct + "%" + (root.micMuted ? "" : " · mic live"));
            } else
                root.hideCol();
        }

        target: area
    }
}
