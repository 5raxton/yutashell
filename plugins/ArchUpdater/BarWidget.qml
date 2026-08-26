import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui

// Arch Updater bar widget — icon + count badge. Click opens the update panel.
Item {
    id: root

    implicitWidth: updateRow.width
    implicitHeight: Theme.scaledBarHeight

    readonly property var daemon: {
        const d = PluginService.daemons["arch-updater"];
        return d || null;
    }

    readonly property int count: daemon ? daemon.updateCount : 0
    readonly property bool checking: daemon ? daemon.checking : false

    Row {
        id: updateRow

        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.checking ? "⟳" : "↻"
            color: root.count > 0 ? Theme.acid : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(14 * Theme.barScale)
            font.weight: Font.DemiBold

            RotationAnimation on rotation {
                running: root.checking
                from: 0
                to: 360
                duration: 800
                loops: Animation.Infinite
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: String(root.count)
            color: root.count > 0 ? Theme.acid : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.barFsLabel
            font.weight: Font.Bold

            Behavior on color {
                ColorAnimation { duration: Theme.movSnap }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            PluginService.togglePluginPanel("arch-updater");
            if (root.daemon && root.daemon.updateCount === 0 && !root.daemon.checking)
                root.daemon.refresh();
        }
    }
}
