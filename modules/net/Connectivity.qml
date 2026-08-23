pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import Quickshell.Bluetooth
import QtQuick

// Shared connectivity model — ONE source for the bar segments, panels,
// connection toasts, and (future) control-center tabs. Device handles and
// nmcli-derived snapshots live here; consumers never re-probe.
Singleton {
    id: root

    // ---- device handles ---------------------------------------------------
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

    readonly property var btAdapter: Bluetooth.defaultAdapter

    // ---- derived state ----------------------------------------------------
    readonly property bool wifiOn: Networking.wifiEnabled && wifiDev !== null
    readonly property bool wifiHardBlocked: !Networking.wifiHardwareEnabled
    readonly property bool wiredUp: wiredDev !== null && wiredDev.hasLink
    readonly property string wiredSpeed: wiredUp && wiredDev.linkSpeed > 0 ? wiredDev.linkSpeed + " Mb/s" : ""
    readonly property bool btOn: btAdapter !== null && btAdapter.enabled
    readonly property bool airplane: !Networking.wifiEnabled && !btOn

    readonly property var activeWifi: {
        if (!wifiDev)
            return null;
        const nets = wifiDev.networks.values;
        for (let i = 0; i < nets.length; i++)
            if (nets[i].connected)
                return nets[i];
        return null;
    }

    readonly property int strength: activeWifi ? Math.max(0, Math.min(100, activeWifi.signalStrength)) : 0

    // primary link summary for chrome labels
    readonly property string linkLabel: wiredUp ? "WIRED" : activeWifi ? activeWifi.name.toUpperCase() : wifiOn ? "OPEN" : "OFFLINE"

    // arms the connection-change announcer (NetWatch is lazy-instantiated)
    readonly property bool _watchArmed: NetWatch._ready

    // ---- nmcli snapshots (VPN list + DNS) ---------------------------------
    property var vpnList: [] // [{name,type,device,active}]
    property string activeCon: "" // active ethernet/wifi profile name
    property string dnsServers: ""

    function _splitConLine(l) {
        // NAME:TYPE:DEVICE:ACTIVE — NAME may contain colons; split from the right
        const i1 = l.lastIndexOf(":");
        if (i1 < 0)
            return null;
        const active = l.slice(i1 + 1);
        const i2 = l.lastIndexOf(":", i1 - 1);
        if (i2 < 0)
            return null;
        const device = l.slice(i2 + 1, i1);
        const i3 = l.lastIndexOf(":", i2 - 1);
        if (i3 < 0)
            return null;
        return {
            "name": l.slice(0, i3),
            "type": l.slice(i3 + 1, i2),
            "device": device,
            "active": active === "yes"
        };
    }

    readonly property bool _probeRunning: conProbe.running || dnsProbe.running

    function refresh() {
        conProbe.command = ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,ACTIVE", "con", "show"];
        conProbe.running = true;
        dnsProbe.command = ["nmcli", "-t", "dev", "show"];
        dnsProbe.running = true;
    }

    function runNm(args) {
        followup.command = args;
        followup.running = true;
    }

    function vpnToggle(row) {
        runNm(["nmcli", "con", row.active ? "down" : "up", "id", row.name]);
    }

    Process {
        id: conProbe

        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").map(root._splitConLine).filter(r => r && (r.type === "vpn" || r.type === "wireguard"));
                root.vpnList = rows;
                const act = text.split("\n").map(root._splitConLine).filter(r => r && r.active && (r.type === "ethernet" || r.type === "wifi"));
                root.activeCon = act.length > 0 ? act[0].name : "";
            }
        }
    }

    Process {
        id: dnsProbe

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const m = /^IP4\.DNS\[\d+\]:(.+)$/.exec(lines[i].trim());
                    if (m && out.indexOf(m[1]) < 0)
                        out.push(m[1]);
                }
                root.dnsServers = out.join("  ·  ");
            }
        }
    }

    Process {
        id: followup

        onExited: root.refresh()
    }
}
