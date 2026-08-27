import Quickshell
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui
import "../focus"

// BreakOverlay (PH.05) — fullscreen overlay shown during focus breaks.
// Large countdown timer + rotating health tips. Dismissible after minimum
// break time (10s). Blocks input via exclusion mode.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    readonly property bool show: FocusMode.showBreak && FocusMode.running

    anchors { top: true; bottom: true; left: true; right: true }
    color: "#cc000000"
    exclusionMode: ExclusionMode.Ignore
    visible: root.show

    WlrLayershell.layer: WlrLayer.Overlay

    // health tips that rotate every 8 seconds
    property var tips: [
        "Look at something 20 feet away for 20 seconds",
        "Stretch your shoulders and neck",
        "Drink some water",
        "Stand up and walk around",
        "Roll your ankles and wrists",
        "Take 5 deep breaths",
        "Rest your eyes — close them for 30 seconds",
        "Touch your toes or do a gentle forward fold",
        "Roll your head in slow circles"
    ]
    property int tipIndex: 0

    Timer {
        interval: 8000
        running: root.show
        repeat: true
        onTriggered: root.tipIndex = (root.tipIndex + 1) % root.tips.length
    }

    Column {
        anchors.centerIn: parent
        spacing: 24

        // phase label
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: FocusMode.phase === "longBreak" ? "LONG BREAK" : "BREAK TIME"
            color: Theme.acid
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsTitle
            font.weight: Font.Bold
            font.letterSpacing: 4
        }

        // countdown
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: FocusMode.display
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: 96
            font.weight: Font.Light
        }

        // health tip
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 480
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.tips[root.tipIndex]
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBody
        }

        // dismiss hint
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: FocusMode.remaining <= (FocusMode.breakMin * 60 - 10)
            text: "Click anywhere to continue"
            color: Theme.faint
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.letterSpacing: 2
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            // only dismiss after minimum break time (10s)
            const elapsed = (FocusMode.breakMin * 60) - FocusMode.remaining;
            if (elapsed >= 10) {
                // skip to next phase
                FocusMode.remaining = 0;
            }
        }
    }

    // round counter at bottom
    Text {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 40
        anchors.horizontalCenter: parent.horizontalCenter
        text: "Round " + FocusMode.round + " / " + FocusMode.roundsBeforeLong
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsMicro
        font.letterSpacing: 2
    }
}
