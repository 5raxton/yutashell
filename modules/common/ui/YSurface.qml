import QtQuick
import qs.theme

// YSurface — the standard popup card. ONE implementation of the house
// entrance: the surface drops down from behind the bar (bar renders on the
// Overlay layer, surfaces land on Top), slides to its resting spot below it,
// and lifts back up on close. Every popup in the shell uses this so they all
// read as the same object.
//
// Consumers set open/anchorX/cardW/cardH and anchor content INSIDE; the
// parent window stays fullscreen-transparent and masks input to this item.
Rectangle {
    id: root

    property bool open: false
    // horizontal placement of the resting spot: center | left | right
    property string anchorX: "center"
    property int cardW: 720
    property int cardH: 560
    // gap between bar and card at rest
    property int restGap: Theme.outerPad + 6

    readonly property real restY: Theme.barHeight + restGap
    readonly property real hiddenY: -height - 12

    x: {
        if (anchorX === "left")
            return Theme.outerPad * 2;
        if (anchorX === "right")
            return parent.width - width - Theme.outerPad * 2;
        return Math.round((parent.width - width) / 2);
    }
    y: open ? restY : hiddenY
    opacity: open ? 1 : 0
    visible: opacity > 0.01

    Behavior on y {
        NumberAnimation {
            duration: root.open ? Theme.movSlow : Theme.movMed
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Theme.movFast
            easing.type: Easing.OutCubic
        }
    }

    width: cardW
    height: cardH
    color: Theme.bgAlt
    border.width: 1
    border.color: Theme.lineStrong

    // swallow clicks inside so they never reach windows under the card area
    MouseArea {
        anchors.fill: parent

        onClicked: mouse => mouse.accepted = true
    }

    // corner tick motif — the family mark
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        width: 2
        height: 26
        color: Theme.acid
    }
}
