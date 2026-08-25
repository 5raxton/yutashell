import QtQuick
import qs.theme

// Hand-drawn scroll indicator. SIBLING overlay — position it over the target
// Flickable/GridView yourself; never declare it inside (content reparenting).
// The rail sleeps: it wakes bright while you scroll, then settles — rail
// fades away, thumb dims to a whisper.
Item {
    id: root

    property var target: null
    property bool _awake: false

    readonly property bool scrollable: target && target.contentHeight > target.height + 8
    readonly property real thumbH: Math.max(26, height * height / Math.max(1, target?.contentHeight ?? 1))
    readonly property real frac: Math.max(0, Math.min(1, (target?.contentY ?? 0) / Math.max(1, (target?.contentHeight ?? 1) - (target?.height ?? 1))))

    visible: scrollable && rail.opacity > 0.01

    Connections {
        target: root.target

        function onContentYChanged() {
            root._awake = true;
            sleepTimer.restart();
        }
    }

    Timer {
        id: sleepTimer

        interval: 700
        onTriggered: root._awake = false
    }

    Rectangle {
        id: rail

        anchors.verticalCenter: parent.verticalCenter
        x: 0
        width: root._awake ? 1.5 : 1
        height: parent.height
        color: root._awake ? Theme.acid : Theme.hairline
        opacity: root._awake ? 0.35 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.movSlow
                easing.type: Easing.OutCubic
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation { duration: Theme.movFast }
        }
    }

    Rectangle {
        id: thumb

        y: root.frac * (root.height - height)
        width: 3
        height: root.thumbH
        color: Theme.lineStrong
        opacity: root._awake ? 1 : 0.35

        Behavior on y {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.movSlow
                easing.type: Easing.OutCubic
            }
        }
    }
}
