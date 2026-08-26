import Quickshell
import Quickshell.Io
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"

// ProcessKiller — PH.06.3 process monitor + killer panel. Search field filters
// `ps aux` output; each row shows PID, user, CPU%, MEM%, command. Kill button
// sends SIGTERM; shift+click sends SIGKILL (with confirmation).
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
    visible: ShellState.processesOpen || hideDelay.running
    mask: Region {
        item: ShellState.processesOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.processesOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: 520
    readonly property int padX: Theme.sp4
    readonly property int contentW: cardW - padX * 2 - 1

    property var processes: []
    property string filter: ""
    property var _killTarget: null

    readonly property var filtered: {
        if (filter.length === 0)
            return processes;
        const q = filter.toLowerCase();
        return processes.filter(p => (p.cmd.toLowerCase().indexOf(q) >= 0) || (p.user.toLowerCase().indexOf(q) >= 0) || String(p.pid).indexOf(q) >= 0);
    }

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    Connections {
        target: ShellState

        function onProcessesOpenChanged() {
            if (ShellState.processesOpen)
                refreshTimer.restart();
            if (!ShellState.processesOpen)
                hideDelay.restart();
        }
    }

    Timer {
        id: refreshTimer

        interval: 3000
        running: ShellState.processesOpen
        repeat: true
        triggeredOnStart: true
        onTriggered: psProbe.running = true
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeProcesses()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeProcesses()
        }

        YSurface {
            spawnId: "processes"
            open: ShellState.processesOpen
            anchorX: "left"
            cardW: root.cardW
            cardH: Math.min(600, contentRoot.height - Theme.barHeight - Theme.outerPad * 2)

            Column {
                x: root.padX
                y: 0
                width: parent.width - root.padX * 2 - 1
                spacing: Theme.sp2

                // header
                Item {
                    width: parent.width
                    height: Theme.headH

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "PROCESSES"
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBody
                        font.weight: Font.ExtraBold
                        font.letterSpacing: 1.5
                    }

                    YChip {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        label: root.filtered.length + ""
                        tone: "outline"
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.hairline
                }

                // search field
                YField {
                    id: searchField

                    width: parent.width
                    placeholder: Theme.jpEnabled ? "検索…" : "search processes…"
                    navKeys: true

                    onAccepted: root.filter = text

                    Component.onCompleted: if (ShellState.processesOpen)
                        forceFocus()

                    Connections {
                        target: ShellState
                        function onProcessesOpenChanged() {
                            if (ShellState.processesOpen)
                                searchField.forceFocus();
                        }
                    }

                    // property to track text changes for onTextEdited
                    property string lastText: ""
                    Timer {
                        interval: 150
                        running: true
                        repeat: true
                        onTriggered: {
                            if (searchField.text !== searchField.lastText) {
                                searchField.lastText = searchField.text;
                                root.filter = searchField.text;
                            }
                        }
                    }
                }

                // column headers
                Row {
                    width: parent.width
                    spacing: 0

                    Text { width: 52; text: "PID"; color: Theme.faint; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.letterSpacing: 1 }
                    Text { width: 50; text: "USER"; color: Theme.faint; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.letterSpacing: 1 }
                    Text { width: 44; text: "CPU"; color: Theme.faint; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.letterSpacing: 1 }
                    Text { width: 44; text: "MEM"; color: Theme.faint; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.letterSpacing: 1 }
                    Text { text: "COMMAND"; color: Theme.faint; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.letterSpacing: 1 }
                }

                // process list
                Flickable {
                    width: parent.width
                    height: Math.max(200, root.cardH - 180)
                    clip: true
                    contentWidth: width
                    contentHeight: procCol.height

                    FastWheel {}

                    Column {
                        id: procCol

                        width: parent.width
                        spacing: 1

                        Repeater {
                            model: root.filtered

                            delegate: Rectangle {
                                id: procRow

                                required property int index
                                required property var modelData

                                width: procCol.width
                                height: 22
                                color: hArea.containsMouse ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.04) : "transparent"

                                Row {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 0

                                    Text { width: 52; text: procRow.modelData.pid; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro }
                                    Text { width: 50; text: procRow.modelData.user.slice(0, 8); color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro }
                                    Text { width: 44; text: procRow.modelData.cpu + "%"; color: procRow.modelData.cpu > 50 ? Theme.alert : procRow.modelData.cpu > 20 ? Theme.acid : Theme.ink; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: procRow.modelData.cpu > 50 ? Font.Bold : Font.Normal }
                                    Text { width: 44; text: procRow.modelData.mem + "%"; color: procRow.modelData.mem > 50 ? Theme.alert : procRow.modelData.mem > 20 ? Theme.acid : Theme.ink; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: procRow.modelData.mem > 50 ? Font.Bold : Font.Normal }
                                    Text { width: parent.width - 190; text: procRow.modelData.cmd; color: Theme.ink; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; elide: Text.ElideRight }
                                }

                                // kill button on hover
                                YButton {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.rightMargin: Theme.sp1
                                    visible: hArea.containsMouse
                                    label: "KILL"
                                    tone: "danger"
                                    onClicked: {
                                        if (mouse === undefined || !mouse)
                                            killProc(procRow.modelData.pid, false);
                                        else if (mouse.modifiers & Qt.ShiftModifier)
                                            killProc(procRow.modelData.pid, true);
                                        else
                                            killProc(procRow.modelData.pid, false);
                                    }
                                }

                                MouseArea {
                                    id: hArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function killProc(pid, sigkill) {
        if (sigkill) {
            killCmd.command = ["kill", "-9", String(pid)];
        } else {
            killCmd.command = ["kill", "-15", String(pid)];
        }
        killCmd.running = true;
        // refresh after a short delay
        refreshDelay.restart();
    }

    Timer {
        id: refreshDelay

        interval: 500
        onTriggered: psProbe.running = true
    }

    Process {
        id: psProbe

        stdout: StdioCollector {
            onStreamFinished: root._parsePs(this.text)
        }
    }

    function _parsePs(text) {
        const lines = text.trim().split("\n");
        const out = [];
        for (let i = 1; i < lines.length; i++) {
            const f = lines[i].trim().split(/\s+/);
            if (f.length < 11)
                continue;
            out.push({
                pid: parseInt(f[1]),
                user: f[0],
                cpu: parseFloat(f[2]),
                mem: parseFloat(f[3]),
                cmd: f.slice(10).join(" ").slice(0, 80)
            });
        }
        root.processes = out;
    }

    Process {
        id: killCmd

        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Component.onCompleted: {
        if (ShellState.processesOpen)
            psProbe.running = true;
    }
}
