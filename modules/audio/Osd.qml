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

    readonly property var sinkNode: AudioService.sink
    readonly property var srcNode: AudioService.source
    readonly property real frac: isBright ? Math.max(0, Math.min(1, DisplayService.brightPct / 100)) : AudioService.nodeFrac(isMic ? srcNode : sinkNode)
    readonly property int pct: isBright ? DisplayService.brightPct : AudioService.nodePct(isMic ? srcNode : sinkNode)
    readonly property bool sinkMuted: !isMic && !isBright && sinkNode && sinkNode.audio ? sinkNode.audio.muted : false
    readonly property bool hot: isMic ? (srcNode && srcNode.audio ? srcNode.audio.muted : false) : isBright ? false : root.sinkMuted || pct > 100

    readonly property real barFill: Math.max(0, Math.min(1, root.frac))

    function ping(k) {
        const on = k === "bright" ? ShellState.osdBright : k === "mic" ? ShellState.osdMic : ShellState.osdVolume;
        if (!on)
            return;
        if (outro.running)
            outro.stop();
        kind = k;
        shown.opacity = 1;
        shown.y = shown.targetY;
        fadeTimer.restart();
    }

    anchors {
        top: topSide
        bottom: !topSide
        left: !rightSide || centeredX
        right: rightSide || centeredX
    }

    margins.top: topSide ? Theme.barHeight + pad : pad + 4
    margins.left: centeredX ? 0 : pad
    margins.right: centeredX ? 0 : pad

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: fadeTimer.running || outro.running
    mask: Region {
        item: shown.opacity > 0.5 ? shown : null
    }

    WlrLayershell.layer: WlrLayer.Overlay

    implicitWidth: ShellState.osdWidth
    implicitHeight: 44

    Timer {
        id: fadeTimer

        interval: Math.max(ShellState.osdFadeMs + 300, 1400)
        onTriggered: {
            if (!outro.running)
                outro.restart();
        }
    }

    ParallelAnimation {
        id: outro

        running: false

        NumberAnimation {
            target: shown
            property: "opacity"
            to: 0
            duration: Theme.movFast
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: shown
            property: "y"
            to: shown.targetY - (root.topSide ? 4 : -4)
            duration: Theme.movFast
            easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: intro

        running: false

        NumberAnimation {
            target: shown
            property: "opacity"
            from: 0
            to: 1
            duration: Theme.movMed
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: shown
            property: "y"
            from: shown.targetY + (root.topSide ? -6 : 6)
            to: shown.targetY
            duration: Theme.movMed
            easing.type: Easing.OutCubic
        }
    }

    Item {
        id: shown

        property real targetY: root.topSide ? 0 : root.height - height
        property real targetX: root.centeredX ? (root.width - width) / 2 : root.rightSide ? root.width - width - root.pad : root.pad

        x: targetX
        y: targetY + (root.topSide ? -6 : 6)
        width: root.width - root.pad * 2
        height: root.height - 6
        opacity: 0

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
            color: Theme.bgAlt
            border.width: 1
            border.color: root.hot ? Qt.rgba(Theme.alert.r, Theme.alert.g, Theme.alert.b, 0.3) : Theme.hairline
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
                color: root.hot ? Theme.alert : Theme.acid
                radius: 1

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.movFast
                    }
                }
            }

            Text {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Theme.sp2
                text: root.isMic ? "MIC" : root.isBright ? "BRIGHT" : "VOL"
                color: root.hot ? Theme.alert : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.weight: Font.Bold
                font.letterSpacing: 1
            }

            Text {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.sp2
                text: root.isMic
                    ? (root.hot ? "MUTED" : "LIVE")
                    : root.isBright
                        ? root.pct + "%"
                        : root.sinkMuted
                            ? "MUTED"
                            : (root.pct > 100 ? "+" : "") + root.pct + "%"
                color: root.hot ? Theme.alert : root.pct > 100 && !root.sinkMuted ? Theme.acid : Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLabel
                font.weight: Font.DemiBold
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: Theme.sp2
                height: 3
                color: Theme.hairline
                radius: 1

                Rectangle {
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    width: root.barFill * parent.width
                    color: root.hot ? Theme.alert : Theme.acid
                    radius: 1

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.movSnap
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.movFast
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

    onVisibleChanged: {
        if (visible && !outro.running) {
            intro.restart();
        }
    }
}
