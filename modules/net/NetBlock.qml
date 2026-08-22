import Quickshell
import Quickshell.Networking
import QtQuick
import qs.theme
import qs.modules.common

Item {
    id: root

    implicitWidth: netRow.width
    implicitHeight: Theme.barHeight

    property var tip

    readonly property var wifiDev: {
        const devs = Networking.devices.values;
        for (let i = 0; i < devs.length; i++)
            if (devs[i].type === DeviceType.Wifi)
                return devs[i];
        return null;
    }

    readonly property var wiredDev: {
        const devs = Networking.devices.values;
        for (let i = 0; i < devs.length; i++)
            if (devs[i].type === DeviceType.Wired)
                return devs[i];
        return null;
    }

    // the connected wifi network, if any
    readonly property var activeWifi: {
        if (!wifiDev)
            return null;
        const nets = wifiDev.networks.values;
        for (let i = 0; i < nets.length; i++)
            if (nets[i].connected)
                return nets[i];
        return null;
    }

    readonly property bool wifiOn: Networking.wifiEnabled && wifiDev !== null
    readonly property bool wiredUp: wiredDev !== null && wiredDev.hasLink
    readonly property int strength: activeWifi ? Math.max(0, Math.min(100, activeWifi.signalStrength)) : 0

    // tier = how many of the four bars are lit
    readonly property int tiers: !wifiOn ? 0 : !activeWifi ? (wiredUp ? 0 : 0) : strength >= 75 ? 4 : strength >= 50 ? 3 : strength >= 25 ? 2 : 1

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

        // wired glyph: two stacked bars
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
            visible: !root.wifiOn
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
            else if (area.containsMouse)
                root.showCol(netRow, root.wiredUp ? "wired · open network" : root.activeWifi ? root.activeWifi.name + " · " + root.strength + "%" : root.wifiOn ? "wifi on · not connected" : "wifi off");
            else
                root.hideCol();
        }

        target: area
    }
}
