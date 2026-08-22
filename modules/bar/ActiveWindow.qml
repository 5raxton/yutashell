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
                const idx = evt.data.indexOf(",");
                root.appClass = idx > 0 ? evt.data.slice(0, idx) : "";
                root.winTitle = evt.data.slice(idx + 1);
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

    Text {
        visible: !root.hasClient
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: Theme.jpEnabled ? "NO SIGNAL // 待機中" : "NO SIGNAL // TAIKI"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: 10
        font.letterSpacing: 1
    }
}
