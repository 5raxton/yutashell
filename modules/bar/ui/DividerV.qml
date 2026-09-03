import QtQuick
import qs.theme

// Uniform segment separator: a single centered hairline tick floating in a
// fixed-width gutter. Every zone gap in the bar uses exactly this rhythm.
Item {
    id: root

    implicitWidth: Math.round(17 * Theme.barScale)
    implicitHeight: Theme.scaledBarHeight

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: Math.round(14 * Theme.barScale)
        color: Theme.lineStrong
    }
}
