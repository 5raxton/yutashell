import QtQuick
import QtQuick.Shapes
import qs.theme

// YSurface — the standard popup card. ONE implementation of the house
// entrance: the surface drops down from behind the bar (bar renders on the
// Overlay layer, surfaces land on Top), slides to its resting spot below it,
// and lifts back up on close.
//
// The card rests FLUSH against the bar bottom, and concave "flare" shoulders
// sweep outward from the top corners into the bar line — a socket, not a
// floating tile. Every popup uses this so they all read as the same object.
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
    // extra gap between bar and card at rest (0 = flush socket)
    property int restGap: 0
    // draw the concave outward shoulders that blend the card into the bar
    property bool flareTop: true

    readonly property int flareS: 22

    readonly property real restY: Theme.barHeight + restGap
    readonly property real hiddenY: -height - 12 - (flareTop ? flareS : 0)

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

    // ---- flare shoulders -------------------------------------------------
    // Concave fillets filling the square just OUTSIDE each top corner:
    // square minus the quarter-disc hugging the corner, so the silhouette
    // flares from card-width out to the full bar line.
    //
    // Left path (local coords, item spans [-S..0] × [0..S]):
    //   (0,0) → (S,0) → (S,S) → minor arc back to (0,0), center at (S,S)
    // Right path mirrors it.
    Shape {
        id: flareL

        visible: root.flareTop && root.open
        x: -root.flareS
        y: 0
        width: root.flareS
        height: root.flareS

        ShapePath {
            strokeWidth: -1
            fillColor: root.color

            startX: 0
            startY: 0
            PathLine {
                x: root.flareS
                y: 0
            }
            PathLine {
                x: root.flareS
                y: root.flareS
            }
            PathArc {
                x: 0
                y: 0
                radiusX: root.flareS
                radiusY: root.flareS
                direction: PathArc.Clockwise
            }
        }
    }

    Shape {
        id: flareR

        visible: root.flareTop && root.open
        x: root.width
        y: 0
        width: root.flareS
        height: root.flareS

        ShapePath {
            strokeWidth: -1
            fillColor: root.color

            startX: root.flareS
            startY: 0
            PathLine {
                x: 0
                y: 0
            }
            PathLine {
                x: 0
                y: root.flareS
            }
            PathArc {
                x: root.flareS
                y: 0
                radiusX: root.flareS
                radiusY: root.flareS
                direction: PathArc.Counterclockwise
            }
        }
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
