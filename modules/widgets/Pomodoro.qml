pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common
import qs.modules.notify

// Pomodoro timer — work/break cycle with bar chip and IPC control.
// State machine: idle → work → break → ... → longBreak → idle.
// Persists timing prefs in ShellState; runtime state is ephemeral.
Singleton {
    id: root

    // config
    property int workMin: 25
    property int breakMin: 5
    property int longBreakMin: 15
    property int roundsBeforeLong: 4

    // runtime state
    property string phase: "idle"   // idle | work | break | longBreak
    property int remaining: 0       // seconds
    property int round: 0           // completed work rounds
    property bool running: false

    readonly property string display: {
        if (phase === "idle") return "IDLE";
        const m = Math.floor(remaining / 60);
        const s = remaining % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }
    readonly property string label: {
        if (phase === "work") return "WORK";
        if (phase === "break") return "BREAK";
        if (phase === "longBreak") return "LONG";
        return "POMO";
    }

    function start() {
        if (running) return;
        _enterPhase("work");
        running = true;
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
    }

    function toggle() {
        if (running) pause();
        else if (phase === "idle") start();
        else resume();
    }

    function _enterPhase(p) {
        phase = p;
        if (p === "work") {
            remaining = workMin * 60;
        } else if (p === "break") {
            remaining = breakMin * 60;
        } else if (p === "longBreak") {
            remaining = longBreakMin * 60;
        }
        tickTimer.start();
    }

    function _advance() {
        if (phase === "work") {
            round++;
            if (round >= roundsBeforeLong) {
                Notify.announce("POMODORO", "Time for a long break!", 4);
                _enterPhase("longBreak");
            } else {
                Notify.announce("POMODORO", "Time for a break!", 3);
                _enterPhase("break");
            }
        } else if (phase === "break" || phase === "longBreak") {
            if (phase === "longBreak") round = 0;
            Notify.announce("POMODORO", "Back to work!", 3);
            _enterPhase("work");
        }
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
}
