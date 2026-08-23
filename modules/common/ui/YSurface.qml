import QtQuick
import QtQuick.Shapes
import qs.theme

// YSurface — the standard popup card. ONE implementation of the house
// entrance AND exit: the surface drops down from behind the bar (bar renders
// on the Overlay layer, surfaces land on Top), slides to its resting spot
// below it, and lifts back up on close — with a reverse scanline as it goes.
//
// The card rests FLUSH against the bar bottom, concave "flare" shoulders
// sweep outward from the top corners into the bar line, and a 2px ACID
// POWER LINE grounds the bottom edge — every card in the shell carries the
// same live wire. Content can cascade in via `cascade` (staggered rise).
//
// Entrance ritual (kept quiet, but always there): the card lands with a
// soft overshoot into its socket, an acid scanline sweeps down the face,
// the border burns acid before settling to hairline, the power line draws
// left→right, and the family tick draws itself down the left edge. One
// compound gesture, ~400ms.
//
// Consumers set open/anchorX/cardW/cardH (+ optional cascade) and anchor
// content INSIDE; the parent window stays fullscreen-transparent and masks
// input to this item.
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
    // Item whose direct children stagger-rise when the surface opens
    // (pass your main content Column). Runs once per open, never at boot.
    property Item cascade: null

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

    // ---- entrance / exit ritual ------------------------------------------
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

    // the power line — every card is wired to the same current
    Rectangle {
        id: powerLine

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 0
        height: 2
        color: Theme.acid

        Behavior on width {
            NumberAnimation {
                duration: 340
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

    // exit ceremony: the scanline returns up as the card lifts away
    ParallelAnimation {
        id: outro

        running: false

        NumberAnimation {
            target: scanline
            property: "y"
            to: -2
            from: root.height + 2
            duration: 170
            easing.type: Easing.InCubic
        }
        SequentialAnimation {
            PauseAnimation {
                duration: 60
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
    }

    function reveal(item) {
        if (!item || !item.children)
            return;
        const kids = item.children;
        for (let i = 0; i < kids.length; i++) {
            const kid = kids[i];
            if (!kid || kid.visible === false)
                continue;
            const delay = i * 26;
            kid.opacity = 0;
            // layout-safe rise: Translate transform, removed after landing
            let tr = null;
            try {
                tr = Qt.createQmlObject("import QtQuick; Translate { y: 14 }", kid);
                kid.transform = [tr];
            } catch (e) {
                tr = null;
            }
            const anim = kidAnim.createObject(root, {
                    "target": kid,
                    "delay": delay,
                    "tr": tr
                });
            // sections draw their rules as their row lands
            if (kid.reveal)
                anim.started.connect(kid.reveal);
            anim.start();
        }
    }

    Component {
        id: kidAnim

        SequentialAnimation {
            id: kidSeq

            property Item target
            property int delay: 0
            property var tr: null

            PauseAnimation {
                duration: kidSeq.delay
            }
            ParallelAnimation {
                NumberAnimation {
                    target: kidSeq.target
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: Theme.movSlow
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: kidSeq.tr
                    property: "y"
                    from: 14
                    to: 0
                    duration: Theme.movSlow
                    easing.type: Easing.OutCubic
                }
            }
            onStopped: {
                if (kidSeq.tr && kidSeq.target) {
                    kidSeq.target.transform = [];
                    kidSeq.tr.destroy();
                }
                kidSeq.destroy();
            }
        }
    }

    Timer {
        id: revealDelay

        interval: 140
        onTriggered: if (root.cascade)
            root.reveal(root.cascade)
    }

    onOpenChanged: {
        if (open) {
            root._landed = false;
            familyTick.height = 0;
            powerLine.width = 0;
            scanline.y = -2;
            scanline.opacity = 0.85;
            landTimer.restart();
            intro.restart();
            powerLine.width = root.width;
            revealDelay.restart();
        } else {
            intro.stop();
            landTimer.stop();
            root._landed = false;
            outro.restart();
            familyTick.height = 0;
            powerLine.width = 0;
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

            // Right shoulder, local box [0..S]x[0..S]:
            //   (0,0) = card top corner, (S,0) = on the bar line,
            //   (0,S) = on the card edge, arc center at the far corner (S,S).
            // Fill = bar segment + concave quarter-arc + card-edge segment —
            // the classic inside-fillet (area S²−πS²/4, NOT the complement).
            startX: 0
            startY: 0
            PathLine {
                x: root.flareS
                y: 0
            }
            PathArc {
                x: 0
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
