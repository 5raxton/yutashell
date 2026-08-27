pragma Singleton
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.theme
import qs.modules.common

// WsHeatmap (PH.06) — workspace memory visualization: queries hyprctl for
// workspace/window data, renders a color-coded grid showing window count and
// memory weight per workspace.
Singleton {
    id: root

    property var workspaces: []
    property bool available: false

    Process {
        id: wsProc
        command: ["hyprctl", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(this.text);
                    if (Array.isArray(arr))
                        root.workspaces = arr.map(w => ({
                            id: w.id ?? 0,
                            name: w.name ?? "",
                            windows: w.windows ?? 0,
                            focused: w.id === root._focusedId
                        })).filter(w => w.id > 0);
                } catch (e) {}
            }
        }
    }

    property int _focusedId: 0

    Process {
        id: focusedProc
        command: ["hyprctl", "-j", "activeworkspace"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const o = JSON.parse(this.text);
                    root._focusedId = o.id ?? 0;
                    root._refreshFocus();
                } catch (e) {}
            }
        }
    }

    function _refreshFocus() {
        const ws = root.workspaces;
        for (let i = 0; i < ws.length; i++)
            ws[i].focused = ws[i].id === root._focusedId;
        workspaces = ws;
    }

    function switchTo(wsId) {
        Hyprland.dispatch("hl.dsp.focus({workspace=" + wsId + "})");
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            wsProc.running = true;
            focusedProc.running = true;
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(evt) {
            if (evt.name === "workspace" || evt.name === "destroyworkspace")
                wsProc.running = true;
            if (evt.name === "activeworkspace")
                focusedProc.running = true;
        }
    }

    Component.onCompleted: { available = true; }
}
