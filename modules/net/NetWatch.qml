pragma Singleton
import Quickshell
import Quickshell.Networking
import QtQuick
import qs.modules.notify

// Connection-change announcer. Watches the shared Connectivity model and
// routes transitions through the notification system (Notify.announce) —
// the machine narrating its own links. Debounced so panel operations and
// radio flaps don't spam.
Singleton {
    id: root

    // last announced link signature — only changes get spoken
    property string _lastSig: ""
    property bool _ready: false

    Component.onCompleted: {
        // warm the model, then arm after a beat so boot-time churn is silent
        Qt.callLater(() => {
            _armTimer.start();
        });
    }

    Timer {
        id: _armTimer

        interval: 3000
        onTriggered: {
            root._lastSig = root._sig();
            root._ready = true;
        }
    }

    function _sig() {
        const c = Connectivity;
        return [c.wiredUp ? "w" : "-", c.wifiOn ? "W" : "-", c.activeWifi ? c.activeWifi.name : "", c.btOn ? "B" : "-", Connectivity.vpnList.filter(v => v.active).map(v => v.name).join("+")].join("|");
    }

    function _speak() {
        const c = Connectivity;
        const parts = [];
        if (c.wiredUp)
            parts.push("wired up" + (c.wiredSpeed ? " · " + c.wiredSpeed : ""));
        if (c.activeWifi)
            parts.push("wifi · " + c.activeWifi.name);
        else if (c.wifiOn && !c.wiredUp)
            parts.push("wifi on · no network");
        if (!c.wifiOn)
            parts.push("wifi off");
        if (c.btOn)
            parts.push("bluetooth on");
        const vpns = Connectivity.vpnList.filter(v => v.active);
        if (vpns.length > 0)
            parts.push(vpns.map(v => v.name).join(", ") + " up");
        if (parts.length === 0)
            parts.push("no active links");
        Notify.announce("LINK " + (c.airplane ? "· AIRPLANE" : ""), parts.join("  ·  "), 1);
    }

    readonly property string _currentSig: _ready ? _sig() : _lastSig

    on_CurrentSigChanged: {
        if (!_ready || _currentSig === _lastSig)
            return;
        _debounce.restart();
    }

    Timer {
        id: _debounce

        interval: 900
        onTriggered: {
            if (!root._ready)
                return;
            const prev = root._lastSig;
            root._lastSig = root._currentSig;
            if (prev !== root._lastSig) {
                root._speak();
                // keep nmcli snapshots fresh after any transition
                Connectivity.refresh();
            }
        }
    }
}
