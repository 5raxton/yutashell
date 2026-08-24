import Quickshell
import Quickshell.Wayland
import qs.modules.common
import QtQuick
import qs.theme
import "."

// ShotFlash — the shutter tick (PH.11). A brief 1px acid border pulse on the
// overlay layer whenever a screenshot lands. Fully click-through (empty mask)
// and invisible between shots.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay

    // shutter border — pulses in, snaps out. instant, no glow.
    Rectangle {
        id: border

        anchors.fill: parent
        anchors.margins: 2
        color: "transparent"
        border.width: 2
        border.color: Theme.acid
        opacity: 0
    }

    SequentialAnimation {
        id: flashAnim

        running: false

        NumberAnimation {
            target: border
            property: "opacity"
            from: 0.0
            to: 0.85
            duration: 1
        }
        NumberAnimation {
            target: border
            property: "opacity"
            from: 0.85
            to: 0
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    Connections {
        target: Screenshot

        function onFlashed() {
            flashAnim.restart();
        }
    }
}
