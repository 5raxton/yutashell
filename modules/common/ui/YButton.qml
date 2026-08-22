import QtQuick
import qs.theme

// Solid button with hard-shadow press physics.
// tone: "default" (ink outline) | "acid" (primary) | "danger" (alert)
Rectangle {
    id: root

    property string label: ""
    property string tone: "default"
    signal clicked()

    readonly property bool isAcid: tone === "acid"
    readonly property bool isDanger: tone === "danger"
    readonly property color liveLine: isAcid ? Theme.acid : isDanger ? Theme.alert : Theme.lineStrong
    readonly property color liveText: isAcid ? Theme.acid : isDanger ? Theme.alert : Theme.ink

    implicitWidth: labelText.width + Theme.sp3 * 2
    implicitHeight: Theme.ctlH
    color: area.containsMouse ? liveLine : "transparent"
    border.width: 1
    border.color: area.containsMouse ? liveLine : Qt.rgba(liveLine.r, liveLine.g, liveLine.b, 0.55)

    // hard offset shadow — collapses on press so the button feels physical
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: pressedOffset
        anchors.topMargin: pressedOffset
        anchors.rightMargin: -pressedOffset
        anchors.bottomMargin: -pressedOffset
        color: "transparent"
        border.width: 1
        border.color: Theme.faint
        z: -1

        property int pressedOffset: area.pressed ? 0 : 2

        Behavior on pressedOffset {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }
    }

    Text {
        id: labelText

        anchors.centerIn: parent
        text: root.label.toUpperCase()
        color: area.containsMouse ? Theme.bg : root.liveText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
        font.weight: Font.Bold
        font.letterSpacing: 1.5
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
