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

    // probed — absent binaries must read as unavailable, not silently no-op
    readonly property bool available: _probed && _binOk
    property bool _binOk: false
    property bool _probed: false

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
        if (!root.available)
            return;
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
        if (!root.available || root.lastPath.length === 0)
            return;
        copyProc.command = ["sh", "-c", "wl-copy < '" + root.lastPath.replace(/'/g, "'\\''") + "'"];
        copyProc.running = true;
    }

    function status(): string {
        return "dir " + root.dir + " · template " + ShellState.shotName + (root.lastPath.length > 0 ? " · last " + root.lastPath : "");
    }

    Component.onCompleted: {
        binProbe.command = ["sh", "-c", "command -v grim >/dev/null 2>&1 && command -v slurp >/dev/null 2>&1 && echo yes || echo no"];
        binProbe.running = true;
    }

    Process {
        id: binProbe

        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._binOk = text.trim() === "yes";
                if (!root._binOk)
                    Health.report("shot", "screenshots unavailable (install grim + slurp)");
            }
        }
    }

    Process {
        id: regionProc

        stdout: StdioCollector {
            onStreamFinished: {
                const g = text.trim();
                // slurp emits "%x,%y %wx%h" on success
                if (/^\d+,\d+ \d+x\d+$/.test(g))
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
        onExited: code => Notify.announce("CLIPBOARD", code === 0 ? "shot copied to selection" : "copy failed (is wl-copy installed?)", code === 0 ? 1 : 2)
    }
}
