import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui
import "."

// OverviewGrid — fullscreen workspace map (PH.10). One tile per workspace:
// number, windows on it, click to jump. Live thumbnails of hidden workspaces
// aren't possible without compositor cooperation, so tiles render the window
// list in house style instead (icon + title).
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
    visible: ShellState.overviewOpen || hideDelay.running
    mask: Region {
        item: ShellState.overviewOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(1080, root.width - Theme.outerPad * 4)

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    // staggered reveal counter — increments each time the grid opens,
    // delegate tiles watch it and animate in with per-index delay
    property int _revealTick: 0

    Connections {
        target: ShellState

        function onOverviewOpenChanged() {
            if (ShellState.overviewOpen) {
                root._revealTick++;
            } else {
                hideDelay.restart();
            }
        }
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Overview.closeGrid()

        YClickAway {
            id: clickAway

            onOutsideClicked: Overview.closeGrid()
        }

        YSurface {

            spawnId: "overview"
            id: surface

            open: ShellState.overviewOpen
            cascade: bodyCol
            anchorX: "center"
            cardW: root.cardW
            cardH: bodyCol.implicitHeight + Theme.sp4 * 2
            restGap: Theme.sp2

            Column {
                id: bodyCol

                x: Theme.sp4
                y: Theme.sp4
                width: parent.width - Theme.sp4 * 2
                spacing: Theme.sp3

                Item {
                    width: parent.width
                    height: 28

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "OVERVIEW // " + Overview.workspaces.length + " WORKSPACES"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        font.letterSpacing: 3
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ESC"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        font.letterSpacing: 2
                    }
                }

                Flow {
                    id: grid

                    width: parent.width
                    spacing: Theme.sp2

                    Repeater {
                        model: Overview.workspaces

                        delegate: Rectangle {
                            id: ws

                            required property var modelData

                            readonly property bool focused: modelData.focused
                            readonly property var wins: modelData.windows || []
                            property bool entered: false

                            width: 250
                            // sized from real column content — the old arithmetic
                            // (40 + count*22) clipped rows and the "+N MORE" line
                            height: Math.max(96, wsCol.implicitHeight + Theme.sp3 * 2)
                            color: area.containsMouse ? Theme.surface : Theme.bgAlt
                            border.width: 1
                            border.color: focused ? Theme.acid : (area.containsMouse ? Theme.lineStrong : Theme.hairline)
                            opacity: entered ? 1 : 0
                            y: entered ? 0 : 16
                            scale: entered ? 1 : 0.85

                            Behavior on opacity {
                                enabled: entered
                                NumberAnimation {
                                    duration: Theme.movSlow
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on y {
                                enabled: entered
                                NumberAnimation {
                                    duration: Theme.movSlow
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on scale {
                                enabled: entered
                                NumberAnimation {
                                    duration: Theme.movSlow
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 0.2
                                }
                            }

                            // staggered entrance: each tile delays by index * 40ms
                            Connections {
                                target: root

                                function on_RevealTickChanged() {
                                    entranceDelay.restart();
                                }
                            }

                            Timer {
                                id: entranceDelay

                                interval: ws.index * 40
                                onTriggered: ws.entered = true
                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.movFast
                                }
                            }

                            Column {
                                id: wsCol

                                anchors.fill: parent
                                anchors.margins: Theme.sp3
                                spacing: Theme.sp2

                                Item {
                                    width: parent.width
                                    height: 20

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: String(modelData.id).padStart(2, "0")
                                        color: focused ? Theme.acid : Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsTitle
                                        font.weight: Font.DemiBold
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: wins.length + (wins.length === 1 ? " WINDOW" : " WINDOWS")
                                        color: Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        font.letterSpacing: 1
                                    }
                                }

                                Repeater {
                                    model: ws.wins.length > 5 ? ws.wins.slice(0, 5) : ws.wins

                                    Row {
                                        width: parent.width
                                        height: 18
                                        spacing: Theme.sp2

                                        // one 16px leading slot: glyph when no icon,
                                        // icon centered inside it — title math stays constant
                                        Item {
                                            width: 16
                                            height: 16
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                anchors.centerIn: parent
                                                visible: modelData.iconSrc === ""
                                                text: "■"
                                                color: Theme.acid
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsLabel
                                            }

                                            IconImage {
                                                anchors.centerIn: parent
                                                implicitSize: 14
                                                visible: modelData.iconSrc !== "" && status !== Image.Error && status !== Image.Null
                                                source: Quickshell.iconPath(modelData.iconSrc)
                                                asynchronous: true
                                            }
                                        }

                                        Text {
                                            width: parent.width - 16 - Theme.sp2
                                            text: modelData.title
                                            elide: Text.ElideRight
                                            color: Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsLabel
                                        }
                                    }
                                }

                                Text {
                                    visible: ws.wins.length > 5
                                    text: "+" + (ws.wins.length - 5) + " MORE"
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                    font.letterSpacing: 1
                                }
                            }

                            MouseArea {
                                id: area

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Overview.jumpWorkspace(modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
