pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.notify

// Screenshot suite (PH.11) over grim + slurp + wl-copy. Modes: region (slurp
// selection, styled with the live acid accent), full (whole screen), window
// (focused window geometry from hyprctl). Each shot saves to the configured
// dir + strftime name template, flashes a border pulse, and toasts the path.
// `shot copy` re-copies the last shot; `shot dir` prints the directory.
Singleton {
    id: root

    // grim + slurp are core deps on this machine — treat as available
    readonly property bool available: true

    signal flashed()

    property string lastPath: ""

    readonly property string dir: String(ShellState.shotDir).replace(/^~/, Quickshell.env("HOME"))

    function _hex(c) {
        const r = Math.round(c.r * 255).toString(16).padStart(2, "0");
        const g = Math.round(c.g * 255).toString(16).padStart(2, "0");
        const b = Math.round(c.b * 255).toString(16).padStart(2, "0");
        return "#" + r + g + b;
    }

    // strftime subset (the default template needs only these)
    function _expand(t, d) {
        return String(t)
            .replace(/%Y/g, String(d.getFullYear()))
            .replace(/%m/g, String(d.getMonth() + 1).padStart(2, "0"))
            .replace(/%d/g, String(d.getDate()).padStart(2, "0"))
            .replace(/%H/g, String(d.getHours()).padStart(2, "0"))
            .replace(/%M/g, String(d.getMinutes()).padStart(2, "0"))
            .replace(/%S/g, String(d.getSeconds()).padStart(2, "0"));
    }

    function _nextPath() {
        return root.dir + "/" + root._expand(ShellState.shotName, new Date()) + ".png";
    }

    function capture(mode) {
        const m = String(mode).toLowerCase();
        if (m === "region") {
            regionProc.command = ["sh", "-c",
                "mkdir -p '" + root.dir.replace(/'/g, "'\\''") + "' && slurp -b '" + root._hex(Theme.acid) + "22' -c '" + root._hex(Theme.acid) + "' -f 'JetBrainsMono Nerd Font' -F 'SELECT REGION'"];
            regionProc.running = true;
        } else if (m === "window") {
            winProc.command = ["hyprctl", "-j", "activewindow"];
            winProc.running = true;
        } else {
            root._grim("");
        }
    }

    function _grim(geom) {
        const path = root._nextPath();
        root.lastPath = path;
        if (geom.length > 0)
            grimProc.command = ["sh", "-c", "mkdir -p '" + root.dir.replace(/'/g, "'\\''") + "' && grim -g '" + geom.replace(/'/g, "'\\''") + "' '" + path.replace(/'/g, "'\\''") + "'"];
        else
            grimProc.command = ["sh", "-c", "mkdir -p '" + root.dir.replace(/'/g, "'\\''") + "' && grim '" + path.replace(/'/g, "'\\''") + "'"];
        grimProc.running = true;
    }

    function copyLast() {
        if (root.lastPath.length === 0)
            return;
        copyProc.command = ["sh", "-c", "wl-copy < '" + root.lastPath.replace(/'/g, "'\\''") + "'"];
        copyProc.running = true;
        Notify.announce("CLIPBOARD", "shot copied to selection", 1);
    }

    function status(): string {
        return "dir " + root.dir + " · template " + ShellState.shotName + (root.lastPath.length > 0 ? " · last " + root.lastPath : "");
    }

    Process {
        id: regionProc

        stdout: StdioCollector {
            onStreamFinished: {
                const g = text.trim();
                // slurp emits "x,y w h" on success
                if (/^\d+,\d+ \d+ \d+$/.test(g))
                    root._grim(g);
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: winProc

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const j = JSON.parse(text);
                    const at = j["at"] ?? [0, 0];
                    const size = j["size"] ?? [0, 0];
                    if (size[0] > 0 && size[1] > 0)
                        root._grim(at[0] + "," + at[1] + " " + size[0] + "x" + size[1]);
                } catch (e) {
                    // no focused window — fall back to full screen
                    root._grim("");
                }
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: grimProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            if (code === 0) {
                root.flashed();
                Notify.announce("SHOT SAVED", root.lastPath.replace(root.dir + "/", ""), 1);
            } else {
                Notify.announce("SHOT FAILED", "grim exited " + code, 2);
            }
        }
    }

    Process {
        id: copyProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
}
