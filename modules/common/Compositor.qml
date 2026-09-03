pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

// Compositor (PH.07) — capability detection for the running Wayland
// compositor. yutashell's deep integration targets Hyprland (Helmsman Lua
// dispatcher); other compositors get honest degradation instead of silent
// breakage: features report unavailable through Health, and `compositor
// info` over IPC states the situation in one line.
Singleton {
    id: root

    readonly property bool isHyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? "").length > 0
    readonly property bool isSway: (Quickshell.env("SWAYSOCK") ?? "").length > 0
    readonly property bool isNiri: (Quickshell.env("NIRI_SOCKET") ?? "").length > 0
    readonly property string kind: root.isHyprland ? "hyprland" : root.isSway ? "sway" : root.isNiri ? "niri" : "unknown"

    // feature backends actually consumed by this shell (external tools)
    readonly property var backendMap: ({
            "nightlight": ["hyprsunset", "wlsunset"],
            "screenshot": ["grim"],
            "region-select": ["slurp"],
            "clipboard-history": ["cliphist"]
        })

    property var bins: ({})
    readonly property bool probed: binProbe._done

    Process {
        id: binProbe

        property bool _done: false

        command: ["sh", "-c", "for b in hyprsunset wlsunset grim slurp cliphist; do command -v \"$b\" >/dev/null 2>&1 && echo \"$b ok\" || echo \"$b missing\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                const lines = this.text.trim().split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split(" ");
                    if (parts.length === 2)
                        map[parts[0]] = parts[1] === "ok";
                }
                root.bins = map;
                binProbe._done = true;
            }
        }
    }

    function hasBin(b) {
        return root.bins[b] === true;
    }

    // first available backend binary for a feature id, or "" when none
    function backend(feature) {
        const list = root.backendMap[feature] ?? [];
        for (let i = 0; i < list.length; i++) {
            if (root.hasBin(list[i]))
                return list[i];
        }
        return "";
    }

    Component.onCompleted: {
        binProbe.running = true;
        if (!root.isHyprland)
            Health.report("compositor", "yutashell targets Hyprland — running under '" + root.kind + "', compositor integration is limited");
        else
            Health.clear("compositor");
    }
}
