import QtQuick
import qs.theme

// Uniform segment separator: a single centered hairline tick floating in a
// fixed-width gutter. Every zone gap in the bar uses exactly this rhythm.
Item {
    id: root

    implicitWidth: 17
    implicitHeight: Theme.barHeight

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: 14
        color: Theme.lineStrong
    }
}
