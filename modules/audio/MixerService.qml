pragma Singleton
import Quickshell
import QtQuick
import qs.modules.common

// MixerService (PH.02.1) — per-app audio mixer over PipeWire. Wraps
// AudioService streams with desktop-entry icon resolution and a clean
// write-back API for the MixerPanel.
Singleton {
    id: root

    readonly property bool ready: AudioService.ready

    // output streams (audio playback apps)
    readonly property var outputStreams: AudioService.streams

    // output devices
    readonly property var sinks: AudioService.sinks
    readonly property var currentSink: AudioService.sink

    // input devices
    readonly property var sources: AudioService.sources
    readonly property var currentSource: AudioService.source

    // ---- per-stream API ----

    function label(stream) {
        return AudioService.streamLabel(stream);
    }

    function iconUrl(stream) {
        if (!stream)
            return "";
        const p = stream.properties ?? {};
        const appId = p["application.id"] || p["application.name"] || "";
        if (appId.length > 0) {
            const e = DesktopEntries.heuristicLookup(appId);
            if (e)
                return Quickshell.iconPath(e.icon, "");
        }
        return "";
    }

    function volume(stream) {
        return stream && stream.audio ? stream.audio.volume : 0;
    }

    function volumePct(stream) {
        return AudioService.nodePct(stream);
    }

    function volumeFrac(stream) {
        return AudioService.nodeFrac(stream);
    }

    function setVolumeFrac(stream, frac) {
        AudioService.setFrac(stream, frac);
    }

    function isMuted(stream) {
        return stream && stream.audio ? stream.audio.muted : false;
    }

    function toggleMute(stream) {
        AudioService.toggleMute(stream);
    }

    // ---- device switch ----

    function switchOutput(sink) {
        if (sink)
            Pipewire.preferredDefaultAudioSink = sink;
    }

    function switchInput(source) {
        if (source)
            Pipewire.preferredDefaultAudioSource = source;
    }

    // ---- master volume (for bar segment scroll) ----

    function masterVolumeFrac() {
        return AudioService.nodeFrac(root.currentSink);
    }

    function stepMaster(deltaPct) {
        AudioService.stepPct(root.currentSink, deltaPct);
        AudioService.osdPing("volume");
    }

    function toggleMasterMute() {
        AudioService.toggleMute(root.currentSink);
        AudioService.osdPing("volume");
    }

    // ---- IPC ----
    function status(): string {
        const n = root.outputStreams.length;
        const dev = root.currentSink ? AudioService.deviceLabel(root.currentSink) : "none";
        return dev + " · " + n + " stream" + (n !== 1 ? "s" : "") + " · " + AudioService.nodePct(root.currentSink) + "%";
    }
}
