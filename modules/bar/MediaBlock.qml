import Quickshell.Services.Mpris
import QtQuick
import qs.theme
import qs.modules.common

// MPRIS now-playing ticker: micro MEDIA column + transport glyphs + marquee
// track line. Prefers the playing player; falls back to the first one.
// Scroll runs only while playing AND overflowing — paused/stopped snaps home.
Item {
    id: root

    implicitWidth: col.width
    implicitHeight: Theme.scaledBarHeight

    property var tip

    readonly property var players: Mpris.players.values ?? []
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null

    readonly property string artist: player?.trackArtist ?? ""
    readonly property string title: player?.trackTitle ?? ""
    readonly property string trackLine: {
        const parts = [artist, title].filter(s => s.length > 0);
        return parts.length > 0 ? parts.join(" — ") : (player?.identity ?? "");
    }

    readonly property bool playing: player?.isPlaying ?? false
    readonly property int tickerW: 168
    readonly property bool overflowing: trackText.width > tickerClip.width + 2

    // visibility is gated by the segment model (BarSegments.present("media"));
    // here we only hide when no player exists
    visible: player !== null

    function syncAnim() {
        const run = visible && overflowing && playing;
        if (run) {
            if (!tickerAnim.running)
                tickerAnim.restart();
        } else {
            tickerAnim.stop();
            trackText.x = 0;
        }
    }

    onOverflowingChanged: syncAnim()
    onVisibleChanged: syncAnim()
    onPlayingChanged: syncAnim()
    onPlayerChanged: {
        tickerAnim.stop();
        trackText.x = 0;
        syncAnim();
    }

    NumberAnimation {
        id: tickerAnim

        target: trackText
        property: "x"
        from: tickerClip.width
        to: -trackText.width - 12
        duration: trackText.width > 0 ? Math.max(4000, (tickerClip.width + trackText.width + 12) * 45) : 4000
        loops: Animation.Infinite
    }

    // equalizer bars live inside the transport row above

    Column {
        id: col
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            text: "MEDIA"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFsMicro
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }

        Row {
            spacing: 7

            Row {
                id: eqBars

                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: 3

                    Rectangle {
                        id: eqBar

                        required property int index

                        readonly property int phase: index * 210
                        property real liveH: 3

                        anchors.bottom: parent.bottom
                        width: 2
                        height: root.playing ? liveH : 3
                        color: Theme.acid

                        SequentialAnimation {
                            running: root.visible && root.playing
                            loops: Animation.Infinite

                            PauseAnimation {
                                duration: eqBar.phase
                            }
                            NumberAnimation {
                                target: eqBar
                                property: "liveH"
                                from: 3
                                to: 13 - eqBar.index * 2
                                duration: 340 + eqBar.index * 90
                                easing.type: Easing.InOutSine
                            }
                            NumberAnimation {
                                target: eqBar
                                property: "liveH"
                                to: 4
                                duration: 300 + eqBar.index * 70
                                easing.type: Easing.InOutSine
                            }
                        }

                        Behavior on height {
                            enabled: !root.playing

                            NumberAnimation {
                                duration: Theme.movMed
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            Text {
                id: playPauseIcon
                anchors.verticalCenter: parent.verticalCenter
                text: root.playing ? "\uF04C" : "\uF04B"
                color: root.playing ? Theme.acid : Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(9 * Theme.barScale)

                SequentialAnimation {
                    id: ppBounce
                    running: false

                    NumberAnimation {
                        target: playPauseIcon
                        property: "scale"
                        to: 1.35; duration: Theme.movSnap
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.5
                    }
                    NumberAnimation {
                        target: playPauseIcon
                        property: "scale"
                        to: 1.0; duration: Theme.movMed
                        easing.type: Easing.OutCubic
                    }
                }

                Connections {
                    target: root
                    function onPlayingChanged() { ppBounce.restart(); }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.player?.canGoNext ?? false
                text: "\uF051"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(9 * Theme.barScale)
            }

            Item {
                id: tickerClip
                anchors.verticalCenter: parent.verticalCenter
                width: root.tickerW
                height: 13
                clip: true

                Text {
                    id: trackText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.trackLine
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsLabel
                    onWidthChanged: root.syncAnim()
                }

                // gradient fade at edges — smoother than a hard clip
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 14
                    visible: root.overflowing
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Theme.bg }
                        GradientStop { position: 1; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0) }
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 14
                    visible: root.overflowing
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0) }
                        GradientStop { position: 1; color: Theme.bg }
                    }
                }
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                if (root.player && root.player.canGoNext)
                    root.player.next();
                return;
            }
            // honor the segment click map (default → media widget)
            const a = BarSegments.clickFor("media");
            if (a.length > 0 && BarActions.dispatch(a))
                return;
            ShellState.toggleMedia();
        }

        onWheel: wheel => {
            if (!root.player)
                return;
            if (wheel.angleDelta.y > 0) {
                if (root.player.canGoPrevious)
                    root.player.previous();
            } else if (root.player.canGoNext) {
                root.player.next();
            }
        }

        onContainsMouseChanged: {
            if (!root.tip)
                return;
            if (containsMouse && root.trackLine.length > 0)
                root.tip.showFor(root, root.trackLine + " // " + (root.player?.identity ?? ""));
            else
                root.tip.hide();
        }
    }
}
