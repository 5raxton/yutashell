pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// VoiceInput — recording + transcription singleton. Records audio via
// pw-record (PipeWire), transcribes via faster-whisper or whisper.cpp.
// Gate on `available` (probes `which faster-whisper` at boot).
Singleton {
    id: root

    readonly property bool available: _probed && _toolOk
    property bool _probed: false
    property bool _toolOk: false
    property string _tool: ""

    property bool recording: false
    property bool transcribing: false
    property string transcript: ""

    signal transcribed(string text)
    signal error(string msg)

    function startRecording() {
        if (recording || !available) return;
        transcript = "";
        recordProc.command = ["pw-record", "--format=s16le", "--rate=16000",
            "/tmp/yuta-voice.wav"];
        recordProc.running = true;
        recording = true;
    }

    function stopRecording() {
        if (!recording) return;
        recordProc.running = false;
        recording = false;
        // auto-transcribe
        transcribe();
    }

    function transcribe() {
        if (transcribing) return;
        transcribing = true;
        const proc = root._tool === "faster-whisper"
            ? ["faster-whisper", "large-v3", "/tmp/yuta-voice.wav", "--output_format", "txt"]
            : ["whisper-cli", "-m", "/usr/share/whisper-cpp/ggml-base.bin", "-f", "/tmp/yuta-voice.wav"];
        transcribeProc.command = proc;
        transcribeProc.running = true;
    }

    Component.onCompleted: {
        probeProc.command = ["sh", "-c", "command -v faster-whisper 2>/dev/null && echo faster-whisper || (command -v whisper-cli 2>/dev/null && echo whisper-cli || echo none)"];
        probeProc.running = true;
    }

    Process {
        id: probeProc
        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                const tool = this.text.trim();
                if (tool === "faster-whisper" || tool === "whisper-cli") {
                    root._toolOk = true;
                    root._tool = tool;
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: { root._probed = true; }
        }
    }

    Process {
        id: recordProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: transcribeProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.transcribing = false;
                const text = this.text.trim();
                if (text.length > 0) {
                    root.transcript = text;
                    root.transcribed(text);
                } else {
                    root.error("No speech detected");
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0) {
                    root.transcribing = false;
                    root.error(this.text.trim());
                }
            }
        }
    }
}
