import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."

PanelWindow {
    id: root

    readonly property var targetScreen: FocusMonitor.screen
    screen: targetScreen

    readonly property string corner: ShellState.osdCorner
    readonly property bool topSide: corner.startsWith("t")
    readonly property bool rightSide: corner.endsWith("r")
    readonly property bool centeredX: corner === "tc" || corner === "bc"
    readonly property int pad: Theme.outerPad

    property string kind: "volume"
    readonly property bool isMic: kind === "mic"
    readonly property bool isBright: kind === "bright"
    readonly property bool isThermal: kind === "thermal"

    readonly property var sinkNode: AudioService.sink
    readonly property var srcNode: AudioService.source
    readonly property real frac: isBright ? Math.max(0, Math.min(1, DisplayService.brightPct / 100)) : AudioService.nodeFrac(isMic ? srcNode : sinkNode)
    readonly property int pct: isBright ? DisplayService.brightPct : AudioService.nodePct(isMic ? srcNode : sinkNode)
    readonly property bool sinkMuted: !isMic && !isBright && sinkNode && sinkNode.audio ? sinkNode.audio.muted : false
    readonly property bool hot: isMic ? (srcNode && srcNode.audio ? srcNode.audio.muted : false) : isBright ? false : root.sinkMuted || pct > 100

    readonly property real barFill: root.isThermal ? Math.max(0, Math.min(1, root.thermalTemp / SystemStats.tempCrit)) : Math.max(0, Math.min(1, root.frac))

    // thermal OSD state
    property real thermalTemp: -1
    property bool thermalCritical: false

    readonly property string statusText: root.isThermal
        ? (root.thermalCritical ? "CRITICAL" : "WARNING")
        : root.isMic
        ? (root.hot ? "MUTED" : "LIVE")
        : root.sinkMuted ? "MUTED" : ""
    readonly property string pctText: root.isThermal
        ? SystemStats.fmtTemp(root.thermalTemp)
        : root.isMic ? "" : root.pct + "%"

    function ping(k) {
        const on = k === "bright" ? ShellState.osdBright : k === "mic" ? ShellState.osdMic : k === "thermal" ? ShellState.osdThermal : ShellState.osdVolume;
        if (!on)
            return;
        kind = k;
        shown.opacity = 1;
        shown.y = shown.targetY;
        fadeTimer.restart();
    }

    function pingThermal(temp, crit) {
        thermalTemp = temp;
        thermalCritical = crit;
        ping("thermal");
    }

    anchors {
        top: topSide
        bottom: !topSide
        left: !rightSide || centeredX
        right: rightSide || centeredX
    }

    margins.top: topSide ? Theme.barHeight + pad : 0
    margins.bottom: topSide ? 0 : Theme.sp5
    margins.left: centeredX ? 0 : pad
    margins.right: centeredX ? 0 : pad

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: shown.opacity > 0.01
    mask: Region {
        item: shown.opacity > 0.5 ? shown : null
    }

    WlrLayershell.layer: WlrLayer.Overlay

    implicitWidth: 140
    implicitHeight: 64

    Timer {
        id: fadeTimer

        interval: Math.max(ShellState.osdFadeMs + 300, 1400)
        onTriggered: {
            shown.opacity = 0;
            shown.y = shown.targetY + (root.topSide ? -6 : 6);
        }
    }

    Item {
        id: shown

        property real targetY: root.topSide ? 0 : root.height - height

        x: root.centeredX ? (root.width - width) / 2 : root.rightSide ? root.width - width - root.pad : root.pad
        y: targetY + (root.topSide ? -6 : 6)
        width: root.implicitWidth
        height: root.implicitHeight
        opacity: 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: wheel => {
                const delta = wheel.angleDelta.y > 0 ? 0.03 : -0.03;
                if (root.isBright)
                    DisplayService.setBright(Math.round(Math.max(0, Math.min(1, root.frac + delta)) * 100));
                else if (root.isMic)
                    AudioService.setFrac(root.srcNode, Math.max(0, Math.min(1, root.frac + delta)));
                else
                    AudioService.setFrac(root.sinkNode, Math.max(0, Math.min(1, root.frac + delta)));
                fadeTimer.restart();
            }
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.surface
            border.width: 1
            border.color: root.thermalCritical || root.hot ? Theme.alert : root.isThermal ? Theme.acid : Theme.lineStrong
            radius: Theme.sp1

            Behavior on border.color {
                ColorAnimation {
                    duration: Theme.movFast
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 2
                color: root.thermalCritical || root.hot ? Theme.alert : Theme.acid
                radius: 1

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.movFast
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                anchors.leftMargin: Theme.sp3
                spacing: Theme.sp1

                Text {
                    id: pctText

                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.statusText.length > 0 ? root.statusText : root.pctText
                    color: root.thermalCritical || root.hot ? Theme.alert : root.isThermal ? Theme.acid : root.statusText.length > 0 ? Theme.muted : Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 20
                    font.weight: Font.Bold

                    SequentialAnimation {
                        id: pctPop
                        running: false

                        NumberAnimation {
                            target: pctText
                            property: "scale"
                            to: 1.08; duration: Theme.movSnap
                            easing.type: Easing.OutBack
                            easing.overshoot: 0.4
                        }
                        NumberAnimation {
                            target: pctText
                            property: "scale"
                            to: 1.0; duration: Theme.movMed
                            easing.type: Easing.OutCubic
                        }
                    }

                    Connections {
                        target: root
                        function onFracChanged() { pctPop.restart(); }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.isMic ? "MIC" : root.isBright ? "BRIGHT" : root.isThermal ? "TEMP" : "VOL"
                    color: root.thermalCritical || root.hot ? Theme.alert : root.isThermal ? Theme.acid : Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.sp3
                height: 4
                color: Theme.hairline
                radius: 2

                Rectangle {
                    id: fillBar

                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: root.barFill * parent.width
                    color: root.thermalCritical || root.hot ? Theme.alert : Theme.acid
                    radius: 2

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.movSnap
                            easing.type: Easing.OutBack
                            easing.overshoot: 0.15
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.movFast
                        }
                    }
                }

                // glowing cap at the fill tip
                Rectangle {
                    x: fillBar.width - 3
                    anchors.verticalCenter: parent.verticalCenter
                    width: 8
                    height: 8
                    visible: root.barFill > 0.02 && root.barFill < 0.98
                    color: root.thermalCritical || root.hot ? Theme.alert : Theme.acid
                    opacity: 0.3
                    radius: 4

                    SequentialAnimation on opacity {
                        running: root.visible
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 0.15
                            to: 0.4
                            duration: 700
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: 0.4
                            to: 0.15
                            duration: 700
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: AudioService

        function onOsdPing(k) {
            root.ping(k);
        }
    }

    Connections {
        target: SystemStats

        function onThermalWarning(temp) {
            root.pingThermal(temp, false);
        }

        function onThermalCritical(temp) {
            root.pingThermal(temp, true);
        }
    }
}
