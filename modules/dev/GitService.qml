pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.modules.common

// GitService — reads git status from the focused terminal's CWD (PH.04).
// Runs `git status --porcelain=v2 --branch` on a 3s timer gated on terminal
// focus. Exposes branch, ahead/behind, dirty/staged/untracked counts, and
// the active repo path.
Singleton {
    id: root

    readonly property bool available: _probed
    property bool _probed: false
    property bool _hasGit: false

    // active repo state
    property string cwd: ""
    property string branch: ""
    property int ahead: 0
    property int behind: 0
    property int dirty: 0
    property int staged: 0
    property int untracked: 0
    property bool isRepo: false
    property string remoteUrl: ""

    // focused terminal CWD tracking
    property string _focusedApp: ""
    property string _focusedTitle: ""

    signal statusRefreshed()

    function refresh() {
        if (!_hasGit || root.cwd.length === 0) return;
        gitStatusProc.command = ["git", "-C", root.cwd, "status", "--porcelain=v2", "--branch"];
        gitStatusProc.running = true;
    }

    function _parseStatus(text) {
        const lines = text.split("\n");
        let branch = "", ahead = 0, behind = 0;
        let dirty = 0, staged = 0, untracked = 0;

        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.startsWith("# branch.oid ")) {
                // commit hash — skip
            } else if (line.startsWith("# branch.head ")) {
                branch = line.slice(14);
            } else if (line.startsWith("# branch.ab ")) {
                const parts = line.slice(12).split(" ");
                ahead = parseInt(parts[0]) || 0;
                behind = parseInt(parts[1]) || 0;
            } else if (line.startsWith("1 ")) {
                staged++;
            } else if (line.startsWith("2 ")) {
                dirty++;
            } else if (line.startsWith("? ")) {
                untracked++;
            }
        }

        root.branch = branch;
        root.ahead = ahead;
        root.behind = behind;
        root.dirty = dirty;
        root.staged = staged;
        root.untracked = untracked;
        root.isRepo = true;
        root.statusRefreshed();
    }

    function _tryDetectCwd() {
        const toplevels = Hyprland.toplevels?.values ?? [];
        for (let i = 0; i < toplevels.length; i++) {
            const tl = toplevels[i];
            const appId = tl.wayland?.appId || tl.lastIpcObject?.class || "";
            const title = tl.lastIpcObject?.title || "";
            const isTerminal = ["alacritty", "kitty", "foot", "wezterm", "ghostty", "tilix"].indexOf(appId) >= 0;
            if (isTerminal) {
                // Try to extract CWD from terminal title (many terminals show cwd in title)
                const cwdMatch = title.match(/~\/([^\s]*)/);
                if (cwdMatch) {
                    const home = Quickshell.env("HOME") ?? "";
                    root.cwd = home + "/" + cwdMatch[1];
                    root._focusedApp = appId;
                    root._focusedTitle = title;
                    return;
                }
                // fallback: try /proc/<pid>/cwd via the window's pid
                if (tl.pid > 0) {
                    pidReadProc.command = ["readlink", "/proc/" + tl.pid + "/cwd"];
                    pidReadProc.running = true;
                    return;
                }
            }
        }
    }

    // boot probe
    Component.onCompleted: {
        gitProbeProc.running = true;
    }

    Process {
        id: gitProbeProc
        command: ["which", "git"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._hasGit = this.text.trim().length > 0;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._hasGit = false;
            }
        }
    }

    Process {
        id: gitStatusProc
        stdout: StdioCollector {
            onStreamFinished: {
                root._parseStatus(this.text);
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: pidReadProc
        stdout: StdioCollector {
            onStreamFinished: {
                const path = this.text.trim();
                if (path.length > 0) {
                    root.cwd = path;
                    root.refresh();
                }
            }
        }
        stderr: StdioCollector {}
    }

    // refresh when focused window changes
    Connections {
        target: Hyprland
        function onRawEvent(evt) {
            if (evt.name === "activewindow") {
                root._tryDetectCwd();
            }
        }
    }

    // periodic refresh while we have a CWD
    Timer {
        interval: 3000
        running: root.cwd.length > 0 && root._hasGit
        repeat: true
        onTriggered: root.refresh()
    }
}
