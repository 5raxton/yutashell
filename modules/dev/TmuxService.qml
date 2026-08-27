pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// TmuxService — reads tmux/zellij sessions (PH.04). 5s refresh.
// Exposes session list with name, window count, attached state.
Singleton {
    id: root

    readonly property bool available: _probed
    property bool _probed: false
    property bool _hasTmux: false
    property bool _hasZellij: false

    property var sessions: []
    property string status: ""
    property string activeSession: ""

    signal sessionsRefreshed()

    function refresh() {
        if (_hasTmux) {
            tmuxListProc.running = true;
        } else if (_hasZellij) {
            zellijListProc.running = true;
        }
    }

    function attachSession(name) {
        if (!name) return;
        // This sends the command to the user's active tmux via a background process
        tmuxAttachProc.command = ["sh", "-c", "tmux switch-client -t " + name + " 2>/dev/null || tmux attach -t " + name];
        tmuxAttachProc.running = true;
    }

    function newSession(name) {
        if (!name || !_hasTmux) return;
        tmuxNewProc.command = ["tmux", "new-session", "-d", "-s", name];
        tmuxNewProc.running = true;
        tmuxNewProc.runningChanged.connect(function() {
            if (!tmuxNewProc.running) root.refresh();
        });
    }

    function killSession(name) {
        if (!name || !_hasTmux) return;
        tmuxKillProc.command = ["tmux", "kill-session", "-t", name];
        tmuxKillProc.running = true;
        tmuxKillProc.runningChanged.connect(function() {
            if (!tmuxKillProc.running) root.refresh();
        });
    }

    function _parseTmux(text) {
        const lines = text.trim().split("\n");
        const sessions = [];
        for (let i = 0; i < lines.length; i++) {
            const parts = lines[i].split(":");
            if (parts.length >= 3) {
                sessions.push({
                    name: parts[0],
                    windows: parseInt(parts[1]) || 0,
                    attached: parts[2] === "1",
                    via: "tmux"
                });
            }
        }
        root.sessions = sessions;
        root.status = sessions.length + " sessions";
        root.activeSession = sessions.length > 0 ? sessions.find(s => s.attached)?.name ?? "" : "";
        root.sessionsRefreshed();
    }

    function _parseZellij(text) {
        const lines = text.trim().split("\n");
        const sessions = [];
        for (let i = 0; i < lines.length; i++) {
            const name = lines[i].trim();
            if (name.length > 0) {
                sessions.push({
                    name: name,
                    windows: 0,
                    attached: false,
                    via: "zellij"
                });
            }
        }
        root.sessions = sessions;
        root.status = sessions.length + " sessions (zellij)";
        root.sessionsRefreshed();
    }

    Component.onCompleted: {
        tmuxProbeProc.running = true;
    }

    Process {
        id: tmuxProbeProc
        command: ["sh", "-c", "which tmux 2>/dev/null; which zellij 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                const lines = this.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    if (lines[i].indexOf("tmux") >= 0) root._hasTmux = true;
                    if (lines[i].indexOf("zellij") >= 0) root._hasZellij = true;
                }
                if (root._hasTmux || root._hasZellij) root.refresh();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root._probed = true;
            }
        }
    }

    Process {
        id: tmuxListProc
        command: ["tmux", "list-sessions", "-F", "#{session_name}:#{session_windows}:#{session_attached}"]
        stdout: StdioCollector {
            onStreamFinished: root._parseTmux(this.text);
        }
        stderr: StdioCollector {
            onStreamFinished: {
                // no tmux server running
                if (this.text.indexOf("no server running") >= 0) {
                    root.sessions = [];
                    root.status = "no server";
                    root.sessionsRefreshed();
                }
            }
        }
    }

    Process {
        id: zellijListProc
        command: ["zellij", "list-sessions"]
        stdout: StdioCollector {
            onStreamFinished: root._parseZellij(this.text);
        }
        stderr: StdioCollector {}
    }

    Process {
        id: tmuxAttachProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: tmuxNewProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: tmuxKillProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Timer {
        interval: 5000
        running: root._hasTmux || root._hasZellij
        repeat: true
        onTriggered: root.refresh()
    }
}
