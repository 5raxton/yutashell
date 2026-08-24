pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// Brightness control — internal panels through brightnessctl (works for
// seat users via udev uaccess, no setuid needed) and external displays over
// DDC/CI (ddcutil). Both backends are probed independently; whatever answers
// lands in `displays`. When NEITHER backend exists the whole surface degrades
// to a no-op and consumers hide / report through Health.
//
// All writes are slow spawns — values are cached and writes coalesce through
// the debounce; never call these synchronously on hover.
Singleton {
    id: root

    // probed at boot: at least one display answered somewhere
    readonly property bool available: _probed && displays.length > 0

    property bool _probed: false
    property bool _ctlOk: false
    property bool _ddcOk: false

    readonly property var displays: _dispList // [{id,kind,label}] kind: "bl"|"ddc"
    property var _dispList: []

    on_DispListChanged: root.poll()

    // cached brightness percent (first display drives the readout)
    property int brightPct: 80

    // UI value moves instantly on drag; slow writes coalesce to the final
    // position — per-pixel calls would spawn a process storm
    function setBright(pct) {
        // IPC strings can be garbage — NaN must never reach a spawn command
        const n = parseInt(pct);
        if (isNaN(n))
            return;
        // 1..100: brightnessctl floors at its own minimum anyway, and a 0%
        // command on some panels reads as "panel off" — refuse the bottom stop
        const v = Math.max(1, Math.min(100, n));
        brightPct = v;
        if (!available)
            return;
        _pendingPct = v;
        writeDebounce.restart();
    }

    property int _pendingPct: -1

    Timer {
        id: writeDebounce

        interval: 150
        onTriggered: root._writeNow(root._pendingPct)
    }

    function _writeNow(v) {
        if (v < 0 || !root.available)
            return;
        const ops = [];
        for (let i = 0; i < root.displays.length; i++) {
            const d = root.displays[i];
            if (d.kind === "bl")
                ops.push("brightnessctl -q -d " + d.id + " set " + v + "%");
            else
                ops.push("ddcutil -d " + String(parseInt(d.id)) + " setvcp 10 " + v + " --noverify");
        }
        if (ops.length === 0)
            return;
        // one chained shell op — reusing a single Process per-display drops
        // every display after the first (running edge fires once); the follow-up
        // read runs from onExited so a failed link can't strand the readout
        setProc.command = ["sh", "-c", ops.join(" && ")];
        setProc.running = true;
    }

    function poll() {
        if (!root.available)
            return;
        if (_hasBl) {
            ctlGet.command = ["sh", "-c", "brightnessctl -m 2>/dev/null"];
            ctlGet.running = true;
        } else if (root.displays.length > 0) {
            getProc.command = ["sh", "-c", "ddcutil -d " + root.displays[0].id + " getvcp 10"];
            getProc.running = true;
        }
    }

    readonly property bool _hasBl: _dispList.some(d => d.kind === "bl")

    Component.onCompleted: {
        binProbe.command = ["sh", "-c", "command -v brightnessctl >/dev/null 2>&1 && echo ctl=yes || echo ctl=no; command -v ddcutil >/dev/null 2>&1 && echo ddc=yes || echo ddc=no"];
        binProbe.running = true;
    }

    Process {
        id: binProbe

        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                root._ctlOk = /ctl=yes/.test(out);
                root._ddcOk = /ddc=yes/.test(out);
                root._probed = true;
                if (root._ctlOk) {
                    detectBl.command = ["sh", "-c", "brightnessctl -m 2>/dev/null"];
                    detectBl.running = true;
                }
                if (root._ddcOk) {
                    detectProc.command = ["sh", "-c", "ddcutil detect --terse 2>/dev/null | grep -E '^Display [0-9]+' | sed 's/Display //'"];
                    detectProc.running = true;
                }
                if (!root._ctlOk && !root._ddcOk)
                    Health.report("brightness", "no brightness backend — install brightnessctl (internal) or ddcutil (external)");
                else
                    Health.clear("brightness");
            }
        }
    }

    Process {
        id: detectBl

        stdout: StdioCollector {
            onStreamFinished: {
                // machine-readable rows: name,class,current,percent,max
                const out = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const f = lines[i].split(",");
                    if (f.length >= 4 && f[1] === "backlight")
                        out.push({
                            "id": f[0],
                            "kind": "bl",
                            "label": f[0].toUpperCase()
                        });
                }
                root._merge(out);
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
                            "id": n,
                            "kind": "ddc",
                            "label": "DDC/" + n
                        });
                }
                root._merge(out);
            }
        }
    }

    // async probes land out of order — accumulate by kind instead of racing
    // two writers over the same array
    property var _blFound: null
    property var _ddcFound: null

    function _merge(list) {
        if (list.length === 0)
            return;
        if (list[0].kind === "bl")
            root._blFound = list;
        else
            root._ddcFound = list;
        const merged = (root._blFound ?? []).concat(root._ddcFound ?? []);
        if (merged.length === 0)
            return;
        root._dispList = merged;
        Health.clear("brightness");
    }

    Process {
        id: ctlGet

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const f = lines[i].split(",");
                    if (f.length >= 4 && f[1] === "backlight") {
                        const p = parseInt(f[3]);
                        if (!isNaN(p)) {
                            root.brightPct = Math.max(1, Math.min(100, p));
                            return;
                        }
                    }
                }
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

        onExited: root.poll()
    }

    Component.onDestruction: {
        Health.clear("brightness");
    }
}
