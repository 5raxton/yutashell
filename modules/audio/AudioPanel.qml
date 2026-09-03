import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."

// Audio console — output/input device sliders with default-device stars,
// per-app streams with mute, overdrive past 100 % flagged in acid.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: ShellState.audioOpen || hideDelay.running
    mask: Region {
        item: ShellState.audioOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.audioOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(680, contentRoot.width - Theme.outerPad * 2)
    readonly property int cardH: Math.min(560, contentRoot.height - Theme.barHeight - Theme.outerPad * 2)
    readonly property int padX: Theme.sp4

    readonly property var sink: AudioService.sink
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property int pct: AudioService.nodePct(sink)

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    // linger mapped after close so YSurface's exit ceremony renders
    Connections {
        target: ShellState

        function onAudioOpenChanged() {
            if (!ShellState.audioOpen)
                hideDelay.restart();
        }
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeAudio()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeAudio()
        }

        YSurface {

            spawnId: "vol"
            id: surface

            open: ShellState.audioOpen
            cascade: bodyCol
            anchorX: "right"
            cardW: root.cardW
            cardH: Math.max(320, root.cardH)

            // ---- header ----
            Item {
                x: root.padX
                y: 0
                width: surface.width - root.padX * 2 - 1
                height: Theme.headH

                Rectangle {
                    id: mark

                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    color: "transparent"
                    border.width: 1
                    border.color: root.muted ? Theme.alert : Theme.acid

                    Text {
                        anchors.centerIn: parent
                        text: "♪"
                        color: root.muted ? Theme.alert : Theme.acid
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: mark.right
                    anchors.leftMargin: Theme.sp2
                    text: "AUDIO.CONSOLE"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                YChip {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    label: root.muted ? "MUTED" : (root.pct > 100 ? "+" : "") + root.pct + "%"
                    tone: root.muted ? "alert" : root.pct > 100 ? "acid" : "outline"
                }
            }

            Rectangle {
                x: root.padX
                y: Theme.headH
                width: surface.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            Flickable {
                id: scroll

                x: root.padX
                y: Theme.headH + Theme.sp3
                width: surface.width - root.padX * 2 - 1
                height: surface.height - y - Theme.footH - Theme.sp3
                contentWidth: width
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 4000
                maximumFlickVelocity: 4200
                contentHeight: bodyCol.height

                FastWheel {
                }

                Column {
                    id: bodyCol

                    width: parent.width
                    spacing: Theme.sectionGap

                    // ===== OUTPUT =====
                    Column {
                        width: parent.width
                        spacing: Theme.sp2

                        YSection {
                            index: "01"
                            label: "output"
                            chip: AudioService.sinks.length + " DEV"
                        }

                        // master row: default sink
                        Column {
                            width: parent.width
                            spacing: Theme.sp1

                            Row {
                                width: parent.width

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - pctText.width - Theme.sp3
                                    elide: Text.ElideRight
                                    text: root.sink ? AudioService.deviceLabel(root.sink).toUpperCase() : "NO OUTPUT DEVICE"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    id: pctText

                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.muted ? "MUTED" : (root.pct > 100 ? "+" : "") + root.pct + "%"
                                    color: root.muted ? Theme.alert : root.pct > 100 ? Theme.acid : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                }
                            }

                            YSlider {
                                width: parent.width
                                value: root.sink ? AudioService.nodeFrac(root.sink) : 0
                                onMoved: v => { if (root.sink) AudioService.setFrac(root.sink, v); }
                            }

                            Row {
                                spacing: Theme.sp1

                                YButton {
                                    label: root.muted ? "UNMUTE" : "MUTE"
                                    tone: root.muted ? "danger" : "default"
                                    onClicked: {
                                        AudioService.toggleMute(root.sink);
                                        AudioService.osdPing("volume");
                                    }
                                }

                                YButton {
                                    label: "-10"
                                    onClicked: {
                                        AudioService.stepPct(root.sink, -10);
                                        AudioService.osdPing("volume");
                                    }
                                }

                                YButton {
                                    label: "+10"
                                    onClicked: {
                                        AudioService.stepPct(root.sink, 10);
                                        AudioService.osdPing("volume");
                                    }
                                }
                            }
                        }

                        // device list — star sets the default
                        Repeater {
                            model: AudioService.sinks

                            delegate: Row {
                                id: sinkRow

                                required property var modelData

                                readonly property bool isDef: modelData === root.sink

                                width: parent.width
                                spacing: Theme.sp2

                                Row {
                                    id: sinkLabelHost

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - volSlider.width - Theme.sp2 * 2
                                    spacing: 4

                                    Text {
                                        id: sinkStar

                                        anchors.verticalCenter: parent.verticalCenter
                                        text: sinkRow.isDef ? "★" : "☆"
                                        color: sinkRow.isDef ? Theme.acid : Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - sinkStar.width - parent.spacing
                                        elide: Text.ElideMiddle
                                        text: AudioService.deviceLabel(sinkRow.modelData)
                                        color: sinkRow.isDef ? Theme.ink : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsLabel
                                    }

                                    MouseArea {
                                        id: starArea

                                        width: parent.width
                                        height: parent.height
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Pipewire.preferredDefaultAudioSink = sinkRow.modelData
                                    }
                                }

                                YSlider {
                                    id: volSlider

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 150
                                    value: AudioService.nodeFrac(sinkRow.modelData)
                                    onMoved: v => { if (sinkRow.modelData) AudioService.setFrac(sinkRow.modelData, v); }
                                }
                            }
                        }
                    }

                    // ===== INPUT =====
                    Column {
                        width: parent.width
                        spacing: Theme.sp2

                        YSection {
                            index: "02"
                            label: "input"
                            chip: AudioService.sources.length + " DEV"
                        }

                        Repeater {
                            model: AudioService.sources

                            delegate: Row {
                                id: srcRow

                                required property var modelData

                                readonly property bool isDef: modelData === AudioService.source

                                width: parent.width
                                spacing: Theme.sp2

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - srcSlider.width - Theme.sp2 * 2
                                    spacing: 4

                                    Text {
                                        id: srcStar

                                        anchors.verticalCenter: parent.verticalCenter
                                        text: srcRow.isDef ? "★" : "☆"
                                        color: srcRow.isDef ? Theme.acid : Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - srcStar.width - parent.spacing
                                        elide: Text.ElideMiddle
                                        text: AudioService.deviceLabel(srcRow.modelData)
                                        color: srcRow.isDef ? Theme.ink : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsLabel
                                    }

                                    MouseArea {
                                        width: parent.width
                                        height: parent.height
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Pipewire.preferredDefaultAudioSource = srcRow.modelData
                                    }
                                }

                                YSlider {
                                    id: srcSlider

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 150
                                    value: AudioService.nodeFrac(srcRow.modelData)
                                    onMoved: v => { if (srcRow.modelData) AudioService.setFrac(srcRow.modelData, v); }
                                }
                            }
                        }

                        Text {
                            visible: AudioService.sources.length === 0
                            text: "no input hardware"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                        }
                    }

                    // ===== STREAMS =====
                    Column {
                        width: parent.width
                        spacing: Theme.sp2

                        YSection {
                            index: "03"
                            label: "streams"
                            chip: AudioService.streams.length + " LIVE"
                        }

                        Repeater {
                            model: AudioService.streams

                            delegate: Column {
                                id: streamItem

                                required property var modelData

                                readonly property bool smut: modelData.audio ? modelData.audio.muted : false

                                width: parent.width
                                spacing: 4

                                Row {
                                    width: parent.width

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - streamPct.width - muteBtn.width - Theme.sp2 * 2
                                        elide: Text.ElideMiddle
                                        text: AudioService.streamLabel(streamItem.modelData)
                                        color: streamItem.smut ? Theme.faint : Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsLabel
                                    }

                                    YButton {
                                        id: muteBtn

                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 52
                                        label: streamItem.smut ? "UNMUTE" : "MUTE"
                                        tone: streamItem.smut ? "default" : "acid"
                                        onClicked: AudioService.toggleMute(streamItem.modelData)
                                    }

                                    Text {
                                        id: streamPct

                                        anchors.verticalCenter: parent.verticalCenter
                                        text: AudioService.nodePct(streamItem.modelData) + "%"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsLabel
                                    }
                                }

                                YSlider {
                                    width: parent.width
                                    value: AudioService.nodeFrac(streamItem.modelData)
                                    onMoved: v => AudioService.setFrac(streamItem.modelData, v)
                                }
                            }
                        }

                        Text {
                            visible: AudioService.streams.length === 0
                            text: "no apps playing"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                        }
                    }
                }
            }

            YScroll {
                anchors.top: scroll.top
                anchors.bottom: scroll.bottom
                anchors.right: scroll.right
                width: 3
                target: scroll
            }

            // ---- footer ----
            Rectangle {
                x: root.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.sp2
                width: surface.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            Text {
                x: root.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 8
                text: "PIPEWIRE · OVERDRIVE CEILING " + ShellState.audioCeiling + "%"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.letterSpacing: 1
            }

            YButton {
                anchors.right: parent.right
                anchors.rightMargin: root.padX - 6
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 4
                width: 30
                label: "×"
                onClicked: ShellState.closeAudio()
            }
        }
    }
}
