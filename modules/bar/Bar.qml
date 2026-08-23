import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "ui"
import "../net"
import "../audio"
import "../common/ui"

PanelWindow {
    id: root

    property var tip

    // Overlay: topmost layer. Popups land on Top, so anything sliding down
    // (settings/picker/launcher) emerges from BEHIND this bar.
    WlrLayershell.layer: WlrLayer.Overlay

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: Theme.barHeight
    color: "transparent"

    Rectangle {
        id: frame
        anchors.fill: parent
        color: Theme.bg

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.hairline
        }

        YPulse {
            x: Theme.outerPad
            y: 0
            width: 132
            height: 2
            color: Theme.acid
            lo: 0.55
        }

        Row {
            id: leftRow
            anchors.left: parent.left
            anchors.leftMargin: Theme.outerPad
            anchors.verticalCenter: parent.verticalCenter

            IdentityBlock {}
            DividerV {}
            Workspaces {
                id: workspacesModule
            }
        }

        ActiveWindow {
            id: activeWindowModule
            anchors.left: leftRow.right
            anchors.leftMargin: 18
            anchors.right: rightRow.left
            anchors.rightMargin: 18
            anchors.top: parent.top
            anchors.bottom: parent.bottom
        }

        Row {
            id: rightRow

            // segment presence — dividers read these instead of long chains
            readonly property bool segTray: ShellState.barTray
            readonly property bool segMedia: ShellState.barMedia && mediaModule.player !== null
            readonly property bool segNet: ShellState.barNet
            readonly property bool segBt: ShellState.barBt && btModule.present
            readonly property bool segAudio: ShellState.barAudio
            readonly property bool segNl: ShellState.barAudio && NightLight.active
            readonly property bool segStats: ShellState.barStats
            readonly property bool segClock: ShellState.barClock

            anchors.right: parent.right
            anchors.rightMargin: Theme.outerPad
            anchors.verticalCenter: parent.verticalCenter

            TrayCluster {
                id: trayModule
                tip: root.tip
                visible: rightRow.segTray
            }

            DividerV {
                visible: rightRow.segTray && (rightRow.segMedia || rightRow.segNet || rightRow.segBt || rightRow.segAudio || rightRow.segNl)
            }

            MediaBlock {
                id: mediaModule
                tip: root.tip
                visible: rightRow.segMedia
            }

            DividerV {
                visible: rightRow.segMedia && (rightRow.segStats || rightRow.segNet || rightRow.segBt || rightRow.segAudio || rightRow.segNl)
            }

            NetBlock {
                id: netModule
                tip: root.tip
                visible: rightRow.segNet
            }

            DividerV {
                visible: rightRow.segNet && rightRow.segBt
            }

            BtBlock {
                id: btModule
                tip: root.tip
                visible: rightRow.segBt
            }

            DividerV {
                visible: (rightRow.segNet || rightRow.segBt) && (rightRow.segAudio || rightRow.segStats)
            }

            AudioBlock {
                id: audioModule
                tip: root.tip
                visible: rightRow.segAudio
            }

            // night light active chip — the filter is on, the machine says so
            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: rightRow.segNl
                text: "☾"
                color: Theme.acid
                font.family: Theme.fontFamily
                font.pixelSize: 12

                SequentialAnimation on opacity {
                    running: rightRow.segNl
                    loops: Animation.Infinite

                    NumberAnimation {
                        from: 1.0
                        to: 0.45
                        duration: 1600
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 0.45
                        to: 1.0
                        duration: 1600
                        easing.type: Easing.InOutSine
                    }
                }
            }

            DividerV {
                visible: rightRow.segNl && rightRow.segStats
            }

            StatsCluster {
                id: statsModule
                tip: root.tip
                visible: rightRow.segStats
            }

            DividerV {
                visible: (rightRow.segTray || rightRow.segMedia || rightRow.segStats || rightRow.segNet || rightRow.segBt || rightRow.segAudio || rightRow.segNl) && rightRow.segClock
            }

            ClockBlock {
                visible: ShellState.barClock
            }
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(evt) {
            if (evt.name !== "urgent")
                return;
            const addr = String(evt.data ?? "").replace(/^0x/, "");
            const tl = Hyprland.toplevels.values.find(t => String(t.address).replace(/^0x/, "") === addr);
            if (tl?.workspace && tl.workspace.id > 0)
                workspacesModule.markUrgent(tl.workspace.id);
        }

        function onFocusedWorkspaceChanged() {
            workspacesModule.clearUrgent(Hyprland.focusedWorkspace?.id ?? -1);
        }
    }
}
