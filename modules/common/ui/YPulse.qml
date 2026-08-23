import QtQuick
import qs.theme

// YPulse — a living Rectangle. The organism layer's base cell: use it in
// place of a plain Rectangle wherever an element should breathe while idle
// (acid strips, status dots, scan marks). Slow opacity drift between `lo`
// and 1 over Theme.movDrift — life runs slow. Never pulse text.
Rectangle {
    id: root

    property real lo: 0.62

    SequentialAnimation {
        running: root.visible

        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "opacity"
            from: 1.0
            to: root.lo
            duration: Theme.movDrift
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            target: root
            property: "opacity"
            from: root.lo
            to: 1.0
            duration: Theme.movDrift
            easing.type: Easing.InOutSine
        }
    }
}
