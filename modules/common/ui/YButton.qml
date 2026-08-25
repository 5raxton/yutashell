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

    implicitWidth: labelText.implicitWidth + Theme.sp3 * 2
    implicitHeight: Theme.ctlH
    activeFocusOnTab: true
    color: area.containsMouse || activeFocus ? liveLine : "transparent"
    border.width: 1
    border.color: activeFocus ? Theme.acid : area.containsMouse ? liveLine : Qt.rgba(liveLine.r, liveLine.g, liveLine.b, 0.55)

    Behavior on color {
        ColorAnimation { duration: Theme.movFast }
    }

    Behavior on border.color {
        ColorAnimation { duration: Theme.movFast }
    }

    scale: area.containsMouse ? 1.03 : 1

    Behavior on scale {
        NumberAnimation {
            duration: Theme.movSnap
            easing.type: Easing.OutBack
            easing.overshoot: 0.3
        }
    }

    Keys.onReturnPressed: event => {
        event.accepted = true;
        root.clicked();
    }
    Keys.onSpacePressed: event => {
        event.accepted = true;
        root.clicked();
    }

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
        // when a consumer forces a width below the label's natural size,
        // truncate with an ellipsis instead of painting past the border
        width: Math.max(0, Math.min(implicitWidth, root.width - Theme.sp1))
        elide: Text.ElideRight
        text: root.label.toUpperCase()
        color: area.containsMouse || root.activeFocus ? Theme.bg : root.liveText
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
        font.weight: Font.Bold
        font.letterSpacing: 1.5
    }

    // default tone keeps its fill on hover; this acid underline is the
    // "acknowledged" cue for idle state — draws in, snaps out
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        height: 2
        width: !root.isAcid && !root.isDanger && area.containsMouse ? parent.width : 0
        color: Theme.acid

        Behavior on width {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
