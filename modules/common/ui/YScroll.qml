import QtQuick
import qs.theme

// Hand-drawn scroll indicator. SIBLING overlay — position it over the target
// Flickable/GridView yourself; never declare it inside (content reparenting).
Item {
    id: root

    property var target: null

    readonly property bool scrollable: target && target.contentHeight > target.height + 8
    readonly property real thumbH: Math.max(26, height * height / Math.max(1, target?.contentHeight ?? 1))
    readonly property real frac: Math.max(0, Math.min(1, (target?.contentY ?? 0) / Math.max(1, (target?.contentHeight ?? 1) - (target?.height ?? 1))))

    visible: scrollable

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: 0
        width: 1
        height: parent.height
        color: Theme.hairline
    }

    Rectangle {
        y: root.frac * (root.height - height)
        width: 3
        height: root.thumbH
        color: Theme.lineStrong

        Behavior on y {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }
    }
}
