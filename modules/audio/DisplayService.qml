pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// External-display brightness over ddcutil. This box has no internal
// backlight; when ddcutil is absent the whole surface degrades to a no-op
// and every consumer hides. ddcutil is SLOW — values are cached and writes
// are fire-and-forget; never call it synchronously on hover.
Singleton {
    id: root

    // probed at boot: binary present AND at least one display answered
    readonly property bool available: _probed && _ddcOk && displays.length > 0

    property bool _ddcOk: false
    property bool _probed: false
    readonly property var displays: _dispList // [{idx,name}]
    property var _dispList: []

    // cached brightness percent (first display drives the readout)
    property int brightPct: 80

    on_DispListChanged: root.poll()

    function setBright(pct) {
        const v = Math.max(0, Math.min(100, pct));
        brightPct = v;
        if (!available)
            return;
        // one chained shell op — reusing a single Process per-display would
        // drop every display after the first (running edge fires once)
        const ops = [];
        for (let i = 0; i < displays.length; i++)
            ops.push("ddcutil -d " + String(parseInt(displays[i].idx)) + " setvcp 10 " + v + " --noverify");
        setProc.command = ["sh", "-c", ops.join(" && ")];
        setProc.running = true;
    }

    function poll() {
        if (!available)
            return;
        getProc.command = ["sh", "-c", "ddcutil -d " + displays[0].idx + " getvcp 10"];
        getProc.running = true;
    }

    Component.onCompleted: {
        binProbe.command = ["sh", "-c", "command -v ddcutil >/dev/null 2>&1 && echo yes || echo no"];
        binProbe.running = true;
        poll();
    }

    Process {
        id: binProbe

        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._ddcOk = text.trim() === "yes";
                if (!root._ddcOk)
                    Health.report("ddcutil", "monitor brightness unavailable (install ddcutil)");
                else
                    Health.clear("ddcutil");
                if (root._ddcOk) {
                    detectProc.command = ["sh", "-c", "ddcutil detect --terse 2>/dev/null | grep -E '^Display [0-9]+' | sed 's/Display //'"];
                    detectProc.running = true;
                }
            }
        }
    }

    Process {
        id: detectProc

        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const n = lines[i].trim();
                    if (/^\d+$/.test(n))
                        out.push({
                            "idx": parseInt(n),
                            "name": "DDC/" + n
                        });
                }
                root._dispList = out;
            }
        }
    }

    Process {
        id: getProc

        stdout: StdioCollector {
            onStreamFinished: {
                const m = /current\s*=\s*(\d+)/i.exec(text);
                if (m)
                    root.brightPct = Math.max(0, Math.min(100, parseInt(m[1])));
            }
        }
    }

    Process {
        id: setProc
    }
}
