import QtQuick
import qs.theme

// Bordered tag chip. tone: "outline" | "acid" | "alert"
// Counters tick: a label change snaps the chip through a micro pop.
Rectangle {
    id: root

    property string label: ""
    property string tone: "outline"

    readonly property bool isAcid: tone === "acid"
    readonly property bool isAlert: tone === "alert"

    implicitWidth: chipText.width + Theme.sp2 * 2
    implicitHeight: 15
    color: "transparent"
    border.width: 1
    border.color: root.isAcid ? Theme.acid : root.isAlert ? Theme.alert : Theme.lineStrong

    onLabelChanged: tickAnim.restart()

    SequentialAnimation {
        id: tickAnim

        NumberAnimation {
            target: root
            property: "scale"
            from: 1.18
            to: 1.0
            duration: Theme.movSnap
            easing.type: Easing.OutBack
            easing.overshoot: 0.6
        }
    }

    Text {
        id: chipText

        anchors.centerIn: parent
        text: root.label.toUpperCase()
        color: root.isAcid ? Theme.acid : root.isAlert ? Theme.alert : Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsMicro
        font.weight: Font.Bold
        font.letterSpacing: 1
    }
}
