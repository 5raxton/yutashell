import QtQuick
import qs.theme

// Brutalist slider — hairline track, acid fill, square thumb that grows
// under the hand. Cubic taper is the CONSUMER's business; this control only
// moves fractions.
Item {
    id: root

    property real value: 0 // 0..1 (bound by consumer to live state)
    property real hot: 0.8 // fraction past which the fill burns acid
    signal moved(real v)

    implicitWidth: 200
    implicitHeight: 20

    readonly property real shown: area.pressed ? area._drag : value

    // track
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: 2
        color: Theme.hairline
    }

    // fill — lineStrong normally, acid past `hot` or while grabbed
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        width: Math.max(0, Math.min(1, root.shown)) * parent.width
        height: 2
        color: area.pressed || root.shown >= root.hot ? Theme.acid : Theme.lineStrong

        Behavior on color {
            ColorAnimation {
                duration: Theme.movFast
            }
        }
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(1, root.shown)) * (parent.width - width)
        width: area.pressed ? 10 : 6
        height: width
        color: root.shown >= root.hot || area.pressed ? Theme.acid : Theme.faint
        scale: area.containsMouse || area.pressed ? 1.2 : 1

        Behavior on width {
            NumberAnimation {
                duration: Theme.movSnap
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: Theme.movSnap
                easing.type: Easing.OutBack
                easing.overshoot: 0.3
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.movFast
            }
        }
    }

    MouseArea {
        id: area

        property real _drag: 0

        anchors.fill: parent
        anchors.margins: -6
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function _apply(x) {
            _drag = Math.max(0, Math.min(1, (x + 6) / (width - 12)));
            root.moved(_drag);
        }

        onPressed: mouse => _apply(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                _apply(mouse.x);
        }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.03 : -0.03))))
    }
}
