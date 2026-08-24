pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import "."

// SystemStats — the ONE sampling engine (PH.13). Owns every periodic read of
// /proc, /sys/class/hwmon and nvidia-smi; nothing else in the shell touches
// those files. Consumers bind to properties; the bar stats cluster, future
// control-center graphs, and threshold-driven alerting all drink from here.
//
// Two poll classes (intervals live in ShellState so PH.16 can stepper them):
//   FAST (2 s):  cpu aggregate + per-core, memory, network rates, load, uptime
//   SLOW (5 s):  disk IO, hwmon temps, GPU (nvidia-smi), battery
// Threshold signals fire once per crossing per kind so alert chrome can react
// without every consumer re-deriving the same math.
Singleton {
    id: root

    // ---- hostname (probed once) ----
    property string hostname: ""

    // ---- FAST class ----
    property real cpuPct: -1        // aggregate 0..100
    property var cpuCores: []       // [{ id: int, pct: real }]
    property real memPct: -1
    property real memUsed: -1       // bytes
    property real memTotal: -1      // bytes
    property real netDown: -1       // B/s
    property real netUp: -1         // B/s
    property real load1: -1
    property real uptime: -1        // seconds

    // ---- SLOW class ----
    property real diskRead: -1      // B/s
    property real diskWrite: -1     // B/s
    property real gpuUtil: -1       // %
    property real gpuTemp: -1       // °C
    property real gpuMemUsed: -1    // MB
    property bool gpuPresent: false
    property var temps: []          // [{ id, label, temp }]
    property bool batPresent: false
    property int batPct: -1
    property bool batCharging: false

    // ---- thresholds (signals fire on crossing) ----
    signal warnRaised(string kind)
    signal critRaised(string kind)

    property var _lastLevel: ({})   // kind -> "ok"|"warn"|"crit"

    // configurable limits (PH.16 steppers edit these)
    readonly property int cpuWarn: 85
    readonly property int cpuCrit: 95
    readonly property int tempWarn: 80
    readonly property int tempCrit: 90
    readonly property int memWarn: 90
    readonly property int batWarn: 20
    readonly property int batCrit: 10

    // ---- units/locale formatters (PH.13 spec; consumed everywhere) ----
    function fmtRate(v) {
        if (v < 0)
            return "--";
        if (v < 1024)
            return Math.round(v) + "B";
        if (v < 1048576)
            return (v / 1024).toFixed(v < 10240 ? 1 : 0) + "K";
        if (v < 1073741824)
            return (v / 1048576).toFixed(v < 10485760 ? 1 : 0) + "M";
        return (v / 1073741824).toFixed(1) + "G";
    }

    function fmtBytes(v) {
        if (v < 0)
            return "--";
        if (v < 1024)
            return Math.round(v) + " B";
        if (v < 1048576)
            return (v / 1024).toFixed(v < 10240 ? 1 : 0) + " KB";
        if (v < 1073741824)
            return (v / 1048576).toFixed(v < 10485760 ? 1 : 0) + " MB";
        return (v / 1073741824).toFixed(2) + " GB";
    }

    // 12h/24h clock string; seconds optional
    function fmtTime(d, secs) {
        const h24 = d.getHours();
        let h = h24;
        let ap = "";
        if (!ShellState.clock24h) {
            ap = h24 >= 12 ? " PM" : " AM";
            h = h24 % 12;
            if (h === 0)
                h = 12;
        }
        const mm = String(d.getMinutes()).padStart(2, "0");
        const ss = secs ? ":" + String(d.getSeconds()).padStart(2, "0") : "";
        return String(h).padStart(2, "0") + ":" + mm + ss + ap;
    }

    function fmtTemp(v) {
        return v < 0 ? "--" : Math.round(v) + "°";
    }

    // ---- thresholds -----------------------------------------------------
    function _threshold(kind, value, warn, crit) {
        let lvl = "ok";
        if (value >= crit)
            lvl = "crit";
        else if (value >= warn)
            lvl = "warn";
        const prev = root._lastLevel[kind] ?? "ok";
        if (lvl === prev)
            return;
        root._lastLevel[kind] = lvl;
        if (lvl === "crit")
            root.critRaised(kind);
        else if (lvl === "warn")
            root.warnRaised(kind);
    }

    // ---- /proc sampling ---------------------------------------------------
    property var _prevCpu: []       // per-core + aggregate [{total, idle}]
    property double _prevNetRx: -1
    property double _prevNetTx: -1
    property double _prevDiskR: -1
    property double _prevDiskW: -1
    property double _prevNetStamp: 0
    property double _prevDiskStamp: 0

    function _sampleCpu(t) {
        const lines = t.trim().split("\n");
        const cores = [];
        let aggTotal = 0;
        let aggIdle = 0;
        let prevAgg = root._prevCpu.length > 0 ? root._prevCpu[0] : null;
        for (let i = 0; i < lines.length; i++) {
            const ln = lines[i].trim();
            if (!ln.startsWith("cpu"))
                continue;
            const f = ln.split(/\s+/);
            const label = f[0];           // "cpu" | "cpu0" | ...
            const nums = f.slice(1, 8).map(Number);
            const total = nums.reduce((a, b) => a + b, 0);
            const idle = (nums[3] || 0) + (nums[4] || 0);
            if (label === "cpu") {
                aggTotal = total;
                aggIdle = idle;
                if (prevAgg && total > prevAgg.total)
                    root.cpuPct = Math.max(0, Math.min(100, Math.round((1 - (idle - prevAgg.idle) / (total - prevAgg.total)) * 100)));
                continue;
            }
            const idx = parseInt(label.slice(3), 10);
            if (isNaN(idx))
                continue;
            const prev = root._prevCpu[idx + 1] ?? null;
            let pct = -1;
            if (prev && total > prev.total)
                pct = Math.max(0, Math.min(100, Math.round((1 - (idle - prev.idle) / (total - prev.total)) * 100)));
            cores.push({
                id: idx,
                pct: pct
            });
            root._prevCpu[idx + 1] = {
                total: total,
                idle: idle
            };
        }
        root._prevCpu[0] = {
            total: aggTotal,
            idle: aggIdle
        };
        if (cores.length > 0)
            root.cpuCores = cores;
        if (root.cpuPct >= 0)
            root._threshold("cpu", root.cpuPct, root.cpuWarn, root.cpuCrit);
    }

    function _sampleMem(t) {
        const total = Number((t.match(/MemTotal:\s+(\d+)/) || [])[1]);
        const avail = Number((t.match(/MemAvailable:\s+(\d+)/) || [])[1]);
        if (total > 0 && !isNaN(avail)) {
            root.memTotal = total * 1024;
            root.memUsed = (total - avail) * 1024;
            root.memPct = Math.round((1 - avail / total) * 100);
            root._threshold("mem", root.memPct, root.memWarn, 100);
        }
    }

    function _sampleNet(t) {
        let rx = 0;
        let tx = 0;
        const lines = t.split("\n");
        for (let i = 2; i < lines.length; i++) {
            const ln = lines[i];
            const idx = ln.indexOf(":");
            if (idx < 0)
                continue;
            if (ln.slice(0, idx).trim() === "lo")
                continue;
            const f = ln.slice(idx + 1).trim().split(/\s+/).map(Number);
            rx += f[0] || 0;
            tx += f[8] || 0;
        }
        const now = Date.now();
        if (root._prevNetRx >= 0) {
            const dt = (now - root._prevNetStamp) / 1000;
            if (dt > 0) {
                root.netDown = Math.max(0, (rx - root._prevNetRx) / dt);
                root.netUp = Math.max(0, (tx - root._prevNetTx) / dt);
            }
        }
        root._prevNetRx = rx;
        root._prevNetTx = tx;
        root._prevNetStamp = now;
    }

    function _sampleDisk(t) {
        let r = 0;
        let w = 0;
        for (const ln of t.trim().split("\n")) {
            const f = ln.trim().split(/\s+/).map(Number);
            if (f.length < 6 || !f[0])
                continue;
            // fields: major minor name reads ... sectors_read ... sectors_written
            if (f[5] !== undefined)
                r += f[5] * 512;
            if (f[9] !== undefined)
                w += f[9] * 512;
        }
        const now = Date.now();
        if (root._prevDiskR >= 0) {
            const dt = (now - root._prevDiskStamp) / 1000;
            if (dt > 0) {
                root.diskRead = Math.max(0, (r - root._prevDiskR) / dt);
                root.diskWrite = Math.max(0, (w - root._prevDiskW) / dt);
            }
        }
        root._prevDiskR = r;
        root._prevDiskW = w;
        root._prevDiskStamp = now;
    }

    function _sampleLoad(t) {
        const f = t.trim().split(/\s+/);
        const v = parseFloat(f[0]);
        if (!isNaN(v))
            root.load1 = v;
    }

    function _sampleUptime(t) {
        const f = t.trim().split(/\s+/);
        const v = parseFloat(f[0]);
        if (!isNaN(v))
            root.uptime = v;
    }

    function _sampleTemp(t) {
        // "LABEL value\n" lines, one per discovered sensor (Celsius)
        const out = [];
        const lines = t.trim().split("\n");
        const seen = {};
        for (let i = 0; i < lines.length; i++) {
            const f = lines[i].trim().split(/\s+/);
            if (f.length < 2)
                continue;
            const label = f[0];
            const v = parseFloat(f[1]);
            if (isNaN(v))
                continue;
            // disambiguate duplicate labels (nvme ×2, spd5118 ×2)
            seen[label] = (seen[label] ?? 0) + 1;
            const id = seen[label] > 1 ? label + seen[label] : label;
            out.push({
                id: id,
                label: label,
                temp: Math.round(v)
            });
        }
        // same readings → keep array identity so sensor-row delegates don't
        // rebuild every SLOW tick while the temps tab is open
        const old = root.temps;
        if (old.length === out.length) {
            let same = true;
            for (let j = 0; j < out.length; j++) {
                if (!old[j] || old[j].id !== out[j].id || old[j].temp !== out[j].temp) {
                    same = false;
                    break;
                }
            }
            if (same)
                return;
        }
        root.temps = out;
        // hottest temp drives the threshold
        let hot = -1;
        for (const s of out)
            if (s.temp > hot)
                hot = s.temp;
        if (hot >= 0)
            root._threshold("temp", hot, root.tempWarn, root.tempCrit);
    }

    // ---- FileViews -------------------------------------------------------
    FileView {
        id: cpuFile
        path: "/proc/stat"
        watchChanges: false
        printErrors: false
        onLoaded: root._sampleCpu(cpuFile.text())
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        watchChanges: false
        printErrors: false
        onLoaded: root._sampleMem(memFile.text())
    }

    FileView {
        id: netFile
        path: "/proc/net/dev"
        watchChanges: false
        printErrors: false
        onLoaded: root._sampleNet(netFile.text())
    }

    FileView {
        id: loadFile
        path: "/proc/loadavg"
        watchChanges: false
        printErrors: false
        onLoaded: root._sampleLoad(loadFile.text())
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        watchChanges: false
        printErrors: false
        onLoaded: root._sampleUptime(uptimeFile.text())
    }

    FileView {
        id: diskFile
        path: "/proc/diskstats"
        watchChanges: false
        printErrors: false
        onLoaded: root._sampleDisk(diskFile.text())
    }

    FileView {
        id: hostnameFile
        path: "/proc/sys/kernel/hostname"
        watchChanges: false
        printErrors: false
        onLoaded: {
            const h = hostnameFile.text().trim();
            if (h.length > 0)
                root.hostname = h;
        }
    }

    // battery (sysfs; absent on this desktop box — reported honestly)
    FileView {
        id: batCapFile
        path: "/sys/class/power_supply/BAT1/capacity"
        watchChanges: false
        printErrors: false
        onLoaded: {
            root.batPresent = true;
            const v = parseInt(batCapFile.text());
            if (!isNaN(v))
                root.batPct = v;
            root._threshold("bat", root.batPct, root.batWarn, root.batCrit);
        }
        onLoadFailed: {
            if (!root._batFallback) {
                root._batFallback = true;
                batCapFile.path = "/sys/class/power_supply/BAT0/capacity";
                batStatFile.path = "/sys/class/power_supply/BAT0/status";
            } else {
                root.batPresent = false;
                root.batPct = -1;
            }
        }
    }

    property bool _batFallback: false

    FileView {
        id: batStatFile
        path: "/sys/class/power_supply/BAT1/status"
        watchChanges: false
        printErrors: false
        onLoaded: {
            const s = batStatFile.text().trim();
            root.batCharging = s.startsWith("Charging") || s.startsWith("Full");
        }
    }

    // ---- Process probes (hwmon temps + nvidia-smi) -----------------------
    Process {
        id: tempProc
        stdout: StdioCollector {
            onStreamFinished: root._sampleTemp(this.text)
        }
        stderr: StdioCollector {}
    }

    Process {
        id: gpuProc
        stdout: StdioCollector {
            onStreamFinished: {
                const f = this.text.trim().split(",").map(s => s.trim());
                if (f.length < 4)
                    return;
                const util = parseFloat(f[0]);
                const temp = parseFloat(f[1]);
                const mem = parseFloat(f[2]);
                if (!isNaN(util))
                    root.gpuUtil = Math.round(util);
                if (!isNaN(temp))
                    root.gpuTemp = Math.round(temp);
                if (!isNaN(mem))
                    root.gpuMemUsed = Math.round(mem);
                root.gpuPresent = !isNaN(util);
                if (root.gpuPresent)
                    root._gpuMiss = 0;
                if (root.gpuTemp >= 0)
                    root._threshold("gpu", root.gpuTemp, root.tempWarn, root.tempCrit);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                // nvidia-smi absent or failed — degrade cleanly
                if (this.text.trim().length > 0)
                    root.gpuPresent = false;
            }
        }
    }

    // FAST timer
    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            cpuFile.reload();
            memFile.reload();
            netFile.reload();
            loadFile.reload();
            uptimeFile.reload();
        }
    }

    // SLOW timer
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            diskFile.reload();
            if (root.batPresent || !root._batFallback) {
                batCapFile.reload();
                batStatFile.reload();
            }
            // hwmon: discover + read temps in one shot
            tempProc.command = ["sh", "-c",
                "for h in /sys/class/hwmon/hwmon*; do n=$(cat \"$h/name\" 2>/dev/null); case \"$n\" in coretemp) t=$(cat \"$h/temp1_input\" 2>/dev/null); [ -n \"$t\" ] && echo \"CPU $((t/1000))\";; nvme) t=$(cat \"$h/temp1_input\" 2>/dev/null); [ -n \"$t\" ] && echo \"NVME $((t/1000))\";; spd5118) t=$(cat \"$h/temp1_input\" 2>/dev/null); [ -n \"$t\" ] && echo \"RAM $((t/1000))\";; acpitz) t=$(cat \"$h/temp1_input\" 2>/dev/null); [ -n \"$t\" ] && echo \"CHIP $((t/1000))\";; esac; done"];
            tempProc.running = true;
            // GPU: one batched nvidia-smi query — but once absence is proven,
            // stop paying a failed fork/exec every tick forever. A missing
            // binary never reaches `exited`, so count silent ticks instead:
            // three strikes while gpuPresent stays false ⇒ dead until success.
            if (!root._gpuDead) {
                if (root.gpuPresent) {
                    root._gpuMiss = 0;
                } else {
                    root._gpuMiss++;
                    if (root._gpuMiss >= 3)
                        root._gpuDead = true;
                }
            }
            if (!root._gpuDead) {
                gpuProc.command = ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,power.draw", "--format=csv,noheader,nounits"];
                gpuProc.running = true;
            }
        }
    }

    // strike counter + latch for absent nvidia-smi (reset on any success)
    property int _gpuMiss: 0
    property bool _gpuDead: false

    Component.onCompleted: hostnameFile.reload()
}
