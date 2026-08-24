import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."

// The OSD — brutal horizontal gauge that stamps itself onto the screen on
// volume/mic/brightness events and fades away. One instance, three kinds.
PanelWindow {
    id: root

    // primary display of whatever screens exist at boot
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
    // volume kind reports the SINK's mute so `audio mute` reads honestly
    // (it used to be indistinguishable from an unmuted change)
    readonly property bool sinkMuted: !isMic && !isBright && sinkNode && sinkNode.audio ? sinkNode.audio.muted : false
    readonly property bool hot: isMic ? (srcNode && srcNode.audio ? srcNode.audio.muted : false) : isBright ? false : root.sinkMuted || pct > 100

    function ping(k) {
        // per-kind gates (settings → OSD): a disabled kind swallows the ping
        const on = k === "bright" ? ShellState.osdBright : k === "mic" ? ShellState.osdMic : ShellState.osdVolume;
        if (!on)
            return;
        // key-hold bursts land here dozens of times a second — keep this path
        // free of animation restarts: cancel the outro (so the fade-in
        // Behavior owns the property again), pin opacity, rewind the clock
        if (outro.running)
            outro.stop();
        kind = k;
        shown.opacity = 1;
        fadeTimer.restart();
    }

    anchors {
        top: topSide
        bottom: !topSide
        left: !rightSide || centeredX
        right: rightSide || centeredX
    }

    margins.top: topSide ? Theme.barHeight + pad : pad + 6
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
    implicitHeight: 64

    Timer {
        id: fadeTimer

        // floor at 1.4 s: key-repeat bursts can gap when the IPC queue backs
        // up, and the OSD must ride out any pause shorter than a deliberate
        // stop — the configured fade only ever extends it
        interval: Math.max(ShellState.osdFadeMs + 300, 1400)
        onTriggered: {
            if (!outro.running)
                outro.restart();
        }
    }

    SequentialAnimation {
        id: outro

        NumberAnimation {
            target: shown
            property: "opacity"
            to: 0
            duration: Theme.movMed
            easing.type: Easing.OutCubic
        }
    }

    Rectangle {
        id: shown

        anchors.fill: parent
        color: Theme.bgAlt
        border.width: 1
        border.color: root.hot ? Theme.alert : Theme.lineStrong
        opacity: 0

        // drifts toward its edge as it fades — a pure function of opacity, so
        // entrance/exit ride the one animation with zero extra cost
        transform: Translate {
            y: (1 - shown.opacity) * (root.topSide ? -5 : 5)
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.movFast
            }
        }

        // accent spine — the tooltip's signature, shared language
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            color: root.hot ? Theme.alert : Theme.acid

            Behavior on color {
                ColorAnimation {
                    duration: Theme.movFast
                }
            }
        }

        Text {
            id: tagText

            x: Theme.sp3
            y: Theme.sp2
            text: root.isMic ? "MIC" : root.isBright ? "BRIGHT" : "VOL"
            color: root.hot ? Theme.alert : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }

        Text {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.sp2
            text: root.isMic ? (root.hot ? "MUTED" : "LIVE") : root.isBright ? root.pct + "%" : root.sinkMuted ? "MUTED" : (root.pct > 100 ? "+" : "") + root.pct + "%"
            color: root.hot ? Theme.alert : root.pct > 100 && !root.sinkMuted ? Theme.acid : Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBody
            font.weight: Font.DemiBold
        }

        YSlider {
            id: slider

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.sp3 - 4
            anchors.leftMargin: Theme.sp3
            anchors.rightMargin: Theme.sp3
            implicitHeight: 20
            value: root.frac
            onMoved: v => {
                if (root.isBright)
                    DisplayService.setBright(Math.round(v * 100));
                else if (root.isMic)
                    AudioService.setFrac(root.srcNode, v);
                else
                    AudioService.setFrac(root.sinkNode, v);
                fadeTimer.restart();
            }
        }

        // the current — every chrome carries it
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            height: 2
            width: root.frac * parent.width
            color: root.hot ? Theme.alert : Theme.acid

            Behavior on width {
                NumberAnimation {
                    duration: Theme.movSnap
                    easing.type: Easing.OutCubic
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
}
