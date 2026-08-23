import Quickshell
import Quickshell.Networking
import QtQuick
import qs.theme
import qs.modules.common
import "."

Item {
    id: root

    implicitWidth: netRow.width
    implicitHeight: Theme.barHeight

    property var tip

    readonly property bool wifiOn: Connectivity.wifiOn
    readonly property bool wiredUp: Connectivity.wiredUp
    readonly property int strength: Connectivity.strength
    readonly property var activeWifi: Connectivity.activeWifi

    // tier = how many of the four bars are lit
    readonly property int tiers: !wifiOn ? 0 : !activeWifi ? 0 : strength >= 75 ? 4 : strength >= 50 ? 3 : strength >= 25 ? 2 : 1

    function showCol(item, text) {
        if (tip)
            tip.showFor(item, text);
    }

    function hideCol() {
        if (tip)
            tip.hide();
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.toggleNet()
    }

    Row {
        id: netRow

        anchors.verticalCenter: parent.verticalCenter

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "NET"
            color: root.tiers > 0 || root.wiredUp ? Theme.ink : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsMicro
            font.weight: Font.Bold
            font.letterSpacing: 1.5
        }

        Item {
            width: 8
            height: 1
        }

        // wired glyph: two stacked bars (primary link wins the slot)
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: root.wiredUp

            Rectangle {
                width: 14
                height: 2
                color: Theme.acid
            }

            Rectangle {
                width: 10
                height: 2
                color: Theme.acid
            }
        }

        // wifi signal tiers
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            visible: !root.wiredUp

            Repeater {
                model: 4

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: 3
                    height: 3 + index * 3
                    color: root.tiers > index ? Theme.acid : Theme.lineStrong
                }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.wifiOn && !root.wiredUp
            text: "×"
            color: Theme.alert
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }

    Connections {
        function onPressedChanged() {
            if (area.pressed)
                ;
            else if (area.containsMouse) {
                const c = Connectivity;
                let t;
                if (root.wiredUp)
                    t = "wired · open network" + (c.wiredSpeed ? " · " + c.wiredSpeed : "");
                else if (root.activeWifi)
                    t = root.activeWifi.name + " · " + root.strength + "%";
                else
                    t = c.wifiOn ? "wifi on · not connected" : "wifi off";
                root.showCol(netRow, t);
            } else
                root.hideCol();
        }

        target: area
    }
}
