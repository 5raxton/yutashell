pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs.modules.common
import "../widgets"

// IdleInhibitor (PH.01.2) — prevents screen idle while media is playing or a
// recording is in progress. State lives here; the actual Wayland
// idle-inhibit-unstable-v1 surfaces are instantiated per-Bar (each bar's
// PanelWindow serves as the surface). A manual toggle override is persisted
// in ShellState.
Singleton {
    id: root

    readonly property bool inhibited: _autoInhibit || manualInhibit

    property bool manualInhibit: false
    onManualInhibitChanged: ShellState.set("idleInhibitManual", manualInhibit)

    readonly property bool _autoInhibit: {
        if (!autoMode) return false;
        return _mediaPlaying || Recording.active;
    }

    property bool autoMode: true
    onAutoModeChanged: ShellState.set("idleInhibitAuto", autoMode)

    property bool _mediaPlaying: false

    function toggle() {
        manualInhibit = !manualInhibit;
    }

    Component.onCompleted: {
        manualInhibit = ShellState.idleInhibitManual ?? false;
        autoMode = ShellState.idleInhibitAuto ?? true;
        _checkMedia();
    }

    function _checkMedia() {
        let playing = false;
        try {
            const ps = Mpris.players.values ?? [];
            for (let i = 0; i < ps.length; i++) {
                if (ps[i].isPlaying) { playing = true; break; }
            }
        } catch (e) {}
        _mediaPlaying = playing;
    }

    Connections {
        target: Mpris
        function onPlayersChanged() { root._checkMedia(); }
    }

    Timer {
        interval: 3000
        running: root.autoMode
        repeat: true
        onTriggered: root._checkMedia()
    }

    // ---- IPC ----
    function list(): string {
        const p = [];
        if (manualInhibit) p.push("manual");
        if (_autoInhibit) p.push("auto");
        if (_mediaPlaying) p.push("media");
        if (Recording.active) p.push("recording");
        return p.length > 0 ? p.join(",") : "none";
    }
}
