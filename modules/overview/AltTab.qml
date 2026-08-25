import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui
import "."

// AltTab — window switcher overlay (PH.10). Most-recent-first ordering from
// the MRU tracker in Overview.qml; a brutal acid frame rides the selection.
// Repeated ALT+Tab (the Helmsman bind) advances via Overview.cycleAltTab.
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
    visible: ShellState.altTabOpen || hideDelay.running
    mask: Region {
        item: ShellState.altTabOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.altTabOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(720, root.width - Theme.outerPad * 4)

    // rolling 8-card window around the selection
    readonly property int maxShow: 8
    readonly property int sliceStart: {
        const n = Overview.windows.length;
        if (n <= maxShow)
            return 0;
        let s = Overview.altTabIdx - Math.floor(maxShow / 2);
        if (s < 0)
            s = 0;
        if (s > n - maxShow)
            s = n - maxShow;
        return s;
    }
    readonly property var shown: Overview.windows.slice(sliceStart, sliceStart + Math.min(maxShow, Overview.windows.length))

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    // linger mapped after close so the overlay's exit renders
    Connections {
        target: ShellState

        function onAltTabOpenChanged() {
            if (!ShellState.altTabOpen)
                hideDelay.restart();
        }
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: Overview.cancelAltTab()
        Keys.onReturnPressed: Overview.commitAltTab()
        Keys.onEnterPressed: Overview.commitAltTab()
        Keys.onSpacePressed: Overview.commitAltTab()
        Keys.onTabPressed: event => {
            event.accepted = true;
            Overview.cycleAltTab(event.modifiers & Qt.ShiftModifier ? -1 : 1);
        }
        Keys.onLeftPressed: Overview.cycleAltTab(-1)
        Keys.onUpPressed: Overview.cycleAltTab(-1)
        Keys.onRightPressed: Overview.cycleAltTab(1)
        Keys.onDownPressed: Overview.cycleAltTab(1)

        YClickAway {
            id: clickAway

            onOutsideClicked: Overview.cancelAltTab()
        }

        YSurface {
            id: surface

            open: ShellState.altTabOpen
            cascade: bodyCol
            anchorX: "center"
            cardW: root.cardW
            cardH: 118
            restGap: Theme.sp3
            flares: false

            Column {
                id: bodyCol

                x: Theme.sp4
                y: Theme.sp4
                width: parent.width - Theme.sp4 * 2
                spacing: Theme.sp3

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: "SWITCH WINDOW"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 3
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Theme.sp2

                    Repeater {
                        // rolling slice: with >8 windows a hard slice(0,8) hid the
                        // selection AND mapped clicks to the wrong window
                        model: root.shown

                        delegate: Rectangle {
                            id: card

                            required property int index
                            required property var modelData

                            readonly property bool sel: root.sliceStart + index === Overview.altTabIdx
                            readonly property string iconUrl: modelData.iconSrc === "" ? "" : Quickshell.iconPath(modelData.iconSrc)

                            width: 74
                            height: 72
                            color: sel ? Theme.surface : Theme.bgAlt
                            border.width: sel ? 2 : 1
                            border.color: sel ? Theme.acid : Theme.hairline

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.sp2
                                spacing: Theme.sp1

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: 32
                                    height: 32
                                    color: Theme.acid
                                    visible: card.iconUrl === "" || icon.status !== Image.Ready

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.name.charAt(0).toUpperCase()
                                        color: Theme.bg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsTitle
                                        font.weight: Font.ExtraBold
                                    }
                                }

                                IconImage {
                                    id: icon

                                    anchors.horizontalCenter: parent.horizontalCenter
                                    implicitSize: 32
                                    source: card.iconUrl
                                    asynchronous: true
                                    visible: card.iconUrl !== "" && icon.status !== Image.Error && icon.status !== Image.Null
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: parent.width
                                    text: modelData.name
                                    elide: Text.ElideRight
                                    horizontalAlignment: Text.AlignHCenter
                                    color: card.sel ? Theme.acid : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                    font.letterSpacing: 1
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Overview.selectAltTab(root.sliceStart + card.index)
                            }
                        }
                    }
                }
            }
        }
    }
}
