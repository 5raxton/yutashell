pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// ScreenshotAction — captures a region via grim+slurp, sends to Ollama vision
// model (llava/bakllava) for analysis. Gate on AiService.available.
Singleton {
    id: root

    property bool busy: false
    property string lastResult: ""
    property string error: ""

    signal resultReady(string text)

    function captureAndAnalyze(question) {
        if (busy || !AiService.available) return;
        busy = true;
        error = "";
        lastResult = "";
        _question = question || "What do you see in this screenshot?";
        // capture region
        captureProc.command = ["sh", "-c", "slurp | grim -g - /tmp/yuta-shot.png"];
        captureProc.running = true;
    }

    property string _question: ""

    Process {
        id: captureProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                // slurp cancel or grim failure
                if (this.text.includes("cancelled") || this.text.includes("error")) {
                    root.busy = false;
                    root.error = "Screenshot cancelled";
                }
            }
        }
        onRunningChanged: {
            if (!running && !root.error) {
                // capture finished — encode and send
                root._sendToVision();
            }
        }
    }

    function _sendToVision() {
        // encode image as base64
        encodeProc.command = ["base64", "-w0", "/tmp/yuta-shot.png"];
        encodeProc.running = true;
    }

    Process {
        id: encodeProc
        stdout: StdioCollector {
            onStreamFinished: {
                const b64 = this.text.trim();
                if (b64.length === 0) {
                    root.busy = false;
                    root.error = "Failed to encode screenshot";
                    return;
                }
                // determine model (prefer llava)
                let model = AiService.model;
                if (model.indexOf("llava") < 0 && model.indexOf("bakllava") < 0) {
                    // try to find a vision model
                    const visionModels = AiService.models.filter(m => m.indexOf("llava") >= 0 || m.indexOf("bakllava") >= 0);
                    if (visionModels.length > 0)
                        model = visionModels[0];
                    else {
                        root.busy = false;
                        root.error = "No vision model available (need llava or bakllava)";
                        return;
                    }
                }
                root._analyze(b64, model);
            }
        }
        stderr: StdioCollector {}
    }

    function _analyze(base64, model) {
        const payload = {
            model: model,
            messages: [{
                role: "user",
                content: root._question,
                images: [base64]
            }],
            stream: false
        };
        const json = JSON.stringify(payload);
        visionProc.command = ["curl", "-s", "--max-time", "60",
            "-H", "Content-Type: application/json",
            "-d", json,
            AiService.endpoint + "/api/chat"];
        visionProc.running = true;
    }

    Process {
        id: visionProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                try {
                    const data = JSON.parse(this.text);
                    if (data.message && data.message.content) {
                        root.lastResult = data.message.content;
                        root.resultReady(data.message.content);
                    } else {
                        root.error = "No response from vision model";
                    }
                } catch (e) {
                    root.error = "Failed to parse vision response";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0) {
                    root.busy = false;
                    root.error = this.text.trim();
                }
            }
        }
    }
}
