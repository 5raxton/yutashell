import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."

// Network suite surface — wifi list + join dialog, wired status, VPN toggle,
// DNS view + quick-set, airplane master switch. Device state comes from the
// shared Connectivity model; VPN/DNS ride nmcli (NetworkManager's own CLI).
PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: ShellState.netOpen || hideDelay.running
    mask: Region {
        item: ShellState.netOpen ? surface : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.netOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(760, contentRoot.width - Theme.outerPad * 2)
    readonly property int cardH: Math.min(620, contentRoot.height - Theme.barHeight - Theme.outerPad * 2)
    readonly property int padX: Theme.sp4
    readonly property int contentW: cardW - padX * 2 - 1

    // ---- shared connectivity model ----
    readonly property var wifiDev: Connectivity.wifiDev
    readonly property bool airplane: Connectivity.airplane

    readonly property var nets: {
        if (!wifiDev || !Networking.wifiEnabled)
            return [];
        const arr = wifiDev.networks.values.slice();
        arr.sort((a, b) => b.signalStrength - a.signalStrength);
        return arr.slice(0, 14);
    }

    // selected unknown network awaiting PSK
    property string pendingJoin: ""

    // applied DNS override for the active managed profile
    property string appliedDns: ""

    Timer {
        id: hideDelay

        interval: 190
    }

    // scan while open, rest when closed
    Connections {
        target: ShellState

        function onNetOpenChanged() {
            if (ShellState.netOpen) {
                if (root.wifiDev)
                    root.wifiDev.scannerEnabled = true;
                Connectivity.refresh();
            } else {
                if (root.wifiDev)
                    root.wifiDev.scannerEnabled = false;
            }
        }
    }

    Component.onCompleted: refreshTimer.start()

    // periodic re-poll of nmcli-derived data while open
    Timer {
        id: refreshTimer

        interval: 5000
        running: ShellState.netOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: Connectivity.refresh()
    }

    // applied-DNS follows the active profile reported by the shared model
    Connections {
        target: Connectivity

        function onActiveConChanged() {
            if (!Connectivity.activeCon) {
                root.appliedDns = "";
                return;
            }
            appliedProbe.command = ["nmcli", "-g", "ipv4.dns", "con", "show", Connectivity.activeCon];
            appliedProbe.running = true;
        }
    }

    function runNm(args) {
        followup.command = args;
        followup.running = true;
    }

    Process {
        id: appliedProbe

        stdout: StdioCollector {
            onStreamFinished: root.appliedDns = text.trim()
        }
    }

    Process {
        id: followup

        onExited: Connectivity.refresh()
    }

    function vpnToggle(row) {
        Connectivity.vpnToggle(row);
    }

    function applyDns(val) {
        if (!Connectivity.activeCon)
            return;
        runNm(["nmcli", "con", "mod", Connectivity.activeCon, "ipv4.dns", val]);
        runNm(["nmcli", "con", "up", Connectivity.activeCon]);
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            root.pendingJoin = "";
            ShellState.closeNet();
        }

        YSurface {
            id: surface

            open: ShellState.netOpen
            cascade: bodyCol
            anchorX: "right"
            cardW: root.cardW
            cardH: Math.max(320, root.cardH)

            // ---- header ----
            Item {
                x: root.padX
                y: 0
                width: parent.width - root.padX * 2 - 1
                height: Theme.headH

                Rectangle {
                    id: mark

                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    color: "transparent"
                    border.width: 1
                    border.color: root.airplane ? Theme.alert : Theme.acid

                    Text {
                        anchors.centerIn: parent
                        text: "網"
                        visible: Theme.jpEnabled
                        color: root.airplane ? Theme.alert : Theme.acid
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !Theme.jpEnabled
                        text: "N"
                        color: root.airplane ? Theme.alert : Theme.acid
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        font.weight: Font.ExtraBold
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: mark.right
                    anchors.leftMargin: Theme.sp2
                    text: "NET.WORK"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                YChip {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    label: Connectivity.wiredUp ? "WIRED" : root.airplane ? "AIRPLANE" : Networking.connectivity === NetworkConnectivity.Full ? "ONLINE" : "OFFLINE"
                    tone: root.airplane ? "alert" : "outline"
                }
            }

            Rectangle {
                x: root.padX
                y: Theme.headH
                width: parent.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            Flickable {
                id: scroll

                x: root.padX
                y: Theme.headH + 1
                width: parent.width - root.padX * 2 - 1
                height: parent.height - Theme.headH - Theme.sp3
                clip: true
                contentWidth: width
                contentHeight: bodyCol.height

                FastWheel {}

                Column {
                    id: bodyCol

                    width: parent.width
                    spacing: Theme.sp2

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Radios"
                        chip: root.airplane ? "airplane" : ""
                    }

                    YRow {
                        width: root.contentW
                        title: "Airplane mode"
                        sub: root.airplane ? "wifi + bluetooth radios down" : "radios up"
                        note: "AIR"
                        on_: root.airplane
                        onToggled: {
                            const next = !root.airplane;
                            Networking.wifiEnabled = !next;
                            if (Bluetooth.defaultAdapter)
                                Bluetooth.defaultAdapter.enabled = !next;
                        }

                        YSwitch {
                            checked: root.airplane
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: {
                                const next = !root.airplane;
                                Networking.wifiEnabled = !next;
                                if (Bluetooth.defaultAdapter)
                                    Bluetooth.defaultAdapter.enabled = !next;
                            }
                        }
                    }

                    YRow {
                        width: root.contentW
                        title: "Wi-Fi radio"
                        sub: !root.wifiDev ? "no wifi hardware" : Networking.wifiHardwareEnabled ? (Networking.wifiEnabled ? "scanning enabled" : "radio off") : "hard-blocked (rfkill)"
                        note: "WFI"
                        interactive: root.wifiDev !== null && Networking.wifiHardwareEnabled
                        on_: Networking.wifiEnabled

                        YSwitch {
                            checked: Networking.wifiEnabled
                            enabled: root.wifiDev !== null && Networking.wifiHardwareEnabled
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "Wireless networks"
                        chip: root.nets.length > 0 ? root.nets.length + "" : ""
                    }

                    Text {
                        width: parent.width
                        visible: root.nets.length === 0
                        text: !Networking.wifiEnabled ? "radio off" : "no networks — still scanning…"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                    }

                    Repeater {
                        model: root.nets

                        delegate: Rectangle {
                            id: netRow

                            required property int index
                            required property var modelData

                            readonly property bool known: modelData.known
                            readonly property bool joined: modelData.connected
                            readonly property bool pending: root.pendingJoin === modelData.name

                            width: root.contentW
                            height: pending ? 84 : 40
                            color: harea.containsMouse ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.04) : "transparent"
                            border.width: 1
                            border.color: pending ? Theme.acid : "transparent"
                            Behavior on height {
                                NumberAnimation {
                                    duration: Theme.movFast
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.sp2
                                spacing: Theme.sp2

                                Row {
                                    spacing: Theme.sp2

                                    // signal tiers
                                    Row {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 2

                                        Repeater {
                                            model: 4

                                            Rectangle {
                                                anchors.bottom: parent.bottom
                                                width: 3
                                                height: 3 + index * 3
                                                color: netRow.modelData.signalStrength >= [25, 50, 75, 101][index] ? Theme.acid : Theme.lineStrong
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: netRow.modelData.name
                                        color: netRow.joined ? Theme.acid : Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsBody
                                        font.weight: netRow.joined ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                        width: Math.min(360, root.contentW - 160)
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: netRow.modelData.security !== WifiSecurityType.None
                                        text: "⚿"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 11
                                    }

                                    YChip {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: netRow.joined
                                        label: "CONN"
                                        tone: "acid"
                                    }

                                    YChip {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: netRow.known && !netRow.joined
                                        label: "SAVED"
                                        tone: "outline"
                                    }

                                    Item {
                                        width: parent.width > 0 ? 1 : 1
                                        height: 1
                                    }

                                    YButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: harea.containsMouse && netRow.known && !netRow.joined
                                        label: "FORGET"
                                        tone: "danger"
                                        onClicked: netRow.modelData.forget()
                                    }

                                    YButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: harea.containsMouse && !netRow.joined && !netRow.pending
                                        label: netRow.known ? "CONNECT" : "JOIN"
                                        onClicked: {
                                            if (netRow.known)
                                                netRow.modelData.connect();
                                            else
                                                root.pendingJoin = netRow.modelData.name;
                                        }
                                    }

                                    YButton {
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: netRow.pending
                                        label: "×"
                                        onClicked: root.pendingJoin = ""
                                    }
                                }

                                Row {
                                    visible: netRow.pending
                                    spacing: Theme.sp1

                                    YField {
                                        id: pskField

                                        width: 240
                                        placeholder: "passphrase…"
                                        echoMode: TextInput.Password
                                        Component.onCompleted: if (visible)
                                            forceFocus()

                                        onAccepted: {
                                            netRow.modelData.connectWithPsk(text);
                                            text = "";
                                            root.pendingJoin = "";
                                        }
                                    }

                                    YButton {
                                        label: "JOIN"
                                        tone: "acid"
                                        onClicked: {
                                            netRow.modelData.connectWithPsk(pskField.text);
                                            pskField.text = "";
                                            root.pendingJoin = "";
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: harea

                                anchors.fill: parent
                                anchors.bottomMargin: netRow.pending ? 44 : 0
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: mouse => {
                                    if (!netRow.pending)
                                        root.pendingJoin = netRow.modelData.name;
                                }
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "03"
                        label: "Wired"
                    }

                    Text {
                        width: parent.width
                        visible: Connectivity.wiredDev !== null
                        text: (Connectivity.wiredUp ? "link " + (Connectivity.wiredSpeed || "") + " · addr " + (Connectivity.wiredDev.address || "—") : "no link")
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                    }

                    Text {
                        width: parent.width
                        visible: Connectivity.wiredDev === null
                        text: "no wired hardware"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                    }

                    YSection {
                        width: parent.width
                        index: "04"
                        label: "VPN tunnels"
                        chip: Connectivity.vpnList.filter(v => v.active).length + " UP"
                    }

                    Repeater {
                        model: Connectivity.vpnList

                        delegate: YRow {
                            id: vpnRow

                            required property int index
                            required property var modelData

                            width: root.contentW
                            interactive: false
                            title: modelData.name
                            sub: modelData.type + (modelData.device.length > 0 && modelData.device !== "--" ? " · " + modelData.device : "")
                            note: modelData.active ? "UP" : ""

                            YButton {
                                anchors.verticalCenter: parent.verticalCenter
                                label: vpnRow.modelData.active ? "DOWN" : "UP"
                                tone: vpnRow.modelData.active ? "danger" : "acid"
                                onClicked: root.vpnToggle(vpnRow.modelData)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: Connectivity.vpnList.length === 0
                        text: "no wireguard/vpn profiles in networkmanager"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                    }

                    YSection {
                        width: parent.width
                        index: "05"
                        label: "DNS"
                    }

                    Text {
                        width: parent.width
                        text: Connectivity.dnsServers.length > 0 ? Connectivity.dnsServers : "—"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBody
                    }

                    Text {
                        width: parent.width
                        text: root.appliedDns.length > 0 ? "profile override: " + root.appliedDns : "profile override: none (dhcp)"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        font.letterSpacing: 1
                    }

                    Row {
                        visible: Connectivity.activeCon.length > 0
                        spacing: Theme.sp1

                        YField {
                            id: dnsField

                            width: 300
                            placeholder: "quick-set e.g. 1.1.1.1 9.9.9.9"
                        }

                        YButton {
                            label: "APPLY"
                            tone: "acid"
                            onClicked: {
                                if (dnsField.text.replace(/\s/g, "").length > 0) {
                                    root.applyDns(dnsField.text);
                                    dnsField.text = "";
                                }
                            }
                        }

                        YButton {
                            label: "REVERT DHCP"
                            onClicked: root.applyDns("")
                        }
                    }

                    Text {
                        width: parent.width
                        visible: Connectivity.activeCon.length === 0
                        text: "no active managed connection — dns quick-set unavailable"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                    }

                    Item {
                        width: 1
                        height: Theme.sp3
                    }
                }
            }

            YScroll {
                target: scroll
            }
        }
    }
}
