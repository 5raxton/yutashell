import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
    }

    margins.top: Theme.barHeight + 8
    margins.left: {
        if (!anchorItem)
            return gapX;
        const p = anchorItem.mapToItem(null, 0, 0);
        const center = p.x + anchorItem.width / 2;
        const sw = screen ? screen.width : 1920;
        return Math.round(Math.max(8, Math.min(center - box.width / 2, sw - box.width - 8)));
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: false
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Overlay

    property Item anchorItem
    readonly property int gapX: 6

    implicitWidth: box.width
    implicitHeight: box.height

    function showFor(item, text) {
        if (!item || !text)
            return;
        anchorItem = item;
        label.text = String(text).toUpperCase();
        visible = true;
        hideTimer.restart();
    }

    function hide() {
        visible = false;
        anchorItem = null;
        hideTimer.stop();
    }

    Timer {
        id: hideTimer
        interval: 2400
        onTriggered: root.hide()
    }

    Rectangle {
        id: box

        width: label.width + 24
        height: 22
        color: Theme.bgAlt
        border.width: 1
        border.color: Theme.lineStrong

        Rectangle {
            x: 1
            y: 1
            width: 2
            height: parent.height - 2
            color: Theme.acid
        }

        Text {
            id: label
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 9
            font.letterSpacing: 0.5
        }
    }
}
