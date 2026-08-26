import Quickshell
import QtQuick
import qs.theme
import qs.modules.common

Item {
    id: root

    implicitWidth: contentRow.width
    implicitHeight: Theme.scaledBarHeight

    readonly property string hostname: (Quickshell.env("HOSTNAME") ?? "yuta").toUpperCase()

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
        spacing: Theme.sp2

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
                    font.pixelSize: Math.round(11 * Theme.barScale)
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(4 * Theme.barScale)
                    height: Math.round(11 * Theme.barScale)
                    color: Theme.acid

                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 1
                            to: 0.15
                            duration: 520
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: 0.15
                            to: 1
                            duration: 520
                            easing.type: Easing.InOutSine
                        }
                    }
                }
            }

            Text {
                text: "YUTA.SHELL // v" + Theme.version
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.barFsMicro
                font.letterSpacing: 2
            }
        }
    }
}
