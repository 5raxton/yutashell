import Quickshell
import Quickshell.Io
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"

// NetDetails — information-dense network details panel (PH.06.1).
// Active interface, IP4/IP6 addresses, gateway, DNS, signal strength,
// link speed, VPN status. Data sourced from nmcli.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: ShellState.netDetailsOpen || hideDelay.running
    mask: Region {
        item: ShellState.netDetailsOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.netDetailsOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: 460
    readonly property int padX: Theme.sp4

    // parsed network detail fields
    property string device: ""
    property string connection: ""
    property string ipAddress4: ""
    property string ipAddress6: ""
    property string gateway: ""
    property string dnsServers: ""
    property string signal: ""
    property string linkSpeed: ""
    property string vpnStatus: ""
    property string macAddress: ""

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    Connections {
        target: ShellState

        function onNetDetailsOpenChanged() {
            if (ShellState.netDetailsOpen) {
                detailProbe.running = true;
                connProbe.running = true;
            }
            if (!ShellState.netDetailsOpen)
                hideDelay.restart();
        }
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeNetDetails()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeNetDetails()
        }

        YSurface {
            spawnId: "netdetails"
            open: ShellState.netDetailsOpen
            anchorX: "right"
            cardW: root.cardW
            cardH: Math.max(400, contentCol.height + Theme.sp4 * 2)

            Column {
                id: contentCol

                x: root.padX
                y: 0
                width: parent.width - root.padX * 2 - 1
                spacing: Theme.sp3

                // ---- header ----
                Item {
                    width: parent.width
                    height: Theme.headH

                    Rectangle {
                        id: mark

                        x: 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: 22
                        height: 22
                        color: "transparent"
                        border.width: 1
                        border.color: root.connection.length > 0 ? Theme.acid : Theme.lineStrong

                        Text {
                            anchors.centerIn: parent
                            text: "◆"
                            color: root.connection.length > 0 ? Theme.acid : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 11
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: mark.right
                        anchors.leftMargin: Theme.sp2
                        text: "NET.INFO"
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBody
                        font.weight: Font.ExtraBold
                        font.letterSpacing: 1.5
                    }

                    YChip {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        label: root.connection.length > 0 ? root.connection.toUpperCase() : "OFFLINE"
                        tone: root.connection.length > 0 ? "acid" : "outline"
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.hairline
                }

                // ---- interface ----
                YSection {
                    width: parent.width
                    index: "01"
                    label: "Interface"
                    chip: root.device.toUpperCase()
                }

                YRow {
                    width: parent.width
                    title: "Device"
                    sub: root.device.length > 0 ? root.device : "—"
                    note: "DEV"
                    interactive: false
                }

                YRow {
                    visible: root.macAddress.length > 0
                    width: parent.width
                    title: "MAC"
                    sub: root.macAddress
                    note: "HW"
                    interactive: false
                }

                // ---- IPv4 ----
                YSection {
                    width: parent.width
                    index: "02"
                    label: "IPv4"
                    chip: root.ipAddress4.length > 0 ? "ACTIVE" : "NONE"
                }

                YRow {
                    width: parent.width
                    title: "Address"
                    sub: root.ipAddress4.length > 0 ? root.ipAddress4 : "no IPv4 address"
                    note: "IP"
                    interactive: root.ipAddress4.length > 0
                    onClicked: {
                        if (root.ipAddress4.length > 0) {
                            copyCmd.command = ["wl-copy", root.ipAddress4];
                            copyCmd.running = true;
                        }
                    }
                }

                YRow {
                    visible: root.gateway.length > 0
                    width: parent.width
                    title: "Gateway"
                    sub: root.gateway
                    note: "GW"
                    interactive: false
                }

                // ---- IPv6 ----
                YSection {
                    visible: root.ipAddress6.length > 0
                    width: parent.width
                    index: "03"
                    label: "IPv6"
                    chip: "ACTIVE"
                }

                YRow {
                    visible: root.ipAddress6.length > 0
                    width: parent.width
                    title: "Address"
                    sub: root.ipAddress6
                    note: "IP6"
                    interactive: true
                    onClicked: {
                        copyCmd.command = ["wl-copy", root.ipAddress6];
                        copyCmd.running = true;
                    }
                }

                // ---- DNS ----
                YSection {
                    visible: root.dnsServers.length > 0
                    width: parent.width
                    index: "04"
                    label: "DNS"
                    chip: root.dnsServers.split("  ·  ").length + ""
                }

                Text {
                    visible: root.dnsServers.length > 0
                    width: parent.width
                    text: root.dnsServers
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    wrapMode: Text.Wrap
                }

                // ---- signal (wifi) ----
                YSection {
                    visible: root.signal.length > 0
                    width: parent.width
                    index: "05"
                    label: "Signal"
                    chip: root.signal
                }

                YRow {
                    visible: root.signal.length > 0
                    width: parent.width
                    title: "Strength"
                    sub: root.signal
                    note: "SIG"
                    interactive: false
                }

                YRow {
                    visible: root.linkSpeed.length > 0
                    width: parent.width
                    title: "Link speed"
                    sub: root.linkSpeed
                    note: "SPD"
                    interactive: false
                }

                // ---- VPN ----
                YSection {
                    visible: root.vpnStatus.length > 0
                    width: parent.width
                    index: "06"
                    label: "VPN"
                    chip: root.vpnStatus.toUpperCase()
                }

                Item {
                    width: 1
                    height: Theme.sp2
                }
            }
        }
    }

    // nmcli detail probe
    Process {
        id: detailProbe

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const fields = {};
                for (let i = 0; i < lines.length; i++) {
                    const idx = lines[i].indexOf(":");
                    if (idx > 0) {
                        const k = lines[i].slice(0, idx).trim();
                        const v = lines[i].slice(idx + 1).trim();
                        if (k.length > 0)
                            fields[k] = v;
                    }
                }
                root.device = fields["GENERAL.DEVICE"] || "";
                root.connection = fields["GENERAL.NAME"] || "";
                root.macAddress = fields["GENERAL.HWADDR"] || "";
                root.ipAddress4 = fields["IP4.ADDRESS[1]"] || "";
                root.gateway = fields["IP4.GATEWAY"] || "";
                root.dnsServers = fields["IP4.DNS[1]"] || "";
                root.ipAddress6 = fields["IP6.ADDRESS[1]"] || "";
                root.signal = fields["WIFI.PROPERTIES.SIGNAL"] || "";
                root.linkSpeed = fields["GENERAL.SPEED"] || "";
            }
        }
    }

    // active connection name probe
    Process {
        id: connProbe

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split(":");
                    if (parts.length >= 4 && parts[3] === "yes") {
                        root.connection = parts[0];
                        break;
                    }
                }
            }
        }
    }

    // copy to clipboard
    Process {
        id: copyCmd

        stdout: StdioCollector {}
    }
}
