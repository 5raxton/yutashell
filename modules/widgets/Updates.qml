pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common
import qs.modules.notify

// Updates (PH.11) — sparse `checkupdates` poll (pacman-contrib). Click/`updates
// check` refreshes; `updates show` lists them; `updates open` launches a
// terminal so the user can run the upgrade themselves. Graceful when absent.
Singleton {
    id: root

    readonly property bool available: _probed && _binOk
    property bool _binOk: false
    property bool _probed: false

    property var packages: []   // raw "name old -> new" lines
    property bool checking: false
    property date lastCheck: new Date(0)

    readonly property int count: packages.length

    function refresh() {
        if (!root.available)
            return;
        root.checking = true;
        probe.running = true;
    }

    function openTerminal() {
        // launch the user's terminal with a checkupdates+upgrade hint
        termProc.command = ["sh", "-c", "(alacritty -e sh -c 'checkupdates; echo; echo \"run: sudo pacman -Syu\"; exec \"$SHELL\"' >/dev/null 2>&1 &) || true"];
        termProc.running = true;
    }

    function status(): string {
        if (!root.available)
            return "unavailable (install pacman-contrib)";
        return root.count + " update(s)" + (root.lastCheck.getTime() > 0 ? " · checked " + root.lastCheck.toTimeString().slice(0, 5) : "");
    }

    Component.onCompleted: {
        binProbe.command = ["sh", "-c", "command -v checkupdates >/dev/null 2>&1 && echo yes || echo no"];
        binProbe.running = true;
    }

    Process {
        id: binProbe

        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._binOk = text.trim() === "yes";
                if (root._binOk)
                    root.refresh();
            }
        }
    }

    Process {
        id: probe

        stdout: StdioCollector {
            onStreamFinished: {
                root.checking = false;
                const lines = text.trim().length ? text.trim().split("\n") : [];
                root.packages = lines;
                root.lastCheck = new Date();
                // narrate only transitions — a static list must not toast
                // every 6h re-check
                if (lines.length > 0 && lines.length !== root._announcedCount)
                    Notify.announce("UPDATES", lines.length + " package update(s) available", 1);
                root._announcedCount = lines.length;
            }
        }
        stderr: StdioCollector {}
    }

    property int _announcedCount: -1

    Process {
        id: termProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    // sparse re-check every 6h
    Timer {
        interval: 21600000
        running: true
        repeat: true
        triggeredOnStart: false
        onTriggered: root.refresh()
    }
}
