import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."

// Emoji / kaomoji picker (PH.11) — JP-first categories, click copies to the
// selection (wl-copy) and dismisses with a toast. Themed like the launcher.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    readonly property bool open: ShellState.emojiOpen

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.open || hideDelay.running
    mask: Region {
        item: root.open ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: 560
    readonly property int padX: Theme.sp4

    property int catIdx: 0

    readonly property var categories: [
        { id: "faces", label: "FACES", jp: "顔", items: ["😀", "😂", "🥹", "😊", "😍", "🤔", "😎", "🥲", "😴", "🤯", "😭", "🙃", "😇", "🥳", "😐", "🙄", "🤝", "👀", "🔥", "💀"] },
        { id: "kaomoji", label: "KAOMOJI", jp: "顔文字", items: ["(・ω・)", "(≧▽≦)", "(｡•̀ᴗ-)✧", "(◕‿◕)", "ヽ(・∀・)ﾉ", "(╯°□°)╯", "(´･ω･`)", "¯\\_(ツ)_/¯", "(⌐■_■)", "(¬‿¬)", "(>_<)", "(T_T)", "(＾▽＾)", "(*^▽^*)", "(・∀・)", "ノ( ゜-゜ノ)"] },
        { id: "symbols", label: "SYMBOLS", jp: "記号", items: ["◼", "◻", "▲", "▼", "◆", "◇", "●", "○", "★", "☆", "☐", "☒", "▁", "▔", "◢", "◣", "◤", "◥", "╱", "╳", "+", "×", "→", "←"] },
        { id: "hearts", label: "HEARTS", jp: "心", items: ["❤", "💚", "💙", "💜", "🖤", "🤍", "💛", "🧡", "♥", "♡", "💕", "💔", "❤‍🔥", "💯", "✨", "🌸", "⭐", "☾", "☀", "⚡"] }
    ]

    readonly property var cat: categories[Math.max(0, Math.min(catIdx, categories.length - 1))]

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    onOpenChanged: if (!root.open)
        hideDelay.restart()

    function copy(s) {
        // wl-copy is an optional backend — never claim success it can't deliver
        if (!_wlCopyOk) {
            Notify.announce("EMOJI", "copy unavailable (install wl-clipboard)", 2);
            return;
        }
        copyProc.command = ["sh", "-c", "printf '%s' '" + s.replace(/'/g, "'\\''") + "' | wl-copy"];
        copyProc.running = true;
    }

    property bool _wlCopyOk: false

    Process {
        id: wlProbe

        command: ["sh", "-c", "command -v wl-copy >/dev/null 2>&1 && echo yes || echo no"]
        stdout: StdioCollector {
            onStreamFinished: {
                root._wlCopyOk = text.trim() === "yes";
                if (!root._wlCopyOk)
                    Health.report("wl-clipboard", "emoji copy unavailable (install wl-clipboard)");
            }
        }
    }

    Component.onCompleted: wlProbe.running = true

    Process {
        id: copyProc

        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: code => {
            if (code === 0) {
                Notify.announce("EMOJI", "copied to selection", 1);
                ShellState.closeEmoji();
            } else {
                Notify.announce("EMOJI", "copy failed", 2);
            }
        }
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeEmoji()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeEmoji()
        }

        YSurface {

            spawnId: "emoji"
            id: surface

            open: root.open
            anchorX: "center"
            cardW: root.cardW
            cardH: 420

            // ---- header ----
            Item {
                x: root.padX
                y: 0
                width: surface.width - root.padX * 2 - 1
                height: Theme.headH

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "EMOJI // KAOMOJI"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                YButton {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    width: 30
                    label: "×"
                    onClicked: ShellState.closeEmoji()
                }
            }

            Rectangle {
                x: root.padX
                y: Theme.headH
                width: surface.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            // ---- category strip ----
            Row {
                x: root.padX
                y: Theme.headH + Theme.sp3
                spacing: Theme.sp1

                Repeater {
                    model: root.categories

                    delegate: YButton {
                        required property int index
                        required property var modelData

                        tone: root.catIdx === index ? "acid" : "default"
                        label: modelData.label
                        onClicked: root.catIdx = index
                    }
                }
            }

            // ---- symbol grid ----
            Flickable {
                x: root.padX
                y: Theme.headH + Theme.sp3 + Theme.ctlH + Theme.sp2
                width: surface.width - root.padX * 2 - 1
                height: surface.height - y - Theme.footH - Theme.sp2
                clip: true
                contentWidth: width
                contentHeight: grid.height
                boundsBehavior: Flickable.StopAtBounds

                FastWheel {
                }

                Flow {
                    id: grid

                    width: parent.width
                    spacing: Theme.sp2

                    Repeater {
                        model: root.cat.items

                        delegate: Rectangle {
                            id: sym

                            required property var modelData

                            width: 54
                            height: 54
                            clip: true
                            color: symArea.containsMouse ? Theme.surface : Theme.bg
                            border.width: 1
                            border.color: symArea.containsMouse ? Theme.lineStrong : Theme.hairline
                            scale: symArea.containsMouse ? 1.12 : 1.0

                            Behavior on scale {
                                NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                            }

                            Text {
                                anchors.centerIn: parent
                                width: parent.width - Theme.sp2
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                text: sym.modelData
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: sym.modelData.length > 2 ? Theme.fsBody : Math.round(Theme.fsDisplay * 1.2)
                            }

                            MouseArea {
                                id: symArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                // close happens in copyProc.onExited on success only
                                onClicked: root.copy(sym.modelData)
                            }
                        }
                    }
                }
            }

            // ---- footer ----
            Text {
                x: root.padX
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Theme.sp2
                text: "CLICK COPIES · ESC CLOSE"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.letterSpacing: 1.5
            }
        }
    }
}
