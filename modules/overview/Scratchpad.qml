import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui
import "."

// Scratchpad — compact YSurface listing windows stashed in special:magic.
// Click to restore (window.move to previous workspace), right-click to close.
// Open via IPC `overview scratchpad` or bar segment `scratchpad`.
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
    visible: ShellState.scratchpadOpen || hideDelay.running
    mask: Region {
        item: ShellState.scratchpadOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.scratchpadOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(480, root.width - Theme.outerPad * 4)

    // scratchpad windows from Hyprland toplevel model
    readonly property var scratchWindows: {
        const out = [];
        const vals = Hyprland.toplevels.values;
        for (let i = 0; i < vals.length; i++) {
            const tl = vals[i];
            const wsId = tl.workspace ? tl.workspace.id : 0;
            const wsName = tl.workspace ? String(tl.workspace.name) : "";
            if (wsId < 0 || wsName === "magic") {
                const appId = tl.wayland?.appId || tl.lastIpcObject?.class || "";
                const e = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
                out.push({
                    address: String(tl.address),
                    title: tl.title || appId || "window",
                    appId: appId,
                    iconSrc: e ? (e.icon || "") : "",
                    appName: e ? e.name : (appId || "window")
                });
            }
        }
        return out;
    }

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    Connections {
        target: ShellState

        function onScratchpadOpenChanged() {
            if (!ShellState.scratchpadOpen)
                hideDelay.restart();
        }
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeScratchpad()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeScratchpad()
        }

        YSurface {
            spawnId: "scratchpad"
            id: surface

            open: ShellState.scratchpadOpen
            cascade: bodyCol
            anchorX: "right"
            cardW: root.cardW
            cardH: Math.max(200, bodyCol.implicitHeight + Theme.sp4 * 2)

            Column {
                id: bodyCol

                x: Theme.sp4
                y: Theme.sp4
                width: parent.width - Theme.sp4 * 2
                spacing: Theme.sp3

                // header
                Item {
                    width: parent.width
                    height: 28

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "SCRATCHPAD"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        font.letterSpacing: 3
                    }

                    YChip {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        label: root.scratchWindows.length + " STASHED"
                        tone: "outline"
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.hairline
                }

                // window list
                Repeater {
                    model: root.scratchWindows

                    delegate: Rectangle {
                        id: row

                        required property var modelData
                        required property int index

                        width: bodyCol.width
                        height: 44
                        color: rowHover.containsMouse ? Theme.surface : "transparent"

                        Behavior on color {
                            ColorAnimation { duration: Theme.movFast }
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: Theme.hairline
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.sp2
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.sp2

                            // app icon or initial fallback
                            Rectangle {
                                width: 20
                                height: 20
                                color: "transparent"
                                anchors.verticalCenter: parent.verticalCenter

                                IconImage {
                                    anchors.fill: parent
                                    implicitSize: 20
                                    visible: modelData.iconSrc.length > 0 && status !== Image.Error
                                    source: modelData.iconSrc.length > 0 ? Quickshell.iconPath(modelData.iconSrc) : ""
                                    asynchronous: true
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.iconSrc.length === 0 || (parent.parent.children[0] && parent.parent.children[0].status === Image.Error)
                                    text: modelData.appName.charAt(0).toUpperCase()
                                    color: Theme.acid
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.DemiBold
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Text {
                                    text: modelData.appName
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                    width: bodyCol.width - Theme.sp2 * 2 - 70
                                }

                                Text {
                                    text: modelData.title
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                    elide: Text.ElideRight
                                    width: bodyCol.width - Theme.sp2 * 2 - 70
                                }
                            }
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.rightMargin: Theme.sp1
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.sp1
                            visible: rowHover.containsMouse

                            YButton {
                                label: "RESTORE"
                                onClicked: {
                                    Overview.focusAddress(modelData.address);
                                    Hyprland.dispatch('hl.dsp.window.move({ workspace = "previous" })');
                                    ShellState.closeScratchpad();
                                }
                            }

                            YButton {
                                label: "×"
                                tone: "danger"
                                onClicked: {
                                    Overview.closeAddress(modelData.address);
                                }
                            }
                        }

                        // empty state
                        Text {
                            anchors.centerIn: parent
                            visible: root.scratchWindows.length === 0
                            text: "NO STASHED WINDOWS"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                            font.letterSpacing: 2
                        }

                        MouseArea {
                            id: rowHover
                            anchors.fill: parent
                            anchors.rightMargin: row.children.length > 1 && row.children[row.children.length - 1].visible ? 100 : 0
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }
            }
        }
    }
}
