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
// Entrance ritual (kept quiet, but always there): the card lands with a
// soft overshoot into its socket, an acid scanline sweeps down the face
// once, the border burns acid before settling to hairline, and the family
// tick draws itself down the left edge. One compound gesture, ~400ms.
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

    // intro state — driven once per open
    property bool _landed: false

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
            // entering: dip a touch past the socket so the bar lip visually
            // swallows the card edge, then click back flush
            easing.type: root.open ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 0.12
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
    // burn acid on arrival, cool to hairline once landed
    border.color: root._landed ? Theme.lineStrong : Theme.acid

    Behavior on border.color {
        ColorAnimation {
            duration: Theme.movMed
        }
    }

    Timer {
        id: landTimer

        interval: 230
        onTriggered: root._landed = true
    }

    // ---- entrance ritual --------------------------------------------------
    Rectangle {
        id: scanline

        anchors.left: parent.left
        anchors.right: parent.right
        y: -2
        height: 2
        color: Theme.acid
        opacity: 0
    }

    Rectangle {
        id: familyTick

        anchors.left: parent.left
        anchors.top: parent.top
        width: 2
        height: 0
        color: Theme.acid

        Behavior on height {
            enabled: root.open

            NumberAnimation {
                duration: Theme.movMed
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: intro

        running: false

        ParallelAnimation {
            NumberAnimation {
                target: scanline
                property: "y"
                from: -2
                to: root.height + 2
                duration: 380
                easing.type: Easing.OutCubic
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 280
                }
                NumberAnimation {
                    target: scanline
                    property: "opacity"
                    from: 0.85
                    to: 0
                    duration: 110
                    easing.type: Easing.OutCubic
                }
            }
            SequentialAnimation {
                PauseAnimation {
                    duration: 110
                }
                NumberAnimation {
                    target: familyTick
                    property: "height"
                    from: 0
                    to: 26
                    duration: Theme.movMed
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    onOpenChanged: {
        if (open) {
            root._landed = false;
            familyTick.height = 0;
            scanline.y = -2;
            scanline.opacity = 0.85;
            landTimer.restart();
            intro.restart();
        } else {
            intro.stop();
            landTimer.stop();
            root._landed = false;
            scanline.opacity = 0;
            familyTick.height = 0;
        }
    }

    // swallow clicks inside so they never reach windows under the card area
    MouseArea {
        anchors.fill: parent

        onClicked: mouse => mouse.accepted = true
    }

    // ---- flare shoulders -------------------------------------------------
    // Concave fillets filling the square just OUTSIDE each top corner:
    // square minus the quarter-disc hugging the outer-top corner, so the
    // silhouette flares from card-width out to the full bar line.
    //
    // ONE geometry, defined once, mirrored for the far side — the two
    // shoulders cannot disagree. Path spans local [0..S]x[0..S]:
    //   M(S,0) -> L(0,0)  along the bar line
    //   arc centered (S,0), radius S, down to (S,S)  — the concave bite
    //   close along the outer edge
    component FlareShape: Shape {
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
            // Counterclockwise selects the arc bowed toward the outer corner
            // (concave socket); Clockwise would fill the complement and read
            // as a convex fang beside the card.
            PathArc {
                x: root.flareS
                y: root.flareS
                radiusX: root.flareS
                radiusY: root.flareS
                direction: PathArc.Counterclockwise
            }
        }
    }

    FlareShape {
        id: flareR

        visible: root.flareTop && root.open
        x: root.width
        y: 0
    }

    FlareShape {
        id: flareL

        visible: root.flareTop && root.open
        x: -root.flareS
        y: 0
        transform: Scale {
            xScale: -1
            origin.x: root.flareS / 2
            origin.y: root.flareS / 2
        }
    }
}
