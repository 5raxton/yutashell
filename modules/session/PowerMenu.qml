import Quickshell
import Quickshell.Wayland
import Quickshell.Services.UPower
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui

// PowerMenu — session tiles behind a hold-to-confirm gate. Destructive tiles
// demand a press-and-hold (duration from prefs, 0 disables); the acid fill
// creeping across the tile face IS the countdown — release early and it
// snaps back empty.
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
    visible: ShellState.sessionOpen || hideDelay.running
    mask: Region {
        item: ShellState.sessionOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.sessionOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: 600
    readonly property int tileW: 176
    readonly property int tileH: 118

    Timer {
        id: hideDelay

        interval: 190
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Session.closeMenu()

        YClickAway {
            id: clickAway

            onOutsideClicked: Session.closeMenu()
        }

        YSurface {
            id: surface

            open: ShellState.sessionOpen
            cascade: bodyCol
            anchorX: "center"
            cardW: root.cardW
            cardH: bodyCol.implicitHeight + Theme.sp4 * 2

            Column {
                id: bodyCol

                x: Theme.sp4
                y: Theme.sp4
                width: parent.width - Theme.sp4 * 2
                spacing: Theme.sp2

                // ---- header ----
                Item {
                    width: parent.width
                    height: 28

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SESSION //"
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

                // ---- tiles ----
                Item {
                    id: gridWrap

                    width: parent.width
                    height: Math.ceil(tiles.count / 3) * (root.tileH + Theme.sp2) - Theme.sp2

                    Grid {
                        id: tiles

                        anchors.fill: parent
                        columns: 3
                        columnSpacing: Theme.sp2
                        rowSpacing: Theme.sp2

                        Repeater {
                            model: Session.tiles

                            PowerTile {}
                        }
                    }
                }

                // ---- footer: profile chip · battery · esc hint ----
                Item {
                    width: parent.width
                    height: 28

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.sp2

                        // power profile chip — click cycles saver/balanced/performance
                        Item {
                            visible: Session.ppdAvailable
                            width: ppdChip.implicitWidth
                            height: ppdChip.implicitHeight
                            anchors.verticalCenter: parent.verticalCenter

                            YChip {
                                id: ppdChip

                                anchors.fill: parent
                                label: Session.profileName.toUpperCase()
                                tone: "acid"
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Session.cycleProfile()
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: UPower.displayDevice && UPower.displayDevice.isPresent
                            text: "BAT " + Math.round(UPower.displayDevice ? UPower.displayDevice.percentage : 0) + "%"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                            font.letterSpacing: 1
                        }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: ShellState.holdMs > 0
                        text: "HOLD DESTRUCTIVE TILES"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        font.letterSpacing: 2
                    }
                }
            }
        }
    }

    // ---- one tile ---------------------------------------------------------
    component PowerTile: Rectangle {
        id: tile

        required property var modelData

        readonly property bool destructive: Session.destructiveTiles.has(modelData)
        readonly property bool needsHold: destructive && ShellState.holdMs > 0
        readonly property var meta: {
            const m = {
                "lock": ["󰌾", "LOCK"],
                "logout": ["󰗽", "LOGOUT"],
                "suspend": ["󰤄", "SUSPEND"],
                "hibernate": ["󰋊", "HIBERNATE"],
                "reboot": ["󰜉", "REBOOT"],
                "poweroff": ["󰐥", "POWEROFF"]
            };
            return m[modelData] ?? ["?", modelData.toUpperCase()];
        }

        width: root.tileW
        height: root.tileH
        color: area.containsMouse ? Theme.bgAlt : Theme.surface
        border.width: 1
        border.color: area.pressed ? Theme.acid : area.containsMouse ? Theme.lineStrong : Theme.hairline

        Behavior on border.color {
            ColorAnimation {
                duration: Theme.movFast
            }
        }

        // hover tick grows down the left edge (family language)
        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            width: 2
            height: area.containsMouse ? 18 : 0
            color: Theme.acid

            Behavior on height {
                NumberAnimation {
                    duration: Theme.movFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: Theme.sp2

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.meta[0]
                color: holdFill.width > 4 ? Theme.bg : tile.destructive ? Theme.ink : Theme.acid
                font.family: Theme.fontFamily
                font.pixelSize: 30
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tile.meta[1]
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLabel
                font.letterSpacing: 2
            }
        }

        // hold-to-confirm fill: acid floods the tile face across holdMs
        Rectangle {
            id: holdFill

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 0
            height: parent.height
            opacity: 0.85
            color: Theme.acid
        }

        SequentialAnimation {
            id: holdAnim

            NumberAnimation {
                target: holdFill
                property: "width"
                from: 0
                to: tile.width
                duration: Math.max(1, ShellState.holdMs)
                easing.type: Easing.Linear
            }
            ScriptAction {
                script: Session.fire(tile.modelData)
            }
        }

        function release() {
            holdAnim.stop();
            holdFill.width = 0;
        }

        MouseArea {
            id: area

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onPressed: {
                if (!tile.needsHold) {
                    Session.fire(tile.modelData);
                    return;
                }
                holdAnim.restart();
            }

            onReleased: tile.release()
            onCanceled: tile.release()
        }
    }
}
