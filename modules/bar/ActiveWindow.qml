import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import qs.theme

Item {
    id: root

    implicitHeight: Theme.barHeight

    property string appClass: ""
    property string winTitle: ""

    readonly property bool hasClient: appClass.length > 0

    Process {
        id: initialProbe
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(this.text);
                    root.appClass = String(j["class"] ?? "");
                    root.winTitle = String(j.title ?? "");
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: false
        onTriggered: initialProbe.running = true
    }

    Connections {
        target: Hyprland

        function onRawEvent(evt) {
            if (evt.name === "activewindow") {
                // evt.data can arrive null/undefined on some event bursts
                const d = String(evt.data ?? "");
                const idx = d.indexOf(",");
                root.appClass = idx > 0 ? d.slice(0, idx) : "";
                root.winTitle = idx >= 0 ? d.slice(idx + 1) : "";
            } else if (evt.name === "activewindowv2" && !evt.data) {
                root.appClass = "";
                root.winTitle = "";
            }
        }
    }

    Text {
        id: crossGlyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        visible: root.hasClient
        text: "+"
        color: Theme.acid
        font.family: Theme.fontFamily
        font.pixelSize: 11
    }

    Text {
        id: slashText
        visible: root.hasClient
        anchors.left: crossGlyph.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "//"
        color: Theme.acid
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.weight: Font.Bold
    }

    Text {
        id: classText
        visible: root.hasClient
        anchors.left: slashText.right
        anchors.leftMargin: 7
        anchors.verticalCenter: parent.verticalCenter
        text: root.appClass.toUpperCase()
        color: Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.weight: Font.DemiBold
        font.letterSpacing: 1
    }

    Text {
        id: dashText
        visible: root.hasClient && root.winTitle.length > 0
        anchors.left: classText.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "\u2014"
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }

    Text {
        id: titleText
        visible: root.hasClient
        anchors.left: dashText.visible ? dashText.right : classText.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: root.winTitle
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
    }

    Item {
        visible: !root.hasClient
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: noSignalLabel.implicitWidth + 10
        height: 14

        Text {
            id: noSignalLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Theme.jpEnabled ? "NO SIGNAL // 待機中" : "NO SIGNAL // TAIKI"
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.letterSpacing: 1
        }

        // blinking cursor — hacker terminal aesthetic
        Rectangle {
            anchors.left: noSignalLabel.right
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 11
            color: Theme.acid

            SequentialAnimation on opacity {
                running: !root.hasClient
                loops: Animation.Infinite

                NumberAnimation {
                    from: 1
                    to: 0
                    duration: 530
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    from: 0
                    to: 1
                    duration: 530
                    easing.type: Easing.InOutSine
                }
            }
        }
    }
}
