import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."

// Clipboard manager (PH.11) — centered overlay listing cliphist history.
// Search-as-you-type, monospace previews, click/enter re-copies via wl-copy,
// DEL removes, right-click pins to top. Graceful empty state; hides when
// cliphist is absent.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    readonly property bool open: ShellState.clipboardOpen
    property bool everOpened: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.open || hideDelay.running
    mask: Region {
        item: root.open ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Timer {
        id: hideDelay

        interval: Theme.movMed
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: root.open

        Keys.onEscapePressed: ShellState.closeClipboard()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeClipboard()
        }

        YSurface {
            id: card

            open: root.open
            anchorX: "center"
            cardW: Math.min(Math.max(480, 560), Math.round(parent.width * 0.4))
            cardH: Math.min(520, Math.round(parent.height * 0.5))

            property int selIdx: 0

            function clampSel() {
                selIdx = Math.max(0, Math.min(selIdx, Math.max(0, filtered.length - 1)));
            }

            function moveSel(d) {
                const n = filtered.length;
                if (n === 0)
                    return;
                selIdx = ((selIdx + d) % n + n) % n;
            }

            readonly property string query: searchField.text.trim().toLowerCase()
            readonly property var filtered: {
                if (query.length === 0)
                    return Clipboard.sorted;
                return Clipboard.sorted.filter(e => e.binary || e.preview.toLowerCase().includes(query));
            }

            function resetForOpen() {
                searchField.text = "";
                selIdx = 0;
                Clipboard.refresh();
                searchField.forceFocus();
            }

            onFilteredChanged: clampSel()

            Component.onCompleted: if (root.open)
                resetForOpen()

            // ---- header ----
            Item {
                x: Theme.sp4
                y: 0
                width: card.width - Theme.sp4 * 2 - 1
                height: Theme.headH

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CLIPBOARD.HISTORY"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 176
                    visible: Theme.jpEnabled
                    text: "履歴"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                }

                YChip {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    label: Clipboard.available ? Clipboard.entries.length + " KEPT" : "NO CLIPHIST"
                    tone: Clipboard.available ? "outline" : "alert"
                }
            }

            Rectangle {
                x: Theme.sp4
                y: Theme.headH
                width: card.width - Theme.sp4 * 2 - 1
                height: 1
                color: Theme.hairline
            }

            // ---- search ----
            Item {
                x: Theme.sp4
                y: Theme.headH + 1
                width: card.width - Theme.sp4 * 2 - 1
                height: Theme.ctlH + Theme.sp3 * 2

                YField {
                    id: searchField

                    anchors.fill: parent
                    anchors.topMargin: Theme.sp2
                    anchors.bottomMargin: Theme.sp2
                    placeholder: Theme.jpEnabled ? "検索 // FILTER HISTORY" : "FILTER HISTORY…"
                    navKeys: true

                    onAccepted: {
                        const e = card.filtered[card.selIdx];
                        if (e)
                            Clipboard.copy(e);
                    }
                    onNavUp: card.moveSel(-1)
                    onNavDown: card.moveSel(1)
                    onNavEscape: ShellState.closeClipboard()
                    onNavShiftDel: {
                        const e = card.filtered[card.selIdx];
                        if (e)
                            Clipboard.remove(e.id);
                    }
                }
            }

            // ---- list ----
            Item {
                x: Theme.sp4
                y: Theme.headH + 1 + Theme.ctlH + Theme.sp3 * 2
                width: card.width - Theme.sp4 * 2 - 1
                height: card.height - y - Theme.footH - Theme.sp3

                Text {
                    anchors.centerIn: parent
                    visible: !Clipboard.available
                    text: "CLIPHIST NOT INSTALLED"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 2
                }

                Text {
                    anchors.centerIn: parent
                    visible: Clipboard.available && card.filtered.length === 0
                    text: card.query.length > 0 ? "NO MATCH" : "CLIPBOARD EMPTY"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 2
                }

                ListView {
                    id: listView

                    anchors.fill: parent
                    visible: Clipboard.available
                    clip: true
                    model: card.filtered
                    currentIndex: card.selIdx
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    spacing: 1
                    boundsBehavior: Flickable.StopAtBounds

                    FastWheel {
                    }

                    delegate: Item {
                        id: rowRoot

                        required property int index
                        required property var modelData

                        readonly property bool sel: index === card.selIdx

                        width: listView.width
                        height: 38

                        Rectangle {
                            anchors.fill: parent
                            color: rowRoot.sel ? Theme.surface : harea.containsMouse ? Theme.bg : "transparent"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 2
                                color: rowRoot.sel ? Theme.acid : "transparent"
                            }
                        }

                        // pin indicator
                        Rectangle {
                            x: Theme.sp3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 5
                            height: 5
                            color: Theme.acid
                            visible: Clipboard.isPinned(rowRoot.modelData.id)
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Clipboard.isPinned(rowRoot.modelData.id) ? 22 : Theme.sp3
                            anchors.right: rowRoot.modelData.binary ? imageTag.left : parent.right
                            anchors.rightMargin: Theme.sp2
                            anchors.verticalCenter: parent.verticalCenter
                            text: rowRoot.modelData.binary ? "· BINARY ·" : rowRoot.modelData.preview.replace(/\n/g, " ")
                            color: rowRoot.sel ? Theme.ink : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBody
                            elide: Text.ElideRight
                        }

                        YChip {
                            id: imageTag

                            visible: rowRoot.modelData.binary
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.sp2
                            anchors.verticalCenter: parent.verticalCenter
                            label: "IMG"
                            tone: "acid"
                        }

                        MouseArea {
                            id: harea

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: mouse => {
                                card.selIdx = rowRoot.index;
                                if (mouse.button === Qt.RightButton) {
                                    if (Clipboard.isPinned(rowRoot.modelData.id))
                                        Clipboard.unpin(rowRoot.modelData.id);
                                    else
                                        Clipboard.pin(rowRoot.modelData.id);
                                    return;
                                }
                                Clipboard.copy(rowRoot.modelData);
                            }
                        }
                    }
                }
            }

            // ---- footer ----
            Rectangle {
                x: 0
                y: card.height - Theme.footH
                width: card.width
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
                    anchors.leftMargin: Theme.sp4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↵ COPY · RCLICK PIN · ⇧DEL DELETE"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 1
                }

                YButton {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp4
                    anchors.verticalCenter: parent.verticalCenter
                    label: "WIPE"
                    tone: "danger"
                    visible: Clipboard.available && Clipboard.entries.length > 0
                    onClicked: Clipboard.clearAll()
                }
            }
        }
    }

    onVisibleChanged: {
        if (visible)
            card.resetForOpen();
    }
}
