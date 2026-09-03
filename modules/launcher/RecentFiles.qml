pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// RecentFiles — reads XDG recently-used.xbel and exposes the top 20 most
// recently accessed files as a flat list [{name, uri, mimeType, timestamp}].
// The launcher uses this for `~` prefix mode.
Singleton {
    id: root

    readonly property var files: _parsed
    property var _parsed: []
    property bool _loaded: false

    FileView {
        id: xbelFile
        path: (Quickshell.env("HOME") ?? "") + "/.local/state/recently-used.xbel"
        printErrors: false
        preload: true
        onLoaded: root._parse()
        onTextChanged: root._parse()
    }

    function _parse() {
        const raw = xbelFile.text();
        if (!raw || raw.length === 0) {
            _parsed = [];
            _loaded = true;
            return;
        }
        const items = [];
        // Simple regex extraction — XBEL bookmark elements have
        // <bookmark href="..." added="..."><title>...</title><metadata>...</metadata></bookmark>
        const re = /<bookmark\s+href="([^"]*)"[^>]*added="([^"]*)"[^>]*>\s*<title>([^<]*)<\/title>/g;
        let m;
        while ((m = re.exec(raw)) !== null) {
            items.push({
                uri: m[1],
                name: m[3],
                added: m[2],
                timestamp: Date.parse(m[2]) || 0
            });
        }
        // sort newest first, cap at 20
        items.sort((a, b) => b.timestamp - a.timestamp);
        _parsed = items.slice(0, 20);
        _loaded = true;
    }

    function openFile(uri) {
        openProc.command = ["xdg-open", uri];
        openProc.running = true;
    }

    Process {
        id: openProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
}
