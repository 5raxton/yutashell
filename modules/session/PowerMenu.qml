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

    screen: FocusMonitor.screen

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

        interval: Theme.lingerMs
    }

    // linger mapped after close so YSurface's exit ceremony renders
    Connections {
        target: ShellState

        function onSessionOpenChanged() {
            if (!ShellState.sessionOpen)
                hideDelay.restart();
        }
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

            spawnId: "power"
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
                    height: Math.ceil(tiles.children.length / 3) * (root.tileH + Theme.sp2) - Theme.sp2

                    Grid {
                        id: tiles

                        anchors.fill: parent
                        columns: 3
                        columnSpacing: Theme.sp2
                        rowSpacing: Theme.sp2

                        Repeater {
                            model: Session.tiles

                            // index must be declared on the delegate to stay in
                            // scope; entranceDelay lives on the component so the
                            // stagger binding resolves without a JS closure.
                            PowerTile {
                                required property int index

                                entranceDelay: index * 30
                            }
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

        // staggered entrance — driven from inside the component so `tile` stays
        // in scope (it is not visible from the delegate usage body)
        required property int index
        property int entranceDelay: 0
        property bool entranceDone: false

        opacity: entranceDone ? 1 : 0
        scale: entranceDone ? 1 : 0.85

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.movSlow
                easing.type: Easing.OutCubic
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: Theme.movSlow
                easing.type: Easing.OutBack
                easing.overshoot: 0.2
            }
        }

        Timer {
            id: entranceTimer

            interval: tile.entranceDelay
            repeat: false
            onTriggered: tile.entranceDone = true
        }

        Component.onCompleted: entranceTimer.start()

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
        // destructive tiles read danger, not acid — the fill that kills your
        // session should never wear the "primary action" color
        border.color: area.pressed ? (tile.destructive ? Theme.alert : Theme.acid) : area.containsMouse ? Theme.lineStrong : tile.destructive ? Theme.lineStrong : Theme.hairline

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
            color: tile.destructive ? Theme.alert : Theme.acid

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
                font.pixelSize: Math.round(Theme.fsDisplay * 1.5)
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                // lightens as the fill passes under it or it vanishes on acid
                color: holdFill.width > 4 ? Theme.bg : Theme.muted
                text: tile.meta[1]
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
            color: tile.destructive ? Theme.alert : Theme.acid
        }

        // danger pulse when hold nears completion — semantic "point of no return"
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 2
            border.color: Theme.alert
            opacity: 0
            visible: tile.needsHold && holdFill.width > tile.width * 0.75

            SequentialAnimation on opacity {
                running: visible
                loops: Animation.Infinite

                NumberAnimation {
                    from: 0
                    to: 0.5
                    duration: 280
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 0.5
                    to: 0
                    duration: 280
                    easing.type: Easing.InOutSine
                }
            }
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
