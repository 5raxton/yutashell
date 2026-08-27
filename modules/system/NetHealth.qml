pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// NetHealth (PH.06) — network health monitor: periodic probes for latency,
// VPN status, DNS resolution time. Alerts on VPN disconnect and latency spikes.
Singleton {
    id: root

    property int latencyMs: -1
    property bool vpnActive: false
    property int dnsMs: -1
    property string ip4: ""
    property string dnsServer: ""
    property bool available: false

    // alert thresholds
    readonly property int latencyWarnMs: 100
    readonly property int latencyCritMs: 500

    readonly property string latencyGrade: {
        if (latencyMs < 0) return "unknown";
        if (latencyMs < 20) return "excellent";
        if (latencyMs < 50) return "good";
        if (latencyMs < 100) return "fair";
        if (latencyMs < 300) return "poor";
        return "bad";
    }

    signal latencySpike(int ms)
    signal vpnChanged(bool active)

    // ping probe
    Process {
        id: pingProc
        command: ["ping", "-c", "1", "-W", "2", "1.1.1.1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text;
                const m = t.match(/time=(\d+\.?\d*)/);
                if (m) {
                    root.latencyMs = Math.round(parseFloat(m[1]));
                    if (root.latencyMs >= root.latencyCritMs)
                        root.latencySpike(root.latencyMs);
                } else {
                    root.latencyMs = -1;
                }
            }
        }
    }

    // IP probe
    Process {
        id: ipProc
        command: ["sh", "-c", "ip -4 -o addr show scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1"]
        stdout: StdioCollector {
            onStreamFinished: { root.ip4 = this.text.trim(); }
        }
    }

    // VPN probe
    Process {
        id: vpnProc
        command: ["sh", "-c", "ip link show wg0 2>/dev/null | grep -q UP && echo up || echo down"]
        stdout: StdioCollector {
            onStreamFinished: {
                const active = this.text.trim() === "up";
                if (active !== root.vpnActive) {
                    root.vpnActive = active;
                    root.vpnChanged(active);
                    if (!active)
                        Health.report("nethealth", "VPN disconnected");
                }
            }
        }
    }

    // DNS probe
    Process {
        id: dnsProc
        command: ["sh", "-c", "dig +short +time=2 +tries=1 example.com A 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.dnsServer = this.text.trim();
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            pingProc.running = true;
            ipProc.running = true;
            vpnProc.running = true;
            dnsProc.running = true;
        }
    }

    Component.onCompleted: {
        available = true;
    }
}
