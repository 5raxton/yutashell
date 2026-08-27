pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common
import qs.modules.notify
import "../session"

// FocusMode (PH.05) — deep focus state machine: idle → focusing → break →
// longBreak → idle. Extends Pomodoro with DND integration, idle inhibit,
// session stats logging, and a break overlay. Persists config in ShellState;
// runtime state is ephemeral.
Singleton {
    id: root

    // config
    property int workMin: ShellState.focusWorkMin ?? 25
    property int breakMin: ShellState.focusBreakMin ?? 5
    property int longBreakMin: ShellState.focusLongBreakMin ?? 15
    property int roundsBeforeLong: ShellState.focusRoundsBeforeLong ?? 4

    // runtime state
    property string phase: "idle"   // idle | focusing | break | longBreak
    property int remaining: 0       // seconds
    property int round: 0           // completed work rounds
    property bool running: false
    property int totalFocusedToday: 0  // seconds focused today

    // session history (persisted)
    property var history: []

    readonly property string display: {
        if (phase === "idle") return "IDLE";
        const m = Math.floor(remaining / 60);
        const s = remaining % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    readonly property string label: {
        if (phase === "focusing") return "FOCUS";
        if (phase === "break") return "BREAK";
        if (phase === "longBreak") return "LONG";
        return "WELL";
    }

    readonly property bool showBreak: phase === "break" || phase === "longBreak"
    readonly property bool focusing: phase === "focusing" && running

    function start() {
        if (running) return;
        _enterPhase("focusing");
        running = true;
        // enable DND
        Notify.setDnd(true);
        // inhibit idle
        IdleInhibitor.manualInhibit = true;
    }

    function pause() {
        running = false;
        tickTimer.stop();
    }

    function resume() {
        if (phase === "idle") { start(); return; }
        running = true;
        tickTimer.start();
    }

    function reset() {
        running = false;
        phase = "idle";
        remaining = 0;
        round = 0;
        tickTimer.stop();
        // restore DND and idle inhibit
        Notify.setDnd(false);
        IdleInhibitor.manualInhibit = false;
    }

    function toggle() {
        if (running) pause();
        else if (phase === "idle") start();
        else resume();
    }

    function _enterPhase(p) {
        phase = p;
        if (p === "focusing") {
            remaining = workMin * 60;
        } else if (p === "break") {
            remaining = breakMin * 60;
        } else if (p === "longBreak") {
            remaining = longBreakMin * 60;
        }
        tickTimer.start();
    }

    function _advance() {
        if (phase === "focusing") {
            // log this session
            const sessionMin = workMin;
            totalFocusedToday += workMin * 60;
            _logSession(sessionMin);

            round++;
            if (round >= roundsBeforeLong) {
                Notify.announce("FOCUS", "Great work! Time for a long break.", 4);
                _enterPhase("longBreak");
            } else {
                Notify.announce("FOCUS", "Break time! Stand up and stretch.", 3);
                _enterPhase("break");
            }
        } else if (phase === "break" || phase === "longBreak") {
            if (phase === "longBreak") round = 0;
            Notify.announce("FOCUS", "Ready to focus again?", 3);
            _enterPhase("focusing");
        }
    }

    function _logSession(minutes) {
        const today = new Date().toISOString().slice(0, 10);
        let entry = history.find(h => h.date === today);
        if (!entry) {
            entry = { date: today, sessions: 0, totalMin: 0 };
            history.push(entry);
        }
        entry.sessions++;
        entry.totalMin += minutes;
        // keep last 30 days
        if (history.length > 30)
            history = history.slice(history.length - 30);
        _saveHistory();
    }

    function _saveHistory() {
        historyWrite.setText(JSON.stringify(history, null, 2));
    }

    FileView {
        id: historyRead
        path: (Quickshell.env("HOME") ?? "") + "/.local/state/yutashell/focus-history.json"
    }

    FileView {
        id: historyWrite
        path: (Quickshell.env("HOME") ?? "") + "/.local/state/yutashell/focus-history.json"
        adapter: JsonAdapter {}
    }

    Timer {
        id: tickTimer
        interval: 1000
        repeat: true
        onTriggered: {
            root.remaining--;
            if (root.remaining <= 0) {
                tickTimer.stop();
                root._advance();
            }
        }
    }

    Component.onCompleted: {
        // load history from file
        try {
            const raw = historyRead.text();
            if (raw && raw.length > 0) {
                const arr = JSON.parse(raw);
                if (Array.isArray(arr)) root.history = arr;
            }
        } catch (e) {}
        // restore today's total from history
        const today = new Date().toISOString().slice(0, 10);
        const entry = history.find(h => h.date === today);
        if (entry) totalFocusedToday = entry.totalMin * 60;
    }

    // IPC
    function status(): string {
        return phase + " " + display + " round=" + round + " today=" + Math.floor(totalFocusedToday / 60) + "m";
    }
}
