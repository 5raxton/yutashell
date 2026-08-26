pragma Singleton
import Quickshell
import QtQuick
import qs.modules.common
import "../widgets"
import Quickshell.Hyprland
import Quickshell.Services.Mpris

// AiContext — builds a system prompt from live shell state for every AI query.
// Sensitive context (file contents, clipboard, window titles with URLs) is only
// included when the provider is local (Ollama).
Singleton {
    id: root

    function buildContext() {
        const parts = [];
        const ts = new Date().toLocaleString();
        parts.push("Time: " + ts);

        // active window
        try {
            const tl = FocusMonitor.activeToplevel;
            if (tl) {
                const appId = tl.wayland ? tl.wayland.appId : (tl.lastIpcObject ? tl.lastIpcObject.class : "unknown");
                const title = tl.title || "";
                parts.push("Active window: " + appId + " \"" + title + "\"");
            }
        } catch (e) {}

        // workspace
        try {
            const ws = FocusMonitor.activeWorkspace;
            if (ws) {
                const wCount = Hyprland.toplevels.values.filter(t => {
                    try { return t.workspace && t.workspace.id === ws.id; } catch (e) { return false; }
                }).length;
                parts.push("Workspace: " + ws.id + " (" + wCount + " windows)");
            }
        } catch (e) {}

        // MPRIS
        try {
            const players = Mpris.players.values;
            const playing = players.find(p => p.isPlaying);
            if (playing)
                parts.push("Playing: " + (playing.trackTitle || "unknown") + " by " + (playing.trackArtist || "unknown"));
            else
                parts.push("Playing: nothing");
        } catch (e) {}

        // system stats
        try {
            parts.push("CPU: " + SystemStats.cpuPercent + "% | RAM: " + SystemStats.memUsedGb + "/" + SystemStats.memTotalGb + " GB");
        } catch (e) {}

        // battery
        try {
            if (SystemStats.batPresent)
                parts.push("Battery: " + SystemStats.batPercent + "% " + (SystemStats.batCharging ? "(charging)" : "(discharging)"));
        } catch (e) {}

        // network
        try {
            parts.push("Network: " + (SystemStats.netOnline ? "online" : "offline"));
        } catch (e) {}

        // weather (if configured)
        try {
            if (typeof Weather !== "undefined" && Weather.current) {
                parts.push("Weather: " + Weather.current.condition + " " + Weather.current.temp + "° " + (ShellState.weatherUnit === "fahrenheit" ? "F" : "C"));
            }
        } catch (e) {}

        // time of day context
        const hour = new Date().getHours();
        if (hour < 6) parts.push("Time of day: night");
        else if (hour < 12) parts.push("Time of day: morning");
        else if (hour < 17) parts.push("Time of day: afternoon");
        else parts.push("Time of day: evening");

        const isWeekend = [0, 6].indexOf(new Date().getDay()) >= 0;
        parts.push("Day: " + (isWeekend ? "weekend" : "weekday"));

        // local-only sensitive context
        if (root._isLocal()) {
            // clipboard content hint
            try {
                if (typeof Clipboard !== "undefined" && Clipboard.currentText)
                    parts.push("Clipboard: (text content available — ask user to paste if needed)");
            } catch (e) {}
        }

        return parts.join("\n");
    }

    function _isLocal() {
        return ShellState.aiProvider === "ollama" || ShellState.aiEndpoint.indexOf("localhost") >= 0 || ShellState.aiEndpoint.indexOf("127.0.0.1") >= 0;
    }
}
