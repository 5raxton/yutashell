import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "ui"

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

        Rectangle {
            x: Theme.outerPad
            y: 0
            width: 132
            height: 2
            color: Theme.acid
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
            anchors.right: parent.right
            anchors.rightMargin: Theme.outerPad
            anchors.verticalCenter: parent.verticalCenter

            TrayCluster {
                id: trayModule
                tip: root.tip
                visible: ShellState.barTray
            }

            DividerV {
                visible: ShellState.barTray && mediaModule.visible
            }

            MediaBlock {
                id: mediaModule
                tip: root.tip
                visible: ShellState.barMedia && mediaModule.player !== null
            }

            DividerV {
                visible: mediaModule.visible && ShellState.barStats
            }

            StatsCluster {
                id: statsModule
                tip: root.tip
                visible: ShellState.barStats
            }

            DividerV {
                visible: (ShellState.barTray || mediaModule.visible || ShellState.barStats) && ShellState.barClock
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
