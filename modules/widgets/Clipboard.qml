pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common
import qs.modules.notify

// Clipboard — history model over cliphist (PH.11). Lists, re-copies and
// deletes entries; pins favorites to the top. Binary entries (images) are
// detected and surfaced as IMAGE rows (text copy is the primary path).
// `available` is false when cliphist is absent — the panel hides then.
Singleton {
    id: root

    readonly property bool available: _probed && _binOk
    property bool _binOk: false
    property bool _probed: false

    property var entries: []        // [{id, preview, binary}]
    property bool refreshing: false

    // pinned entry ids (string) surfaced at the top
    readonly property var pins: {
        try {
            const v = JSON.parse(ShellState.clipboardPins);
            return Array.isArray(v) ? v.map(String) : [];
        } catch (e) {
            return [];
        }
    }

    function isPinned(id) {
        return root.pins.indexOf(String(id)) >= 0;
    }

    function pin(id) {
        const s = String(id);
        if (root.isPinned(s))
            return;
        ShellState.set("clipboardPins", JSON.stringify(root.pins.concat([s])));
    }

    function unpin(id) {
        ShellState.set("clipboardPins", JSON.stringify(root.pins.filter(p => p !== String(id))));
    }

    // ordered model: pinned first (MRU-ish by recency), then the rest
    readonly property var sorted: {
        const pinned = [];
        const rest = [];
        for (const e of root.entries) {
            if (root.isPinned(e.id))
                pinned.push(e);
            else
                rest.push(e);
        }
        return pinned.concat(rest);
    }

    function _isBinary(s) {
        for (let i = 0; i < Math.min(s.length, 256); i++) {
            const c = s.charCodeAt(i);
            if (c < 9 || (c > 13 && c < 32))
                return true;
        }
        return false;
    }

    function refresh() {
        if (!root.available)
            return;
        root.refreshing = true;
        listProc.running = true;
    }

    function copy(e) {
        if (!root.available || !e)
            return;
        const id = String(e.id);
        // announce from the exit code — a missing wl-copy must not claim success
        _copyBinary = e.binary === true;
        copyProc.command = ["sh", "-c", "cliphist decode '" + id + "' | wl-copy"];
        copyProc.running = true;
    }

    property bool _copyBinary: false

    function remove(id) {
        if (!root.available)
            return;
        delProc.command = ["cliphist", "delete", String(id)];
        delProc.running = true;
    }

    function clearAll() {
        if (!root.available)
            return;
        wipeProc.command = ["cliphist", "wipe"];
        wipeProc.running = true;
    }

    Component.onCompleted: {
        binProbe.command = ["sh", "-c", "command -v cliphist >/dev/null 2>&1 && command -v wl-copy >/dev/null 2>&1 && echo yes || echo no"];
        binProbe.running = true;
    }

    Process {
        id: binProbe

        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._binOk = text.trim() === "yes";
                if (!root._binOk)
                    Health.report("cliphist", "clipboard unavailable (install cliphist + wl-clipboard)");
                else
                    Health.clear("cliphist");
                if (root._binOk)
                    root.refresh();
            }
        }
    }

    Process {
        id: listProc

        stdout: StdioCollector {
            onStreamFinished: {
                root.refreshing = false;
                const out = [];
                const lines = text.trim().length ? text.trim().split("\n") : [];
                for (let i = 0; i < lines.length; i++) {
                    const idx = lines[i].indexOf("\t");
                    if (idx < 0)
                        continue;
                    const id = lines[i].slice(0, idx);
                    const prev = lines[i].slice(idx + 1);
                    const bin = root._isBinary(prev);
                    out.push({
                        id: id,
                        preview: bin ? "" : prev,
                        binary: bin
                    });
                }
                root.entries = out;
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: copyProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => Notify.announce("CLIPBOARD", code === 0 ? ((_copyBinary ? "image " : "") + "copied to selection") : "copy failed (is wl-copy installed?)", code === 0 ? 1 : 2)
    }

    Process {
        id: delProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: root.refresh()
    }

    Process {
        id: wipeProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: root.refresh()
    }
}
