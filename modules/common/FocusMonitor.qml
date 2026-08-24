pragma Singleton
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

// FocusMonitor (PH.06) — tracks the compositor-focused monitor so floating
// surfaces open where the user's attention actually is instead of always on
// the first screen. `focusedmonv2` raw events carry "NAME,workspace"; a
// delayed boot probe reads hyprctl -j monitors (focused:true output).
//
// Popup placement LATCHES at open time: ShellState._exclusive calls latch()
// whenever something opens, freezing the target so a mid-display focus move
// never drags a visible card across monitors. Toasts re-latch per arrival.
Singleton {
    id: root

    // live focus state
    property string focusedName: ""
    readonly property var focusedScreen: root.byName(root.focusedName)

    // frozen-at-open target; falls back to live focus, then first screen
    property string latchedName: ""

    readonly property var screen: {
        const l = root.byName(root.latchedName);
        if (l)
            return l;
        const f = root.focusedScreen;
        if (f)
            return f;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
    }

    readonly property bool multiMonitor: Quickshell.screens.length > 1

    function byName(n) {
        if (!n || n.length === 0)
            return null;
        for (let i = 0; i < Quickshell.screens.length; i++) {
            if (Quickshell.screens[i].name === n)
                return Quickshell.screens[i];
        }
        return null;
    }

    function latch() {
        const f = root.focusedScreen;
        if (f)
            root.latchedName = f.name;
    }

    Process {
        id: probe

        command: ["hyprctl", "-j", "monitors"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const list = JSON.parse(this.text);
                    for (let i = 0; i < list.length; i++) {
                        if (list[i].focused) {
                            root.focusedName = String(list[i].name);
                            return;
                        }
                    }
                    if (list.length > 0)
                        root.focusedName = String(list[0].name);
                } catch (e) {}
            }
        }
    }

    Timer {
        interval: 1400
        running: true
        repeat: false
        onTriggered: probe.running = true
    }

    Connections {
        target: Hyprland

        function onRawEvent(evt) {
            if (evt.name === "focusedmonv2") {
                const idx = String(evt.data).indexOf(",");
                root.focusedName = idx > 0 ? String(evt.data).slice(0, idx) : "";
            }
        }
    }
}
