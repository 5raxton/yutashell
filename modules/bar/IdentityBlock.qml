import Quickshell
import QtQuick
import qs.theme
import qs.modules.common

Item {
    id: root

    implicitWidth: contentRow.width
    implicitHeight: Theme.barHeight

    property bool blinkOn: true

    readonly property string hostname: (Quickshell.env("HOSTNAME") || "yuta").toUpperCase()

    Timer {
        interval: 600
        running: true
        repeat: true
        onTriggered: root.blinkOn = !root.blinkOn
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        // honor the segment click map (default → settings)
        onClicked: {
            const a = BarSegments.clickFor("identity");
            if (a.length > 0)
                BarActions.dispatch(a);
            else
                ShellState.togglePanel();
        }
    }

    Row {
        id: contentRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 9

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 10
            height: 10
            color: hoverArea.containsMouse ? Theme.acid : Theme.ink

            Rectangle {
                x: parent.width - 4
                y: parent.height - 4
                width: 4
                height: 4
                color: Theme.bg
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            Row {
                spacing: 4

                Text {
                    text: root.hostname + " // " + (Theme.jpEnabled ? "因果" : "INGA")
                    color: hoverArea.containsMouse ? Theme.acid : Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 11
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 11
                    color: Theme.acid
                    opacity: root.blinkOn ? 1 : 0
                }
            }

            Text {
                text: "YUTA.SHELL // v" + Theme.version
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: 7
                font.letterSpacing: 2
            }
        }
    }
}
