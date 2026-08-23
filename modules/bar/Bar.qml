import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "ui"
import "../net"
import "../audio"
import "../session"
import "../widgets"
import "../common/ui"
import "."

// Bar v2 (PH.14) — a data-driven organism. The layout (which segments, in
// which zone, in what order) is persisted in ShellState.barSegments and
// resolved by the BarSegments singleton; each segment composes its own
// component and honors its click-action via BarActions. Scale + position
// are persisted too. The bar stays on the Overlay layer — popups slide out
// from behind it.
PanelWindow {
    id: root

    property var tip

    // Overlay: topmost layer. Popups land on Top, so anything sliding down
    // emerges from BEHIND this bar.
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool topBar: ShellState.barPosition !== "bottom"
    readonly property real scaleFactor: Math.max(0.8, Math.min(1.4, ShellState.barScale))

    anchors {
        top: root.topBar
        bottom: !root.topBar
        left: true
        right: true
    }

    implicitHeight: Math.round(Theme.barHeight * root.scaleFactor)
    color: "transparent"

    Rectangle {
        id: frame

        anchors.fill: parent
        color: Theme.bg

        // hairline — bottom edge for a top bar, top edge for a bottom bar
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: root.topBar ? parent.bottom : undefined
            anchors.top: root.topBar ? undefined : parent.top
            height: 1
            color: Theme.hairline
        }

        // the living strip — pulses at the bar's leading edge
        YPulse {
            x: Theme.outerPad
            y: root.topBar ? 0 : parent.height - height
            width: 132
            height: 2
            color: Theme.acid
            lo: 0.55
        }

        // content — sized to the natural bar height, Y-scaled to the pref
        Item {
            id: content

            x: 0
            y: 0
            width: parent.width
            height: Theme.barHeight
            transform: Scale {
                yScale: root.scaleFactor
            }

            // ---- LEFT ZONE ----
            Row {
                id: leftRow

                anchors.left: parent.left
                anchors.leftMargin: Theme.outerPad
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: BarSegments.leftVisible

                    delegate: segDelegate
                }
            }

            // ---- CENTER (active window fill) ----
            ActiveWindow {
                anchors.left: leftRow.right
                anchors.leftMargin: 18
                anchors.right: rightRow.left
                anchors.rightMargin: 18
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: BarSegments.present("activewindow")
            }

            // ---- RIGHT ZONE ----
            Row {
                id: rightRow

                anchors.right: parent.right
                anchors.rightMargin: Theme.outerPad
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: BarSegments.rightVisible

                    delegate: segDelegate
                }
            }
        }
    }

    // ---- segment delegate: divider (except first) + the segment ----------
    Component {
        id: segDelegate

        Row {
            required property int index
            required property var modelData

            spacing: 0

            DividerV {
                visible: index > 0
            }

            Loader {
                sourceComponent: root.segComponent(modelData.id)
            }
        }
    }

    function segComponent(id) {
        switch (id) {
        case "identity":
            return identityComp;
        case "workspaces":
            return workspacesComp;
        case "taskbar":
            return taskbarComp;
        case "tray":
            return trayComp;
        case "media":
            return mediaComp;
        case "net":
            return netComp;
        case "bt":
            return btComp;
        case "audio":
            return audioComp;
        case "stats":
            return statsComp;
        case "cputemp":
            return cputempComp;
        case "gpu":
            return gpuComp;
        case "disk":
            return diskComp;
        case "nightlight":
            return nlComp;
        case "session":
            return sessComp;
        case "recording":
            return recComp;
        case "clock":
            return clockComp;
        }
        return null;
    }

    Component {
        id: identityComp

        IdentityBlock {}
    }

    Component {
        id: workspacesComp

        Workspaces {}
    }

    Component {
        id: taskbarComp

        Taskbar {
            tip: root.tip
        }
    }

    Component {
        id: trayComp

        TrayCluster {
            tip: root.tip
        }
    }

    Component {
        id: mediaComp

        MediaBlock {
            tip: root.tip
        }
    }

    Component {
        id: netComp

        NetBlock {
            tip: root.tip
        }
    }

    Component {
        id: btComp

        BtBlock {
            tip: root.tip
        }
    }

    Component {
        id: audioComp

        AudioBlock {
            tip: root.tip
        }
    }

    Component {
        id: statsComp

        StatsCluster {
            tip: root.tip
        }
    }

    Component {
        id: cputempComp

        StatCell {
            kind: "cputemp"
            tip: root.tip
        }
    }

    Component {
        id: gpuComp

        StatCell {
            kind: "gpu"
            tip: root.tip
        }
    }

    Component {
        id: diskComp

        StatCell {
            kind: "disk"
            tip: root.tip
        }
    }

    Component {
        id: nlComp

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "☾"
            color: Theme.acid
            font.family: Theme.fontFamily
            font.pixelSize: 12

            SequentialAnimation on opacity {
                running: true
                loops: Animation.Infinite

                NumberAnimation {
                    from: 1.0
                    to: 0.45
                    duration: 1600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 0.45
                    to: 1.0
                    duration: 1600
                    easing.type: Easing.InOutSine
                }
            }
        }
    }

    Component {
        id: sessComp

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰤄 " + Session.inhibitCount
            color: Theme.acid
            font.family: Theme.fontFamily
            font.pixelSize: 12
        }
    }

    Component {
        id: recComp

        Row {
            spacing: 6
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                color: Theme.alert

                SequentialAnimation on opacity {
                    running: true
                    loops: Animation.Infinite

                    NumberAnimation {
                        from: 1.0
                        to: 0.25
                        duration: 620
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        from: 0.25
                        to: 1.0
                        duration: 620
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "REC"
                color: Theme.alert
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.weight: Font.Bold
                font.letterSpacing: 1.5
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Recording.stop()
            }
        }
    }

    Component {
        id: clockComp

        ClockBlock {}
    }
}
