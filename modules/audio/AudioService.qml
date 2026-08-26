pragma Singleton
import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import qs.modules.common

// Shared audio model over Quickshell.Services.Pipewire. One tracker keeps
// every node's audio iface warm; consumers read sinks/sources/streams from
// here and never touch Pipewire directly.
//
// Volume math: PipeWire amplitudes are LINEAR (1.0 = 100 %). UI sliders run
// on a CUBIC taper (perceptual) mapped across 0..audioCeiling — the overdrive
// region above 100 % rides the same curve.
//
// PH.01.3: PwNodePeakMonitor feeds real audio peaks for the visualizer —
// replaces fake static bars.
Singleton {
    id: root

    readonly property bool ready: Pipewire.ready

    // OSD requests — the Osd window listens and shows itself
    signal osdPing(string kind)

    // overdrive ceiling as a multiplier (1.3 = 130 %); persisted knob
    readonly property real ceiling: Math.max(1.0, ShellState.audioCeiling / 100)

    // keep sink/source nodes' properties/audio populated (streams handled separately)
    readonly property PwObjectTracker tracker: PwObjectTracker {
        objects: Pipewire.nodes.values.filter(n => n.audio && (n.isSink || (!n.isSink && !n.isStream)))
    }

    // ---- peak monitor (PH.01.3) -------------------------------------------
    // Real-time peak levels from the default audio sink for the CC visualizer.
    readonly property PwNodePeakMonitor peakMonitor: PwNodePeakMonitor {
        node: root.sink
        enabled: root.ready && root.sink !== null
    }
    // Normalized peak value 0..1 (PipeWire peaks are linear 0..1 already)
    readonly property real peakLevel: peakMonitor ? peakMonitor.peak : 0
    // Per-channel peaks list (float[])
    readonly property var channelPeaks: peakMonitor ? peakMonitor.peaks : []

    // ---- handles -----------------------------------------------------------
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink)
    readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isStream)

    // ---- volume math -------------------------------------------------------
    function clamp01(f) {
        return Math.max(0, Math.min(1, f));
    }

    // slider fraction [0..1] -> linear amplitude across 0..ceiling (cubic taper)
    function fracToVol(f) {
        return root.ceiling * Math.pow(root.clamp01(f), 3);
    }

    // linear amplitude -> slider fraction
    function volToFrac(v) {
        return Math.cbrt(root.clamp01((v ?? 0) / root.ceiling));
    }

    function nodePct(node) {
        return node && node.audio ? Math.round(node.audio.volume * 100) : 0;
    }

    function nodeFrac(node) {
        return node && node.audio ? root.volToFrac(node.audio.volume) : 0;
    }

    function setFrac(node, f) {
        if (!node || !node.audio)
            return;
        const v = root.fracToVol(f);
        node.audio.muted = v <= 0.0001;
        node.audio.volume = v;
    }

    function step(node, deltaFrac) {
        if (!node || !node.audio)
            return;
        root.setFrac(node, root.nodeFrac(node) + deltaFrac);
    }

    // step in percentage POINTS (wheel/keys) — linear, predictable
    function stepPct(node, deltaPct) {
        if (!node || !node.audio)
            return;
        const v = Math.max(0, Math.min(root.ceiling, node.audio.volume + deltaPct / 100));
        node.audio.muted = v <= 0.0001;
        node.audio.volume = v;
    }

    function toggleMute(node) {
        if (!node || !node.audio)
            return false;
        node.audio.muted = !node.audio.muted;
        return node.audio.muted;
    }

    // ---- labels ------------------------------------------------------------
    function streamLabel(n) {
        const p = n.properties ?? {};
        return String(p["application.name"] || n.nickname || n.description || n.name || "stream");
    }

    function deviceLabel(n) {
        return String((n.nickname || n.description || n.name || "").replace(/^Built-in\s*/, ""));
    }
}
