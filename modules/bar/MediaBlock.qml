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
    implicitHeight: Theme.barHeight

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

    visible: ShellState.barMedia && player !== null

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
        duration: Math.max(4000, (tickerClip.width + trackText.width + 12) * 45)
        loops: Animation.Infinite
    }

    Column {
        id: col
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            text: "MEDIA"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 7
            font.letterSpacing: 1.5
        }

        Row {
            spacing: 7

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.playing ? "\uF04C" : "\uF04B"
                color: root.playing ? Theme.acid : Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 9
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.player?.canGoNext ?? false
                text: "\uF051"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: 9
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
                    font.pixelSize: 10
                    onWidthChanged: root.syncAnim()
                }

                // edge fade hint that the line continues (static mask strip)
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 10
                    visible: root.overflowing
                    color: Theme.bg
                    opacity: 0.75
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
            if (!root.player)
                return;
            if (mouse.button === Qt.MiddleButton) {
                if (root.player.canGoNext)
                    root.player.next();
                return;
            }
            if (root.player.canTogglePlaying)
                root.player.togglePlaying();
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
                root.tip.showFor(root, root.trackLine + " // " + (root.player.identity ?? ""));
            else
                root.tip.hide();
        }
    }
}
