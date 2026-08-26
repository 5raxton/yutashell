pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

// AiService — core AI singleton connecting to Ollama or any OpenAI-compatible
// endpoint. HTTP via Process + curl (same pattern as Weather/SystemStats).
// Streams SSE responses into responseBuffer for real-time UI binding.
Singleton {
    id: root

    readonly property bool available: _probed && _endpointOk
    property bool _probed: false
    property bool _endpointOk: false

    // provider config (persisted via ShellState)
    readonly property string provider: ShellState.aiProvider
    readonly property string endpoint: ShellState.aiEndpoint
    readonly property string model: ShellState.aiModel

    // runtime state
    property bool isRunning: false
    property string responseBuffer: ""
    property var models: []
    property string error: ""

    // conversation history for chat mode
    property var _messages: []
    // accumulated SSE buffer for streaming parse
    property string _streamBuf: ""

    signal completed(string response)
    signal modelsRefreshed()

    function chat(messages, systemPrompt) {
        if (isRunning || !available) return;
        _messages = messages.slice();
        _startRequest(_buildChatPayload(systemPrompt));
    }

    function complete(prompt, systemPrompt) {
        if (isRunning || !available) return;
        _messages = [
            { role: "user", content: prompt }
        ];
        _startRequest(_buildChatPayload(systemPrompt || ""));
    }

    function clearHistory() {
        _messages = [];
    }

    function _buildChatPayload(systemPrompt) {
        const msgs = [];
        if (systemPrompt && systemPrompt.length > 0) {
            msgs.push({ role: "system", content: systemPrompt });
        }
        for (let i = 0; i < _messages.length; i++)
            msgs.push(_messages[i]);
        return {
            model: root.model,
            messages: msgs,
            stream: true
        };
    }

    function _startRequest(payload) {
        isRunning = true;
        responseBuffer = "";
        error = "";
        _streamBuf = "";
        const json = JSON.stringify(payload);
        chatProc.command = ["curl", "-s", "-N", "--max-time", "120",
            "-H", "Content-Type: application/json",
            "-d", json,
            root.endpoint + "/api/chat"];
        chatProc.running = true;
    }

    function _parseStreamLine(line) {
        if (line.length === 0) return;
        // SSE: lines start with "data: "
        const trimmed = line.startsWith("data: ") ? line.slice(6) : line;
        if (trimmed === "[DONE]") {
            _finish();
            return;
        }
        try {
            const obj = JSON.parse(trimmed);
            if (obj.message && obj.message.content) {
                responseBuffer += obj.message.content;
            }
            if (obj.done) {
                _finish();
            }
        } catch (e) {
            // incomplete JSON fragment — accumulate
            _streamBuf += trimmed;
        }
    }

    function _finish() {
        isRunning = false;
        const result = responseBuffer;
        responseBuffer = "";
        completed(result);
    }

    function refreshModels() {
        if (!available) return;
        modelsProc.command = ["curl", "-s", "--max-time", "10",
            root.endpoint + "/api/tags"];
        modelsProc.running = true;
    }

    function _detectEndpoint() {
        detectProc.command = ["curl", "-s", "--max-time", "3",
            "--connect-timeout", "2",
            "http://localhost:11434/api/tags"];
        detectProc.running = true;
    }

    // boot probe
    Component.onCompleted: {
        // try to reach Ollama at default endpoint
        _detectEndpoint();
    }

    Process {
        id: detectProc
        stdout: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                try {
                    const data = JSON.parse(this.text);
                    if (data.models) {
                        root._endpointOk = true;
                        if (root.provider === "ollama" && root.endpoint.length === 0)
                            ShellState.set("aiEndpoint", "http://localhost:11434");
                        root.models = data.models.map(m => m.name || m.model);
                        if (root.model.length === 0 && root.models.length > 0)
                            ShellState.set("aiModel", root.models[0]);
                        root.modelsRefreshed();
                    }
                } catch (e) {
                    root._endpointOk = false;
                    root.error = "Ollama not detected on localhost:11434";
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                root._probed = true;
                root._endpointOk = false;
            }
        }
    }

    Process {
        id: chatProc
        stdout: StdioCollector {
            onStreamFinished: {
                // flush any remaining buffer
                const lines = root._streamBuf.split("\n");
                for (let i = 0; i < lines.length; i++)
                    root._parseStreamLine(lines[i]);
                if (root.isRunning)
                    root._finish();
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0 && root.isRunning) {
                    root.error = this.text.trim();
                    root.isRunning = false;
                }
            }
        }
    }

    Process {
        id: modelsProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    if (data.models) {
                        root.models = data.models.map(m => m.name || m.model);
                        root.modelsRefreshed();
                    }
                } catch (e) {}
            }
        }
        stderr: StdioCollector {}
    }

    // Stream processor — reads curl's stdout incrementally for SSE
    // The StdioCollector buffers until the process exits, so for streaming
    // we parse on each line. Process uses separate stdout handler above.
}
