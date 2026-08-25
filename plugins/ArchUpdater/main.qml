import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// Arch Updater daemon — scans pacman-contrib, AUR (paru/yay), and Flatpak for
// available updates. Exposes structured data for BarWidget and UpdatePanel.
Item {
    id: root

    property string pluginId: ""

    property bool checking: false
    property date lastCheck: new Date(0)

    property var officialPkgs: []
    property var aurPkgs: []
    property var flatpakPkgs: []

    readonly property int officialCount: officialPkgs.length
    readonly property int aurCount: aurPkgs.length
    readonly property int flatpakCount: flatpakPkgs.length
    readonly property int updateCount: officialCount + aurCount + flatpakCount

    // AUR helper: paru preferred, yay fallback
    property string _aurHelper: ""
    property bool _aurProbed: false
    property bool _checkupdatesAvailable: false
    property bool _flatpakAvailable: false

    // ---- settings from plugin state ----
    readonly property int interval: {
        const v = PluginService.loadPluginData(root.pluginId, "interval", 60);
        return Math.max(5, Number(v) || 60);
    }

    readonly property bool autoCheck: PluginService.loadPluginData(root.pluginId, "autoCheck", true)

    function refresh() {
        root.checking = true;
        root._stage = 0;
        root.officialPkgs = [];
        root.aurPkgs = [];
        root.flatpakPkgs = [];
        if (root._checkupdatesAvailable)
            checkupdatesProc.running = true;
        else
            root._probeAur();
    }

    function updateAll() {
        updateProc.running = true;
    }

    // ---- internal stage machine ----
    // 0 = idle, 1 = checkupdates done, 2 = AUR done, 3 = all done
    property int _stage: 0

    function _probeAur() {
        root._stage = 1;
        if (root._aurHelper.length > 0) {
            aurProc.command = ["sh", "-c", root._aurHelper + " -Qu --aur 2>/dev/null"];
            aurProc.running = true;
        } else {
            aurProbe.running = true;
        }
    }

    function _probeFlatpak() {
        root._stage = 2;
        if (root._flatpakAvailable) {
            flatpakProc.running = true;
        } else {
            root._finishCheck();
        }
    }

    function _finishCheck() {
        root.checking = false;
        root.lastCheck = new Date();
        root._stage = 0;
    }

    function _parseUpdateLine(line) {
        const m = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)$/);
        if (m)
            return { name: m[1], from: m[2], to: m[3] };
        return { name: line, from: "", to: "" };
    }

    // ---- boot probes ----
    Component.onCompleted: {
        checkupdatesProbe.running = true;
        flatpakProbe.running = true;
    }

    Process {
        id: checkupdatesProbe

        command: ["sh", "-c", "command -v checkupdates >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._checkupdatesAvailable = text.trim() === "yes";
                if (root._checkupdatesAvailable && root.autoCheck)
                    root.refresh();
            }
        }
    }

    Process {
        id: flatpakProbe

        command: ["sh", "-c", "command -v flatpak >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: root._flatpakAvailable = text.trim() === "yes"
        }
    }

    Process {
        id: aurProbe

        command: ["sh", "-c", "command -v paru >/dev/null 2>&1 && echo paru || (command -v yay >/dev/null 2>&1 && echo yay || echo none)"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                root._aurProbed = true;
                root._aurHelper = t !== "none" ? t : "";
                if (root.autoCheck)
                    root.refresh();
            }
        }
    }

    // ---- check processes ----
    Process {
        id: checkupdatesProc

        command: ["sh", "-c", "checkupdates 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
                root.officialPkgs = lines.map(l => root._parseUpdateLine(l));
                root._probeAur();
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            if (code !== 0) {
                root.officialPkgs = [];
                root._probeAur();
            }
        }
    }

    Process {
        id: aurProc

        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
                root.aurPkgs = lines.map(l => root._parseUpdateLine(l));
                root._probeFlatpak();
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            if (code !== 0) {
                root.aurPkgs = [];
                root._probeFlatpak();
            }
        }
    }

    Process {
        id: flatpakProc

        command: ["sh", "-c", "flatpak update --dry-run 2>/dev/null | grep '^  '"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().length > 0 ? text.trim().split("\n") : [];
                root.flatpakPkgs = lines.map(l => root._parseUpdateLine(l));
                root._finishCheck();
            }
        }
        stderr: StdioCollector {}
        onExited: code => {
            if (code !== 0) {
                root.flatpakPkgs = [];
                root._finishCheck();
            }
        }
    }

    // ---- update process ----
    Process {
        id: updateProc

        command: ["sh", "-c", "pkexec bash -c 'pacman -Syu --noconfirm 2>&1; " + (root._aurHelper.length > 0 ? root._aurHelper + " -Syu --noconfirm 2>&1; " : "") + "flatpak update -y 2>&1'"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            if (code === 0)
                root.refresh();
        }
    }

    // ---- periodic check ----
    Timer {
        id: checkTimer

        interval: root.interval * 60000
        running: root.autoCheck && root._checkupdatesAvailable
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }
}
