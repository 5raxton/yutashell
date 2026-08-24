import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"

// Notification center — browsable history ring. Same house surface as the
// control core: YSurface card dropping from behind the bar, input masked to
// the card, ESC closes, exclusive with every other popup.
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
    visible: ShellState.notifyCenterOpen || hideDelay.running
    mask: Region {
        item: ShellState.notifyCenterOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.notifyCenterOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: 700
    readonly property int cardH: Math.min(540, contentRoot.height - Theme.barHeight - Theme.outerPad * 2)
    readonly property int padX: Theme.sp4

    Timer {
        id: hideDelay

        interval: 190
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeNotifyCenter()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeNotifyCenter()
        }

        YSurface {
            id: surface

            open: ShellState.notifyCenterOpen
            cascade: listCol
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
                    border.color: Theme.acid

                    Text {
                        anchors.centerIn: parent
                        text: "⏾"
                        color: Theme.acid
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: mark.right
                    anchors.leftMargin: Theme.sp2
                    text: "NOTIFICATION.CENTER"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 236
                    visible: Theme.jpEnabled
                    text: "通知"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 2
                }

                YChip {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    label: Notify.history.length + " KEPT"
                    tone: "outline"
                }
            }

            Rectangle {
                x: root.padX
                y: Theme.headH
                width: surface.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            // ---- DND row ----
            YRow {
                id: dndRow

                x: root.padX
                y: Theme.headH + 1
                width: surface.width - root.padX * 2 - 1
                title: "Do not disturb"
                sub: Notify.dnd ? Notify.suppressedCount + " suppressed since on" : "toasts land normally; critical always breaks through"
                note: "DND"
                on_: Notify.dnd
                onToggled: Notify.toggleDnd()

                YChip {
                    visible: Notify.dnd && Notify.suppressedCount > 0
                    label: String(Notify.suppressedCount)
                    tone: "acid"
                }
            }

            // ---- history list ----
            Flickable {
                id: listFlick

                x: root.padX
                y: dndRow.y + dndRow.height + Theme.sp2
                width: surface.width - root.padX * 2 - 1
                height: surface.height - (dndRow.y + dndRow.height) - Theme.footH - Theme.sp3
                clip: true
                contentWidth: width
                contentHeight: listCol.height

                FastWheel {}


                Column {
                    id: listCol

                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: Notify.history

                        delegate: Item {
                            id: rowRoot

                            required property int index
                            required property var modelData

                            width: listFlick.width
                            height: 44

                            readonly property bool hovered: harea.containsMouse

                            Rectangle {
                                anchors.fill: parent
                                color: rowRoot.hovered ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.04) : "transparent"
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Theme.hairline
                            }

                            Text {
                                id: timeText

                                visible: Notify.fields.time
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.sp1
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    const d = new Date(rowRoot.modelData.t);
                                    return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
                                }
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                            }

                            Rectangle {
                                anchors.left: timeText.visible ? timeText.right : parent.left
                                anchors.leftMargin: Theme.sp1
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 14
                                color: rowRoot.modelData.urg === 2 ? Theme.alert : rowRoot.modelData.sup ? Theme.muted : Theme.acid
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 64
                                anchors.right: actionsRow.visible ? actionsRow.left : parent.right
                                anchors.rightMargin: Theme.sp2
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Row {
                                    spacing: Theme.sp2

                                    Text {
                                        text: rowRoot.modelData.app.toUpperCase()
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        font.letterSpacing: 1
                                    }

                                    Text {
                                        visible: rowRoot.modelData.sup
                                        text: "⏾ QUIET"
                                        color: Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        font.letterSpacing: 1
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: (rowRoot.modelData.sum.length > 0 ? rowRoot.modelData.sum + " — " : "") + rowRoot.modelData.body.replace(/\n/g, " ").replace(/<[^>]*>/g, "")
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                id: actionsRow

                                anchors.right: parent.right
                                anchors.rightMargin: Theme.sp1
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.sp1
                                visible: rowRoot.hovered

                                YButton {
                                    label: "REPLAY"
                                    onClicked: Notify.replay(rowRoot.modelData)
                                }

                                YButton {
                                    label: "×"
                                    tone: "danger"
                                    onClicked: Notify.removeHistory(rowRoot.index)
                                }
                            }

                            MouseArea {
                                id: harea

                                anchors.fill: parent
                                anchors.rightMargin: actionsRow.visible ? actionsRow.width + Theme.sp1 : 0
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }

            YScroll {
                target: listFlick
                x: listFlick.x + listFlick.width - 4
                y: listFlick.y
                width: 3
                height: listFlick.height
            }

            // empty state
            Column {
                anchors.centerIn: parent
                visible: Notify.history.length === 0
                spacing: Theme.sp2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "NO HISTORY"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 3
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Theme.jpEnabled
                    text: "履歴なし"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 2
                }
            }

            // ---- footer ----
            Rectangle {
                x: 0
                y: surface.height - Theme.footH
                width: surface.width
                height: Theme.footH
                color: "transparent"

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.hairline
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: root.padX
                    anchors.verticalCenter: parent.verticalCenter
                    text: "RING 50 · PERSISTED 30"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 1
                }

                YButton {
                    anchors.right: parent.right
                    anchors.rightMargin: root.padX
                    anchors.verticalCenter: parent.verticalCenter
                    label: "CLEAR ALL"
                    tone: "danger"
                    onClicked: Notify.clearHistory()
                }
            }
        }
    }
}
