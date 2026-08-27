pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common
import qs.modules.notify
import qs.modules.audio

// SnapshotService (PH.07) — save and restore entire desktop states: open
// windows (via hyprctl), wallpaper, bar layout, DND, night light. Snapshots
// persist as JSON in ~/.local/state/yutashell/snapshots/<name>.json.
Singleton {
    id: root

    property var snapshots: []
    readonly property string _dir: (Quickshell.env("HOME") ?? "") + "/.local/state/yutashell/snapshots"

    signal saved(string name)
    signal restored(string name)

    property string _pendingName: ""
    property string _pendingJson: ""
    property string _pendingTarget: ""
    readonly property string _helperPath: (Quickshell.env("HOME") ?? "") + "/.local/state/yutashell/snap-write-helper.py"

    function save(name) {
        _pendingName = name;
        _capture.running = true;
    }

    Process {
        id: _capture
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                let clients = [];
                try { clients = JSON.parse(this.text); } catch (e) {}
                if (!Array.isArray(clients)) clients = [];

                const snap = {
                    name: root._pendingName,
                    timestamp: Date.now(),
                    wallpaper: Wallpaper.current,
                    barSegments: ShellState.barSegments,
                    dnd: Notify.dnd,
                    nightLight: NightLight.active,
                    windows: clients.map(function(c) {
                        return {
                            appId: c.class ?? "",
                            title: c.title ?? "",
                            workspace: c.workspace?.id ?? 0,
                            floating: c.floating ?? false
                        };
                    })
                };

                const safe = root._safeName(root._pendingName);
                root._pendingTarget = root._dir + "/" + safe + ".json";
                root._pendingJson = JSON.stringify(snap, null, 2);
                _writeTimer.start();
            }
        }
    }

    Timer {
        id: _writeTimer
        interval: 200
        onTriggered: {
            _writeProc.command = ["python3", root._helperPath, root._pendingTarget, root._pendingJson];
            _writeRunTimer.start();
        }
    }

    Timer {
        id: _writeRunTimer
        interval: 100
        onTriggered: {
            _writeProc.running = true;
            _refreshTimer.start();
        }
    }

    Process {
        id: _writeProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Timer {
        id: _refreshTimer
        interval: 500
        onTriggered: {
            root._refreshList();
            root.saved(root._pendingName);
            Notify.announce("SNAPSHOT", "Saved: " + root._pendingName, 2);
        }
    }

    function restore(name) {
        const path = _dir + "/" + _safeName(name) + ".json";
        _restoreView._name = name;
        _restoreView.path = path;
        _restoreView.reload();
    }

    FileView {
        id: _restoreView
        property string _name: ""
        onLoaded: {
            let snap;
            try { snap = JSON.parse(this.text()); } catch (e) {
                Notify.announce("SNAPSHOT", "Failed to read: " + _restoreView._name, 4);
                return;
            }
            if (snap.wallpaper) Wallpaper.apply(snap.wallpaper);
            if (snap.barSegments) ShellState.set("barSegments", snap.barSegments);
            if (typeof snap.dnd === "boolean") Notify.setDnd(snap.dnd);
            if (Array.isArray(snap.windows)) {
                for (let i = 0; i < snap.windows.length; i++) {
                    const w = snap.windows[i];
                    if (w.appId) {
                        const entry = DesktopEntries.heuristicLookup(w.appId);
                        if (entry) entry.execute();
                    }
                }
            }
            root.restored(_restoreView._name);
            Notify.announce("SNAPSHOT", "Restored: " + _restoreView._name, 2);
        }
    }

    function deleteSnapshot(name) {
        const path = _dir + "/" + _safeName(name) + ".json";
        _deleteProc.command = ["rm", "-f", path];
        _deleteProc.running = true;
        _delRefresh.start();
    }

    Process {
        id: _deleteProc
        stdout: StdioCollector {}
    }

    Timer {
        id: _delRefresh
        interval: 200
        onTriggered: root._refreshList()
    }

    function list(): var { return snapshots; }

    function _refreshList() { _listDir.running = true; }

    Process {
        id: _listDir
        command: ["sh", "-c", "ls -1 " + root._dir + "/*.json 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = this.text.trim();
                if (!raw || raw.length === 0) { root.snapshots = []; return; }
                const files = raw.split("\n").filter(function(l) { return l.trim().length > 0; });
                root._loadFiles = files;
                root._loadIdx = 0;
                root._loadAcc = [];
                root._loadNext();
            }
        }
    }

    property var _loadFiles: []
    property int _loadIdx: 0
    property var _loadAcc: []

    function _loadNext() {
        if (_loadIdx >= _loadFiles.length) {
            _loadAcc.sort(function(a, b) { return b.timestamp - a.timestamp; });
            root.snapshots = _loadAcc;
            return;
        }
        _metaView.path = _loadFiles[_loadIdx];
        _metaView.reload();
    }

    FileView {
        id: _metaView
        onLoaded: {
            try {
                const s = JSON.parse(this.text());
                root._loadAcc.push({
                    name: s.name ?? "unknown",
                    timestamp: s.timestamp ?? 0,
                    windowCount: Array.isArray(s.windows) ? s.windows.length : 0,
                    wallpaper: s.wallpaper ?? "",
                    file: _metaView.path
                });
            } catch (e) {}
            root._loadIdx++;
            root._loadNext();
        }
    }

    function _safeName(n) {
        return (n ?? "unnamed").replace(/[^a-zA-Z0-9_-]/g, "_").substring(0, 64);
    }

    Component.onCompleted: {
        mkdirProc.running = true;
        _bootTimer.start();
    }

    Timer {
        id: _bootTimer
        interval: 500
        onTriggered: {
            _helperWrite.setText('import sys, json\nwith open(sys.argv[1], "w") as f:\n    f.write(sys.argv[2])\n');
            _chmodTimer.start();
        }
    }

    Timer {
        id: _chmodTimer
        interval: 200
        onTriggered: {
            _chmodProc.running = true;
            _refreshList();
        }
    }

    FileView {
        id: _helperWrite
        path: root._helperPath
    }

    Process {
        id: _chmodProc
        command: ["chmod", "+x", root._helperPath]
        stdout: StdioCollector {}
    }

    Process {
        id: mkdirProc
        command: ["sh", "-c", "mkdir -p '" + root._dir + "' && touch '" + root._helperPath + "'"]
        stdout: StdioCollector {}
    }
}
