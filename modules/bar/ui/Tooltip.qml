import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme

PanelWindow {
    id: root

    // follow the anchor item's bar instance — the shared tooltip window must
    // not sit on one fixed screen (PH.06)
    screen: anchorItem && anchorItem.Window.window && anchorItem.Window.window.screen ? anchorItem.Window.window.screen : null

    anchors.left: true
    // top mode drops BELOW the bar; bottom mode rises ABOVE a bottom dock
    anchors.top: !root.bottomAnchored
    anchors.bottom: root.bottomAnchored

    margins.top: root.bottomAnchored ? 0 : Theme.barHeight + 8
    margins.bottom: root.bottomAnchored ? root.edgeGap : 0
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
    property bool bottomAnchored: false
    readonly property int gapX: 6
    readonly property int edgeGap: 64

    implicitWidth: box.width
    implicitHeight: box.height

    function showFor(item, text) {
        root._show(item, text, false);
    }

    function showForDock(item, text) {
        root._show(item, text, true);
    }

    function _show(item, text, fromBottom) {
        if (!item || !text)
            return;
        anchorItem = item;
        bottomAnchored = fromBottom;
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
        onTriggered: {
            // hovering the anchor holds the tip open; leave and it dismisses.
            // MouseAreas expose containsMouse; HoverHandler callers expose
            // hovered — accept either so the hold isn't dead for half the kit
            const a = root.anchorItem;
            if (a && (a.containsMouse === true || a.hovered === true)) {
                hideTimer.restart();
                return;
            }
            root.hide();
        }
    }

    Rectangle {
        id: box

        width: label.width + 24
        height: 22
        color: Theme.bgAlt
        border.width: 1
        border.color: Theme.lineStrong
        opacity: root.visible ? 1 : 0

        // rise out of the bar line as it appears
        transform: Translate {
            y: root.visible ? 0 : (root.bottomAnchored ? 6 : -6)

            Behavior on y {
                NumberAnimation {
                    duration: Theme.movFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.movSnap
            }
        }

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
            font.pixelSize: Theme.fsLabel
            font.letterSpacing: 0.5
        }
    }
}
