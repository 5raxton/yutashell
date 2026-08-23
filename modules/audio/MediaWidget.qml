import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"

// MPRIS mini-widget — the Phase 1 ticker grown up: album art (acid square
// when the stream has none), seekbar with position tracking, transport row.
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: ShellState.mediaOpen || hideDelay.running
    mask: Region {
        item: ShellState.mediaOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.mediaOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: 480
    readonly property int cardH: 200

    readonly property var players: Mpris.players.values ?? []
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null

    // local position clock — MPRIS only reports on seek/track change
    property real posSec: 0
    readonly property real lenSec: player && player.lengthSupported ? player.length / 1000000 : 0

    Timer {
        id: hideDelay

        interval: 190
    }

    Timer {
        id: posTimer

        interval: 500
        running: root.visible && root.playing && root.lenSec > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.player)
                return;
            if (root.player.positionSupported) {
                const p = root.player.position / 1000000;
                // trust reported positions that are sane for this track;
                // between MPRIS updates keep the clock moving ourselves
                if (p > 0 && p <= root.lenSec + 1)
                    root.posSec = p;
                else
                    root.posSec = Math.min(root.lenSec, root.posSec + 0.5);
            } else
                root.posSec = Math.min(root.lenSec, root.posSec + 0.5);
        }
    }

    readonly property bool playing: player?.isPlaying ?? false

    onPlayerChanged: posSec = 0

    function fmt(s) {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeMedia()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeMedia()
        }

        YSurface {
            id: surface

            open: ShellState.mediaOpen
            anchorX: "center"
            cardW: root.cardW
            cardH: root.cardH

            Row {
                x: Theme.sp4
                y: Theme.sp4 + Theme.sp1
                width: surface.width - Theme.sp4 * 2 - 1
                spacing: Theme.sp3

                // ---- art block ----
                Rectangle {
                    id: artBlock

                    width: 128
                    height: 128
                    color: Theme.acid

                    Image {
                        id: artImg

                        anchors.fill: parent
                        visible: root.player && root.player.trackArtUrl.length > 0 && status === Image.Ready
                        source: root.player && root.player.trackArtUrl.length > 0 ? root.player.trackArtUrl : ""
                        sourceSize.width: 256
                        sourceSize.height: 256
                        fillMode: Image.PreserveAspectCrop
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !artImg.visible
                        text: "♪"
                        color: Theme.bg
                        font.family: Theme.fontFamily
                        font.pixelSize: 42
                        font.weight: Font.ExtraBold
                    }
                }

                Column {
                    width: parent.width - artBlock.width - Theme.sp3 - 1
                    height: 128
                    spacing: Theme.sp1

                    Item {
                        height: 8
                        width: 1
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: (root.player?.trackTitle || root.player?.identity || "NOTHING PLAYING").toUpperCase()
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsTitle
                        font.weight: Font.ExtraBold
                        font.letterSpacing: 1
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: [root.player?.trackArtist ?? "", root.player?.trackAlbum ?? ""].filter(s => s.length > 0).join(" — ")
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        font.letterSpacing: 0.5
                    }

                    Item {
                        height: 6
                        width: 1
                    }

                    YSlider {
                        id: seekSlider

                        width: parent.width
                        visible: root.lenSec > 0 && root.player && root.player.canSeek
                        value: root.lenSec > 0 ? Math.max(0, Math.min(1, root.posSec / root.lenSec)) : 0
                        onMoved: v => {
                            if (!root.player || !root.player.canSeek)
                                return;
                            root.posSec = v * root.lenSec;
                            try {
                                root.player.position = v * root.lenSec * 1000000;
                            } catch (e) {
                                root.player.seek((v * root.lenSec - root.player.position / 1000000) * 1000000);
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: childrenRect.height
                        visible: seekSlider.visible

                        Text {
                            anchors.left: parent.left
                            text: root.fmt(root.posSec)
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                        }

                        Text {
                            anchors.right: parent.right
                            text: root.fmt(root.lenSec)
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                        }
                    }

                    Item {
                        height: 6
                        width: 1
                    }

                    Row {
                        spacing: Theme.sp2

                        YButton {
                            width: 44
                            label: "⏮"
                            enabled: root.player && root.player.canGoPrevious
                            onClicked: {
                                root.posSec = 0;
                                if (root.player.canGoPrevious)
                                    root.player.previous();
                            }
                        }

                        YButton {
                            width: 56
                            tone: "acid"
                            label: root.playing ? "❚❚" : "▶"
                            onClicked: {
                                if (root.player && root.player.canTogglePlaying)
                                    root.player.togglePlaying();
                            }
                        }

                        YButton {
                            width: 44
                            label: "⏭"
                            onClicked: {
                                root.posSec = 0;
                                if (root.player && root.player.canGoNext)
                                    root.player.next();
                            }
                        }
                    }
                }
            }

            // identity chip bottom-left
            YChip {
                x: Theme.sp4
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.sp3
                label: (root.player?.identity ?? "").toUpperCase()
            }

            YButton {
                anchors.right: parent.right
                anchors.rightMargin: Theme.sp4 - 6
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                width: 30
                label: "×"
                onClicked: ShellState.closeMedia()
            }
        }
    }
}
