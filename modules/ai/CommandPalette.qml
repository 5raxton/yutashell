import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."
import "../session"

// CommandPalette — AI-powered command surface. Natural language input → AI
// generates Hyprland dispatch, shell command, IPC call, or plain answer.
// Opened via Ctrl+Space or IPC `ai palette`.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: ShellState.aiOpen || hideDelay.running
    mask: Region {
        item: ShellState.aiOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.aiOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(640, contentRoot.width - Theme.outerPad * 2)
    readonly property int cardH: Math.min(520, contentRoot.height - Theme.outerPad * 2)

    // command history (up-arrow navigation)
    property var _history: []
    property int _historyIdx: -1

    Timer {
        id: hideDelay
        interval: Theme.lingerMs
    }

    Connections {
        target: ShellState
        function onAiOpenChanged() {
            if (!ShellState.aiOpen)
                hideDelay.restart();
            else
                input.forceFocus();
        }
    }

    Item {
        id: contentRoot
        anchors.fill: parent
        focus: ShellState.aiOpen

        Keys.onEscapePressed: ShellState.closeAi()

        YClickAway {
            id: clickAway
            onOutsideClicked: ShellState.closeAi()
        }

        YSurface {
            spawnId: "ai"
            open: ShellState.aiOpen
            cascade: bodyCol
            anchorX: "center"
            cardW: root.cardW
            cardH: root.cardH

            Column {
                id: bodyCol
                width: parent.width
                spacing: Theme.sp3

                // header
                Row {
                    width: parent.width
                    spacing: Theme.sp3

                    Rectangle {
                        width: 8; height: 8; radius: 4
                        color: AiService.available ? Theme.acid : Theme.muted
                        anchors.verticalCenter: label.verticalCenter
                    }

                    Text {
                        id: label
                        text: "AI COMMAND PALETTE"
                        font.pixelSize: Theme.fsMicro
                        font.family: Theme.fontFamily
                        color: Theme.ink
                        font.weight: Font.DemiBold
                    }

                    Item { width: 1; height: 1 }

                    Text {
                        text: AiService.model || "no model"
                        font.pixelSize: Theme.fsMicro
                        font.family: Theme.fontFamily
                        color: Theme.muted
                    }

                    Text {
                        text: AiService.provider.toUpperCase()
                        font.pixelSize: Theme.fsMicro
                        font.family: Theme.fontFamily
                        color: Theme.acid
                        font.weight: Font.Bold
                    }
                }

                Rectangle {
                    width: parent.width; height: 1
                    color: Theme.lineStrong
                }

                // model selector (when multiple models available)
                Row {
                    visible: AiService.models.length > 1
                    width: parent.width
                    spacing: Theme.sp2

                    Text {
                        text: "MODEL:"
                        font.pixelSize: Theme.fsMicro
                        font.family: Theme.fontFamily
                        color: Theme.muted
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Repeater {
                        model: AiService.models

                        YButton {
                            required property string modelData
                            label: modelData
                            tone: modelData === AiService.model ? "acid" : "default"
                            onClicked: ShellState.set("aiModel", modelData)
                        }
                    }
                }

                // response area (scrollable)
                Flickable {
                    id: responseFlick
                    width: parent.width
                    height: root.cardH - inputRow.height - Theme.sp3 * 4 - 60
                    clip: true
                    contentHeight: responseText.height
                    flickableDirection: Flickable.VerticalFlick
                    FastWheel {}

                    TextEdit {
                        id: responseText
                        width: parent.width
                        text: {
                            if (AiService.isRunning && AiService.responseBuffer.length === 0)
                                return "Thinking...";
                            if (AiService.error.length > 0)
                                return "Error: " + AiService.error;
                            if (AiService.responseBuffer.length > 0)
                                return AiService.responseBuffer;
                            return "Type a command or question.\n\nExamples:\n  \"focus the browser window\"\n  \"set volume to 50%\"\n  \"switch to workspace 3\"\n  \"what time is it?\"";
                        }
                        color: Theme.ink
                        font.pixelSize: Theme.fsBody
                        font.family: Theme.fontFamily
                        wrapMode: TextEdit.Wrap
                        readOnly: true
                        selectByMouse: true
                        selectedTextColor: Theme.acid
                        textFormat: TextEdit.MarkdownText
                    }
                }

                // action buttons (when AI suggests an action)
                Row {
                    id: actionRow
                    visible: _hasAction
                    width: parent.width
                    spacing: Theme.sp2

                    property bool _hasAction: {
                        if (!AiService.isRunning && AiService.responseBuffer.length > 0) {
                            return _isActionResponse(AiService.responseBuffer);
                        }
                        return false;
                    }

                    YButton {
                        label: "EXECUTE"
                        onClicked: root._executeAction(AiService.responseBuffer)
                    }

                    YButton {
                        label: "COPY"
                        onClicked: {
                            execClip.command = ["wl-copy", AiService.responseBuffer];
                            execClip.running = true;
                        }
                    }
                }

                // input row
                Row {
                    id: inputRow
                    width: parent.width
                    spacing: Theme.sp2

                    YField {
                        id: input
                        width: parent.width - sendBtn.width - (AiService.isRunning ? stopBtn.width + Theme.sp2 : 0) - Theme.sp2
                        placeholder: AiService.isRunning ? "AI is thinking..." : "Ask anything..."
                        enabled: !AiService.isRunning
                        Keys.onReturnPressed: root._send()
                        Keys.onEnterPressed: root._send()
                        Keys.onUpPressed: {
                            if (_history.length > 0) {
                                _historyIdx = Math.min(_historyIdx + 1, _history.length - 1);
                                text = _history[_history.length - 1 - _historyIdx];
                            }
                        }
                        Keys.onDownPressed: {
                            if (_historyIdx > 0) {
                                _historyIdx--;
                                text = _history[_history.length - 1 - _historyIdx];
                            } else {
                                _historyIdx = -1;
                                text = "";
                            }
                        }
                    }

                    YButton {
                        id: sendBtn
                        label: ">"
                        enabled: !AiService.isRunning && input.text.trim().length > 0
                        onClicked: root._send()
                    }

                    YButton {
                        id: stopBtn
                        visible: AiService.isRunning
                        label: "STOP"
                        tone: "danger"
                        onClicked: {
                            chatKillProc.running = true;
                            AiService.isRunning = false;
                        }
                    }
                }
            }
        }
    }

    Process {
        id: execClip
        stdout: StdioCollector {}
    }

    Process {
        id: chatKillProc
        command: ["kill", "-9"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    function _send() {
        const text = input.text.trim();
        if (text.length === 0 || AiService.isRunning) return;
        _history.push(text);
        _historyIdx = -1;
        input.text = "";

        // build context and send
        const ctx = AiContext.buildContext();
        const systemPrompt = "You are YUTA, an intelligent desktop shell assistant for a Hyprland Wayland desktop. " +
            "You can control the shell via IPC commands. When the user asks you to do something on the desktop, " +
            "respond with the appropriate action type and parameters.\n\n" +
            "Current desktop state:\n" + ctx + "\n\n" +
            "Response format for actions:\n" +
            "- For Hyprland window operations: [DISPATCH] hl.dsp.xxx\n" +
            "- For shell commands: [SHELL] command\n" +
            "- For IPC calls: [IPC] target function args\n" +
            "- For answers: just answer naturally in markdown.\n" +
            "Always prefix action responses with the bracketed type on its own line.";

        const msgs = [{ role: "user", content: text }];
        AiService.chat(msgs, systemPrompt);
    }

    function _isActionResponse(text) {
        return text.startsWith("[DISPATCH]") || text.startsWith("[SHELL]") || text.startsWith("[IPC]");
    }

    function _executeAction(text) {
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim();
            if (line.startsWith("[DISPATCH]")) {
                const lua = line.slice(10).trim();
                if (lua.length > 0) {
                    Hyprland.dispatch(lua.startsWith("hl.") ? lua : "hl.dsp." + lua);
                }
                return;
            }
            if (line.startsWith("[SHELL]")) {
                const cmd = line.slice(7).trim();
                if (cmd.length > 0) {
                    shellExecProc.command = ["sh", "-c", cmd];
                    shellExecProc.running = true;
                }
                return;
            }
            if (line.startsWith("[IPC]")) {
                const spec = line.slice(5).trim();
                const parts = spec.split(/\s+/);
                if (parts.length >= 2) {
                    ipcExecProc.command = ["qs", "ipc", "call", parts[0], parts[1]].concat(parts.slice(2));
                    ipcExecProc.running = true;
                }
                return;
            }
        }
    }

    Process {
        id: shellExecProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: ipcExecProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }
}
