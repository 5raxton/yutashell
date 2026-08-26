import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"

// ChatSidebar — conversational AI panel with message bubbles, markdown
// rendering, streaming tokens, model selector. Opened via IPC `ai chat`.
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
    visible: ShellState.aiChatOpen || hideDelay.running
    mask: Region {
        item: ShellState.aiChatOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.aiChatOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(560, contentRoot.width - Theme.outerPad * 2)
    readonly property int cardH: Math.min(640, contentRoot.height - Theme.outerPad * 2)

    // conversation messages: [{ role: "user"|"assistant", content: string }]
    property var _conversation: []
    // current streaming content being built
    property string _streamingContent: ""

    Timer {
        id: hideDelay
        interval: Theme.lingerMs
    }

    Connections {
        target: ShellState
        function onAiChatOpenChanged() {
            if (!ShellState.aiChatOpen)
                hideDelay.restart();
            else
                chatInput.forceFocus();
        }
    }

    Connections {
        target: AiService
        function onCompleted(response) {
            _conversation.push({ role: "assistant", content: response });
            _conversationChanged();
            _streamingContent = "";
        }
        function onResponseBufferChanged() {
            if (AiService.isRunning) {
                _streamingContent = AiService.responseBuffer;
            }
        }
    }

    Item {
        id: contentRoot
        anchors.fill: parent
        focus: ShellState.aiChatOpen

        Keys.onEscapePressed: ShellState.closeAiChat()

        YClickAway {
            id: clickAway
            onOutsideClicked: ShellState.closeAiChat()
        }

        YSurface {
            spawnId: "ai"
            open: ShellState.aiChatOpen
            cascade: bodyCol
            anchorX: "right"
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

                    Text {
                        text: "AI CHAT"
                        font.pixelSize: Theme.fsMicro
                        font.family: Theme.fontFamily
                        color: Theme.ink
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: 1; height: 1 }

                    Repeater {
                        model: AiService.models.length > 1 ? AiService.models : []

                        YButton {
                            required property string modelData
                            label: modelData
                            tone: modelData === AiService.model ? "acid" : "default"
                            onClicked: ShellState.set("aiModel", modelData)
                        }
                    }

                    YButton {
                        label: "CLEAR"
                        onClicked: {
                            root._conversation = [];
                            AiService.clearHistory();
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 1
                    color: Theme.lineStrong
                }

                // message list
                Flickable {
                    id: chatFlick
                    width: parent.width
                    height: root.cardH - chatInputRow.height - Theme.sp3 * 4 - 40
                    clip: true
                    contentHeight: chatCol.height
                    flickableDirection: Flickable.VerticalFlick
                    FastWheel {}

                    Column {
                        id: chatCol
                        width: parent.width
                        spacing: Theme.sp3

                        Repeater {
                            model: root._conversation.length + (AiService.isRunning ? 1 : 0)

                            Rectangle {
                                required property int index
                                property bool isUser: index < root._conversation.length && root._conversation[index].role === "user"
                                property string msgContent: {
                                    if (index < root._conversation.length)
                                        return root._conversation[index].content;
                                    return root._streamingContent;
                                }

                                width: chatCol.width
                                height: Math.max(msgText.height + Theme.sp3 * 2, 36)
                                color: isUser ? Theme.acid + "18" : Theme.bgAlt
                                radius: Theme.sp2
                                border.width: 1
                                border.color: Theme.line

                                Column {
                                    anchors {
                                        left: parent.left; right: parent.right
                                        margins: Theme.sp3
                                        verticalCenter: parent.verticalCenter
                                    }
                                    spacing: Theme.sp1

                                    Text {
                                        text: isUser ? "YOU" : "YUTA"
                                        font.pixelSize: Theme.fsMicro
                                        font.family: Theme.fontFamily
                                        color: isUser ? Theme.acid : Theme.muted
                                        font.weight: Font.Bold
                                    }

                                    Text {
                                        id: msgText
                                        width: parent.width
                                        text: msgContent
                                        color: Theme.ink
                                        font.pixelSize: Theme.fsBody
                                        wrapMode: TextEdit.Wrap
                                        textFormat: TextEdit.MarkdownText
                                    }
                                }
                            }
                        }

                        // auto-scroll spacer
                        Item { width: 1; height: 1 }
                    }
                }

                // input row
                Row {
                    id: chatInputRow
                    width: parent.width
                    spacing: Theme.sp2

                    YField {
                        id: chatInput
                        width: parent.width - chatSendBtn.width - Theme.sp2
                        placeholder: AiService.isRunning ? "AI is typing..." : "Type a message..."
                        enabled: !AiService.isRunning
                        Keys.onReturnPressed: root._sendChat()
                        Keys.onEnterPressed: root._sendChat()
                    }

                    YButton {
                        id: chatSendBtn
                        label: ">"
                        enabled: !AiService.isRunning && chatInput.text.trim().length > 0
                        onClicked: root._sendChat()
                    }
                }
            }
        }
    }

    function _sendChat() {
        const text = chatInput.text.trim();
        if (text.length === 0 || AiService.isRunning) return;
        chatInput.text = "";
        _conversation.push({ role: "user", content: text });
        _conversationChanged();

        const ctx = AiContext.buildContext();
        const systemPrompt = "You are YUTA, an intelligent desktop shell assistant. " +
            "You help with desktop control, coding, and general questions. " +
            "Use markdown for formatting. Be concise but helpful.\n\n" +
            "Desktop state:\n" + ctx;

        // send full conversation
        const msgs = _conversation.map(m => ({ role: m.role, content: m.content }));
        AiService.chat(msgs, systemPrompt);
    }
}
