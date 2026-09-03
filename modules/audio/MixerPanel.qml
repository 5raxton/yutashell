import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."

// MixerPanel (PH.02.2) — per-app audio mixer. Stream cards with app icon,
// name, volume slider, and mute toggle. Output device selector at top;
// input devices below a divider. Spawns from bar "mixer" action or IPC.
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
    visible: ShellState.mixerOpen || hideDelay.running
    mask: Region {
        item: ShellState.mixerOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.mixerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(520, contentRoot.width - Theme.outerPad * 2)
    readonly property int cardH: Math.min(560, contentRoot.height - Theme.barHeight - Theme.outerPad * 2)
    readonly property int padX: Theme.sp4

    readonly property var streams: MixerService.outputStreams
    readonly property var sinks: MixerService.sinks
    readonly property var currentSink: MixerService.currentSink

    Timer {
        id: hideDelay
        interval: Theme.lingerMs
    }

    Connections {
        target: ShellState
        function onMixerOpenChanged() {
            if (!ShellState.mixerOpen)
                hideDelay.restart();
        }
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: ShellState.mixerOpen

        Keys.onEscapePressed: ShellState.closeMixer()

        YClickAway {
            id: clickAway
            onOutsideClicked: ShellState.closeMixer()
        }

        YSurface {
            spawnId: "mixer"
            id: surface

            open: ShellState.mixerOpen
            cascade: bodyCol
            anchorX: "right"
            cardW: root.cardW
            cardH: root.cardH

            // ---- header ----
            Item {
                x: root.padX
                y: 0
                width: surface.width - root.padX * 2 - 1
                height: Theme.headH

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "MIXER"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Text {
                    visible: Theme.jpEnabled
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 64
                    text: "混音"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                }

                YChip {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    label: root.streams.length + " STREAM" + (root.streams.length !== 1 ? "S" : "")
                    tone: root.streams.length > 0 ? "acid" : "outline"
                }
            }

            Rectangle {
                x: root.padX
                y: Theme.headH
                width: surface.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            // ---- body ----
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

                FastWheel {}

                Column {
                    id: bodyCol

                    width: parent.width
                    spacing: Theme.sectionGap

                    // ===== OUTPUT DEVICE SELECTOR =====
                    Column {
                        width: parent.width
                        spacing: Theme.sp2

                        YSection {
                            index: "01"
                            label: "output"
                            chip: root.currentSink ? MixerService.volumePct(root.currentSink) + "%" : "—"
                        }

                        // master row
                        Column {
                            width: parent.width
                            spacing: Theme.sp1

                            Row {
                                width: parent.width

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - masterPct.width - Theme.sp3
                                    elide: Text.ElideRight
                                    text: root.currentSink ? AudioService.deviceLabel(root.currentSink).toUpperCase() : "NO DEVICE"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.DemiBold
                                }

                                Text {
                                    id: masterPct

                                    anchors.verticalCenter: parent.verticalCenter
                                    text: root.currentSink ? MixerService.volumePct(root.currentSink) + "%" : "—"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                }
                            }

                            YSlider {
                                width: parent.width
                                value: root.currentSink ? MixerService.volumeFrac(root.currentSink) : 0
                                onMoved: v => { if (root.currentSink) MixerService.setVolumeFrac(root.currentSink, v); }
                            }

                            Row {
                                spacing: Theme.sp1

                                YButton {
                                    label: AudioService.nodePct(root.currentSink) > 0 && !(root.currentSink && root.currentSink.audio && root.currentSink.audio.muted) ? "MUTE" : "UNMUTE"
                                    tone: root.currentSink && root.currentSink.audio && root.currentSink.audio.muted ? "danger" : "default"
                                    onClicked: MixerService.toggleMasterMute()
                                }

                                YButton {
                                    label: "-10"
                                    onClicked: MixerService.stepMaster(-10)
                                }

                                YButton {
                                    label: "+10"
                                    onClicked: MixerService.stepMaster(10)
                                }
                            }
                        }

                        // device list
                        Repeater {
                            model: root.sinks

                            delegate: Row {
                                id: sinkRow

                                required property var modelData

                                readonly property bool isDef: modelData === root.currentSink

                                width: parent.width
                                spacing: Theme.sp2

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - sinkSlider.width - Theme.sp2 * 2
                                    spacing: 4

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: sinkRow.isDef ? "★" : "☆"
                                        color: sinkRow.isDef ? Theme.acid : Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - Theme.sp2
                                        elide: Text.ElideMiddle
                                        text: AudioService.deviceLabel(sinkRow.modelData)
                                        color: sinkRow.isDef ? Theme.ink : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsLabel
                                    }

                                    MouseArea {
                                        width: parent.width
                                        height: parent.height
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: MixerService.switchOutput(sinkRow.modelData)
                                    }
                                }

                                YSlider {
                                    id: sinkSlider

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 120
                                    value: MixerService.volumeFrac(sinkRow.modelData)
                                    onMoved: v => { if (sinkRow.modelData) MixerService.setVolumeFrac(sinkRow.modelData, v); }
                                }
                            }
                        }
                    }

                    // ===== STREAMS =====
                    Column {
                        width: parent.width
                        spacing: Theme.sp2

                        YSection {
                            index: "02"
                            label: "streams"
                            chip: root.streams.length + " LIVE"
                        }

                        Repeater {
                            model: root.streams

                            delegate: Column {
                                id: streamCard

                                required property var modelData

                                readonly property bool smut: modelData.audio ? modelData.audio.muted : false
                                readonly property string sLabel: MixerService.label(modelData)
                                readonly property string sIcon: MixerService.iconUrl(modelData)

                                width: parent.width
                                spacing: 4

                                Row {
                                    width: parent.width

                                    // app icon (hidden placeholder keeps row height stable)
                                    Item {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 18
                                        height: 18

                                        IconImage {
                                            id: streamIconImg

                                            anchors.fill: parent
                                            implicitSize: 18
                                            source: streamCard.sIcon
                                            asynchronous: true
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - streamIconImg.width - streamMuteBtn.width - streamPctText.width - Theme.sp2 * 3
                                        elide: Text.ElideMiddle
                                        text: streamCard.sLabel
                                        color: streamCard.smut ? Theme.faint : Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsLabel
                                    }

                                    YButton {
                                        id: streamMuteBtn

                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 52
                                        label: streamCard.smut ? "UNMUTE" : "MUTE"
                                        tone: streamCard.smut ? "default" : "acid"
                                        onClicked: MixerService.toggleMute(streamCard.modelData)
                                    }

                                    Text {
                                        id: streamPctText

                                        anchors.verticalCenter: parent.verticalCenter
                                        text: MixerService.volumePct(streamCard.modelData) + "%"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsLabel
                                    }
                                }

                                YSlider {
                                    width: parent.width
                                    value: MixerService.volumeFrac(streamCard.modelData)
                                    onMoved: v => { if (streamCard.modelData) MixerService.setVolumeFrac(streamCard.modelData, v); }
                                }
                            }
                        }

                        Text {
                            visible: root.streams.length === 0
                            text: "no apps playing"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                        }
                    }

                    // ===== INPUT DEVICES =====
                    Column {
                        width: parent.width
                        spacing: Theme.sp2

                        YSection {
                            index: "03"
                            label: "input"
                            chip: MixerService.sources.length + " DEV"
                        }

                        Repeater {
                            model: MixerService.sources

                            delegate: Row {
                                id: srcRow

                                required property var modelData

                                readonly property bool isDef: modelData === MixerService.currentSource

                                width: parent.width
                                spacing: Theme.sp2

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - srcSlider.width - Theme.sp2 * 2
                                    spacing: 4

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: srcRow.isDef ? "★" : "☆"
                                        color: srcRow.isDef ? Theme.acid : Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - Theme.sp2
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
                                        onClicked: MixerService.switchInput(srcRow.modelData)
                                    }
                                }

                                YSlider {
                                    id: srcSlider

                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 120
                                    value: MixerService.volumeFrac(srcRow.modelData)
                                    onMoved: v => { if (srcRow.modelData) MixerService.setVolumeFrac(srcRow.modelData, v); }
                                }
                            }
                        }

                        Text {
                            visible: MixerService.sources.length === 0
                            text: "no input hardware"
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
                text: "PIPEWIRE · " + MixerService.status()
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
                onClicked: ShellState.closeMixer()
            }
        }
    }
}
