import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "ui"

// Toast stack — passive popup, no exclusivity. Cards drop from behind the
// bar in the configured corner (tr|tl); input is masked to the cards only,
// the rest of the window passes clicks straight through.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    readonly property bool right: ShellState.notifyCorner !== "tl"
    readonly property int pad: Theme.sp2 + 2

    anchors {
        top: true
        left: !root.right
        right: root.right
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer: WlrLayer.Top

    implicitWidth: 404
    implicitHeight: contentCol.height + Theme.barHeight + pad * 2

    mask: Region {
        item: Notify.live.length > 0 ? cardsHost : null
    }

    Item {
        id: cardsHost

        x: 0
        y: 0
        width: parent.width
        height: parent.height

        Column {
            id: contentCol

            x: root.pad
            y: Theme.barHeight + root.pad
            width: parent.width - root.pad * 2
            spacing: Theme.sp2

            Repeater {
                model: Notify.live

                ToastCard {}
            }
        }
    }
}
