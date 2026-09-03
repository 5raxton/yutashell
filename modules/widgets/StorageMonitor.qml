pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// StorageMonitor (PH.06.2) — reads `df -h` via Process every 5 s and exposes
// per-mount usage. Consumers: StatCell tooltip, CC SYSTEM tab, Health.
Singleton {
    id: root

    property var mounts: []
    // [{ device, mount, type, size, used, avail, pct }]

    property int warnAt: 85
    property int critAt: 95

    signal mountWarned(string mount)
    signal mountCrited(string mount)

    readonly property bool anyWarn: {
        for (let i = 0; i < mounts.length; i++)
            if (mounts[i].pct >= warnAt)
                return true;
        return false;
    }

    readonly property bool anyCrit: {
        for (let i = 0; i < mounts.length; i++)
            if (mounts[i].pct >= critAt)
                return true;
        return false;
    }

    function mountPct(mountPoint) {
        for (let i = 0; i < mounts.length; i++)
            if (mounts[i].mount === mountPoint)
                return mounts[i].pct;
        return -1;
    }

    function _parse(text) {
        const lines = text.trim().split("\n");
        const out = [];
        for (let i = 1; i < lines.length; i++) {
            const f = lines[i].trim().split(/\s+/);
            if (f.length < 7)
                continue;
            const pct = parseInt(f[6]);
            if (isNaN(pct))
                continue;
            out.push({
                device: f[0],
                mount: f[1],
                type: f[2],
                size: f[3],
                used: f[4],
                avail: f[5],
                pct: pct
            });
            if (pct >= root.warnAt)
                root.mountWarned(f[1]);
            if (pct >= root.critAt)
                root.mountCrited(f[1]);
        }
        root.mounts = out;
    }

    Process {
        id: dfProc

        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            dfProc.command = ["df", "-h", "--output=source,target,fstype,size,used,avail,pcent", "-x", "tmpfs", "-x", "devtmpfs", "-x", "efivarfs"];
            dfProc.running = true;
        }
    }
}
