import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQml.Models
import qs.theme
import qs.modules.common
import "ui"

// Toast stack — passive popup, no exclusivity. Cards drop from behind the
// bar in the configured corner (tr|tl); input is masked to the cards only,
// the rest of the window passes clicks straight through.
//
// The ObjectModel holds the CARD ITEMS themselves (never an inline delegate:
// a Repeater fed by an ObjectModel receives the stored objects directly, so
// plain Entry QtObjects here crashed the compositor session with recursive
// instantiation). Cards are created per toast and destroyed on remove —
// entries stay stable across ticks, so hover-pause and entrance animations
// survive every countdown tick.
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

    // mask hugs the actual card column — empty space beside/below the stack
    // passes clicks through to apps underneath
    mask: Region {
        item: toastModel.count > 0 ? contentCol : null
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
                model: toastModel
            }
        }
    }

    ObjectModel {
        id: toastModel
    }

    Component {
        id: cardComp

        ToastCard {}
    }

    // Entry refs — index-aligned with toastModel (cards at the same slots)
    property var _items: []

function _syncAdd(vm) {
        const stagger = Math.min(root._items.length, 6) * 70;
        // Create without parent — ObjectModel will adopt and place in scene
        const card = cardComp.createObject(root, {
                "entry": vm,
                "staggerMs": stagger
            });
        if (!card)
            return;
        root._items.unshift(vm);
        toastModel.insert(0, card);
    }

    function _syncRemove(vm) {
        const i = root._items.indexOf(vm);
        if (i < 0)
            return;
        root._items.splice(i, 1);
        // removing from the ObjectModel also destroys the card item
        toastModel.remove(i);
    }

    Component.onCompleted: {
        // hot-reload safety net: adopt whatever is already live (oldest first,
        // since _syncAdd prepends)
        for (let i = Notify.live.length - 1; i >= 0; i--)
            root._syncAdd(Notify.live[i]);
    }

    Connections {
        target: Notify

        function onToastAdded(vm) {
            root._syncAdd(vm);
        }

        function onToastRemoved(vm) {
            root._syncRemove(vm);
        }
    }
}
