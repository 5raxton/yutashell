import QtQuick
import QtQuick.Shapes
import qs.theme
import qs.modules.common

// YSurface — the standard popup card. ONE implementation of the house
// entrance AND exit. Spawn origins are configurable per panel via PanelSpawn:
//   bar    — drops from behind the bar and rests flush in its socket (the
//            classic; mirrors automatically when the bar sits on the bottom)
//   top    — slides down from behind the TOP SCREEN EDGE and hangs flush
//            from it, curve shoulders sweeping along the edge
//   bottom — rises from behind the BOTTOM SCREEN EDGE and lands flush on
//            it, curve shoulders sweeping along the edge
//   float  — fades/scales in dead-center, detached from every edge
//
// The classic "bar" card rests FLUSH against the bar bottom, concave "flare"
// shoulders sweep outward from the top corners into the bar line, and a 2px
// ACID POWER LINE grounds the bottom edge — every card in the shell carries
// the same live wire. Content can cascade in via `cascade` (staggered rise).
//
// Entrance ritual (kept quiet, but always there): the card lands with a
// soft overshoot into its socket, an acid scanline sweeps down the face,
// the border burns acid before settling to hairline, the power line draws
// left→right, and the family tick draws itself down the left edge. One
// compound gesture, ~400ms.
//
// Consumers set open/spawnId/anchorX/cardW/cardH (+ optional cascade) and
// anchor content INSIDE; the parent window stays fullscreen-transparent and
// masks input to this item.
Rectangle {
    id: root

    property bool open: false
    // horizontal placement of the resting spot: center | left | right
    property string anchorX: "center"
    // which popup this is — resolves the persisted spawn origin via
    // PanelSpawn (bar|top|bottom|float); "" falls back to the default
    property string spawnId: ""
    property int cardW: 720
    property int cardH: 560
    // extra gap between bar and card at rest (0 = flush socket)
    property int restGap: 0
    // draw the concave outward shoulders that blend the card into whatever
    // edge it docks to (the bar line or the screen edge)
    property bool flares: true
    // Item whose direct children stagger-rise when the surface opens
    // (pass your main content Column). Runs once per open, never at boot.
    property Item cascade: null

    readonly property int flareS: 22

    // ---- resolved spawn origin -------------------------------------------
    readonly property string _mode: PanelSpawn.modeFor(spawnId)
    readonly property bool _floatMode: _mode === "float"
    readonly property bool _docked: !_floatMode
    readonly property bool _barAtBottom: ShellState.barPosition === "bottom"
    // the docking seam is the line the card hangs FROM (top-edge seams) or
    // rises ONTO (bottom-edge seams); flares always sweep along that line
    readonly property bool _seamTop: _mode === "top" || (_mode === "bar" && !_barAtBottom)
    readonly property bool _flaresOn: flares && _docked

    readonly property real restY: {
        if (_floatMode)
            return Math.round((parent.height - height) / 2);
        if (_mode === "top")
            return 0;
        if (_mode === "bottom")
            return parent.height - height;
        // docked to the bar (whichever edge it lives on)
        return _barAtBottom ? parent.height - Theme.barHeight - height - restGap : Theme.barHeight + restGap;
    }

    readonly property real hiddenY: {
        if (_floatMode)
            return restY;
        const pad = height + 12 + (_flaresOn && _seamTop ? flareS : 0);
        return _seamTop ? -pad : parent.height + 12;
    }

    // intro state — driven once per open
    property bool _landed: false

    x: {
        if (_floatMode)
            return Math.round((parent.width - width) / 2);
        if (anchorX === "left")
            return Theme.outerPad * 2;
        if (anchorX === "right")
            return parent.width - width - Theme.outerPad * 2;
        return Math.round((parent.width - width) / 2);
    }
    y: open ? restY : hiddenY
    opacity: open ? 1 : 0
    // float mode breathes in with a scale instead of a slide
    scale: _floatMode && !open ? 0.96 : 1
    transformOrigin: Item.Center
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

    Behavior on scale {
        NumberAnimation {
            duration: Theme.movMed
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
        NumberAnimation {
            target: familyTick
            property: "height"
            to: 0
            duration: 140
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: powerLine
            property: "width"
            to: 0
            duration: 180
            easing.type: Easing.InCubic
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
            // reduced motion: skip the scanline/tick/powerline ritual and the
            // landing delay — the card just appears (the y/opacity behaviors
            // already snap to instant via Theme.movSlow/movMed === 0)
            if (Theme.reducedMotion) {
                powerLine.width = root.width;
                root._landed = true;
                familyTick.height = 26;
                scanline.opacity = 0;
            } else {
                intro.restart();
                powerLine.width = root.width;
                revealDelay.restart();
            }
        } else {
            intro.stop();
            landTimer.stop();
            root._landed = false;
            if (Theme.reducedMotion)
                scanline.opacity = 0;
            else
                outro.restart();
        }
    }

    // swallow clicks inside so they never reach windows under the card area.
    // ALL buttons: right/middle must not fall through to the YClickAway
    // catcher beneath the card (it accepts every button and would close us).
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

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

    // top-seam shoulders — card hangs from the seam (bar on the top edge,
    // or a screen-top spawn); fillets sweep along the card's top corners
    FlareShape {
        id: flareR

        visible: root._flaresOn && root._seamTop && root.open
        opacity: root.open ? 1 : 0
        x: root.width
        y: 0

        Behavior on opacity {
            NumberAnimation { duration: Theme.movFast; easing.type: Easing.OutCubic }
        }
    }

    FlareShape {
        id: flareL

        visible: root._flaresOn && root._seamTop && root.open
        opacity: root.open ? 1 : 0
        x: -root.flareS
        y: 0
        transform: Scale {
            xScale: -1
            origin.x: root.flareS / 2
            origin.y: root.flareS / 2
        }

        Behavior on opacity {
            NumberAnimation { duration: Theme.movFast; easing.type: Easing.OutCubic }
        }
    }

    // bottom-seam shoulders — same fillets mirrored above the card's bottom
    // corners so it blends into a bar or screen edge that lives below it
    FlareShape {
        id: bflareR

        visible: root._flaresOn && !root._seamTop && root.open
        x: root.width
        y: root.height
        transform: Scale {
            yScale: -1
        }
    }

    FlareShape {
        id: bflareL

        visible: root._flaresOn && !root._seamTop && root.open
        x: -root.flareS
        y: root.height
        transform: [
            Scale {
                xScale: -1
                origin.x: root.flareS / 2
            },
            Scale {
                yScale: -1
            }
        ]
    }
}
