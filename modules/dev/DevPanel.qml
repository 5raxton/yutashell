import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."
import "../net"

// DevPanel — unified developer command center surface (PH.04). Tabbed views
// for Git, Docker, CI/CD, Logs, Tmux, and Ports. Each tab shows its service's
// live data with action buttons.
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
    visible: ShellState.devOpen || hideDelay.running
    mask: Region {
        item: ShellState.devOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.devOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(800, contentRoot.width - Theme.outerPad * 2)
    readonly property int cardH: Math.min(580, contentRoot.height - Theme.outerPad * 2)

    property int activeTab: 0
    readonly property var tabs: [
        { id: "git", label: "GIT", icon: "⎇" },
        { id: "docker", label: "DOCKER", icon: "🐳" },
        { id: "cicd", label: "CI/CD", icon: "✓" },
        { id: "logs", label: "LOGS", icon: "≡" },
        { id: "tmux", label: "TMUX", icon: "⊞" },
        { id: "ports", label: "PORTS", icon: "⇄" }
    ]

    Timer {
        id: hideDelay
        interval: Theme.lingerMs
    }

    Connections {
        target: ShellState
        function onDevOpenChanged() {
            if (ShellState.devOpen) hideDelay.stop();
            else hideDelay.restart();
        }
    }

    YClickAway {
        id: clickAway
        anchors.fill: parent
        onClicked: ShellState.closeDev()
    }

    Item {
        id: contentRoot
        anchors.fill: parent

        YSurface {
            anchors.centerIn: parent
            open: ShellState.devOpen
            spawnId: "dev"
            cardW: root.cardW
            cardH: root.cardH

            Column {
                anchors.fill: parent
                anchors.margins: Theme.sp3
                spacing: Theme.sp2

                // header
                Text {
                    text: "DEVELOPER COMMAND CENTER"
                    font.pixelSize: Theme.fsMicro
                    font.family: Theme.fontFamily
                    color: Theme.ink
                    font.weight: Font.DemiBold
                }

                // tab selector
                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: root.tabs

                        Rectangle {
                            required property var modelData
                            required property int index
                            property bool isActive: root.activeTab === index
                            width: tabRow.width + 16
                            height: 26
                            radius: Theme.radius
                            color: isActive ? Theme.acid + "22" : Theme.bg
                            border.width: 1
                            border.color: isActive ? Theme.acid : Theme.hairline

                            Row {
                                id: tabRow
                                anchors.centerIn: parent
                                spacing: 4

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.icon
                                    color: isActive ? Theme.acid : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: isActive ? Theme.acid : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeTab = index
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 1
                    color: Theme.lineStrong
                }

                // tab content
                Flickable {
                    width: parent.width
                    height: parent.height - 80 - Theme.sp2 * 3
                    clip: true
                    contentHeight: tabContent.height
                    flickableDirection: Flickable.VerticalFlick
                    FastWheel {}

                    Column {
                        id: tabContent
                        width: parent.width
                        spacing: Theme.sp2

                        // ---- GIT TAB ----
                        Column {
                            visible: root.activeTab === 0
                            width: parent.width
                            spacing: Theme.sp2

                            Row {
                                spacing: Theme.sp2
                                Text {
                                    text: GitService.isRepo ? GitService.branch : "No repo detected"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsTitle
                                    font.weight: Font.Bold
                                }
                                Text {
                                    visible: GitService.isRepo && GitService.ahead > 0
                                    text: "↑" + GitService.ahead
                                    color: Theme.acid
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    visible: GitService.isRepo && GitService.behind > 0
                                    text: "↓" + GitService.behind
                                    color: Theme.acid
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Text {
                                visible: GitService.cwd.length > 0
                                text: GitService.cwd
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                elide: Text.ElideRight
                                width: parent.width
                            }

                            Row {
                                visible: GitService.isRepo
                                spacing: Theme.sp3

                                Rectangle { width: statW2(GitService.staged); height: 28; radius: 4; color: Theme.acid + "18"; border.width: 1; border.color: Theme.acid
                                    property int val: GitService.staged; function statW2(v) { return v > 0 ? 80 : 60 }
                                    Text { anchors.centerIn: parent; text: "STAGED " + GitService.staged; color: GitService.staged > 0 ? Theme.acid : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                }
                                Rectangle { width: 80; height: 28; radius: 4; color: Theme.bg; border.width: 1; border.color: Theme.hairline
                                    Text { anchors.centerIn: parent; text: "DIRTY " + GitService.dirty; color: GitService.dirty > 0 ? Theme.acid : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                }
                                Rectangle { width: 80; height: 28; radius: 4; color: Theme.bg; border.width: 1; border.color: Theme.hairline
                                    Text { anchors.centerIn: parent; text: "NEW " + GitService.untracked; color: GitService.untracked > 0 ? Theme.acid : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                }
                            }

                            Text {
                                visible: !GitService.available
                                text: "git not installed"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                            }
                        }

                        // ---- DOCKER TAB ----
                        Column {
                            visible: root.activeTab === 1
                            width: parent.width
                            spacing: Theme.sp2

                            Text {
                                text: DockerService.status || "No docker detected"
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                                font.weight: Font.Bold
                            }

                            Repeater {
                                model: DockerService.projects

                                Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 48
                                    radius: Theme.radius
                                    color: Theme.bg
                                    border.width: 1
                                    border.color: Theme.hairline

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: Theme.sp2
                                        spacing: Theme.sp2

                                        Rectangle {
                                            width: 8; height: 8; radius: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: modelData.running ? Theme.acid : Theme.muted
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 8 - Theme.sp2 - dockerBtns.width - Theme.sp2

                                            Text {
                                                text: modelData.name
                                                color: Theme.ink
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsLabel
                                                font.weight: Font.Bold
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }

                                            Text {
                                                text: modelData.containers + " containers · " + modelData.status
                                                color: Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsMicro
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }

                                        Row {
                                            id: dockerBtns
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4

                                            YButton {
                                                label: "RESTART"
                                                onClicked: DockerService.restartProject(modelData.name)
                                            }
                                            YButton {
                                                label: "STOP"
                                                tone: "danger"
                                                onClicked: DockerService.stopProject(modelData.name)
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: DockerService.projects.length === 0 && DockerService.available
                                text: "No compose projects found"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                            }

                            Text {
                                visible: !DockerService.available
                                text: "docker not installed"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                            }
                        }

                        // ---- CI/CD TAB ----
                        Column {
                            visible: root.activeTab === 2
                            width: parent.width
                            spacing: Theme.sp2

                            Row {
                                spacing: Theme.sp2

                                Text {
                                    text: CIService.status || "No CI repos configured"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item { width: 1; height: 1 }

                                YButton {
                                    label: "+ REPO"
                                    onClicked: CIService.addRepo("owner/repo")
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Repeater {
                                model: CIService.runs

                                Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 40
                                    radius: Theme.radius
                                    color: Theme.bg
                                    border.width: 1
                                    border.color: Theme.hairline

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: Theme.sp2
                                        spacing: Theme.sp2

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.conclusion === "success" ? "✓" : modelData.conclusion === "failure" ? "✗" : modelData.status === "in_progress" ? "…" : "—"
                                            color: modelData.conclusion === "success" ? Theme.acid : modelData.conclusion === "failure" ? "#ff4444" : Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsBody
                                            font.weight: Font.Bold
                                            width: 20
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 20 - ciBranch.width - Theme.sp2 * 2

                                            Text {
                                                text: modelData.name + " · " + modelData.repo
                                                color: Theme.ink
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsMicro
                                                elide: Text.ElideRight
                                                width: parent.width
                                            }
                                        }

                                        Text {
                                            id: ciBranch
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: modelData.branch
                                            color: Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsMicro
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: CIService.runs.length === 0 && CIService.available
                                text: "No runs found. Add a repo above."
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                            }

                            Text {
                                visible: !CIService.available
                                text: "gh CLI not installed"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                            }
                        }

                        // ---- LOGS TAB ----
                        Column {
                            visible: root.activeTab === 3
                            width: parent.width
                            spacing: Theme.sp2

                            Row {
                                spacing: Theme.sp2

                                Repeater {
                                    model: ["system", "hyprland"]

                                    Rectangle {
                                        required property string modelData
                                        property bool isActive: LogTailer.source === modelData
                                        width: logTabLabel.implicitWidth + 16
                                        height: 24
                                        radius: 4
                                        color: isActive ? Theme.acid : Theme.bg
                                        border.width: 1
                                        border.color: isActive ? Theme.acid : Theme.hairline
                                        Text {
                                            id: logTabLabel
                                            anchors.centerIn: parent
                                            text: modelData.toUpperCase()
                                            color: isActive ? Theme.ink : Theme.muted
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold
                                        }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: LogTailer.setSource(modelData, "") }
                                    }
                                }

                                Item { width: 1; height: 1 }

                                YButton {
                                    label: LogTailer.paused ? "RESUME" : "PAUSE"
                                    onClicked: LogTailer.paused = !LogTailer.paused
                                }
                                YButton {
                                    label: "CLEAR"
                                    onClicked: LogTailer.clear()
                                }
                            }

                            Rectangle {
                                width: parent.width
                                height: Math.min(400, parent.height - 50)
                                radius: Theme.radius
                                color: Qt.rgba(0, 0, 0, 0.3)
                                border.width: 1
                                border.color: Theme.hairline

                                Flickable {
                                    id: logFlick
                                    anchors.fill: parent
                                    anchors.margins: Theme.sp2
                                    clip: true
                                    contentHeight: logCol.height
                                    flickableDirection: Flickable.VerticalFlick
                                    FastWheel {}

                                    Column {
                                        id: logCol
                                        width: parent.width
                                        spacing: 2

                                        Repeater {
                                            model: LogTailer.lines

                                            Text {
                                                required property var modelData
                                                width: logFlick.width
                                                text: modelData.text || ""
                                                color: modelData.text && modelData.text.indexOf("ERROR") >= 0 ? Theme.acid
                                                    : modelData.text && modelData.text.indexOf("WARN") >= 0 ? "#ccaa44"
                                                    : Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsMicro
                                                wrapMode: Text.Wrap
                                                maximumLineCount: 3
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // ---- TMUX TAB ----
                        Column {
                            visible: root.activeTab === 4
                            width: parent.width
                            spacing: Theme.sp2

                            Row {
                                spacing: Theme.sp2

                                Text {
                                    text: TmuxService.status || "No tmux/zellij detected"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item { width: 1; height: 1 }

                                YButton {
                                    label: "+ NEW"
                                    onClicked: TmuxService.newSession("new-" + Math.floor(Date.now() / 1000) % 1000)
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            Repeater {
                                model: TmuxService.sessions

                                Rectangle {
                                    required property var modelData
                                    width: parent.width
                                    height: 44
                                    radius: Theme.radius
                                    color: modelData.attached ? Theme.acid + "12" : Theme.bg
                                    border.width: 1
                                    border.color: modelData.attached ? Theme.acid : Theme.hairline

                                    Row {
                                        anchors.fill: parent
                                        anchors.margins: Theme.sp2
                                        spacing: Theme.sp2

                                        Rectangle {
                                            width: 8; height: 8; radius: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            color: modelData.attached ? Theme.acid : Theme.muted
                                        }

                                        Column {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - 8 - Theme.sp2 * 2 - tmuxAttach.width - tmuxKill.width - Theme.sp2 * 2

                                            Text {
                                                text: modelData.name + (modelData.via === "zellij" ? " (zellij)" : "")
                                                color: Theme.ink
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsLabel
                                                font.weight: modelData.attached ? Font.Bold : Font.Normal
                                            }

                                            Text {
                                                visible: modelData.windows > 0
                                                text: modelData.windows + " windows"
                                                color: Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsMicro
                                            }
                                        }

                                        YButton {
                                            id: tmuxAttach
                                            label: modelData.attached ? "ATTACHED" : "ATTACH"
                                            tone: modelData.attached ? "acid" : "default"
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: {
                                                if (!modelData.attached)
                                                    TmuxService.attachSession(modelData.name);
                                            }
                                        }

                                        YButton {
                                            id: tmuxKill
                                            label: "KILL"
                                            tone: "danger"
                                            anchors.verticalCenter: parent.verticalCenter
                                            onClicked: TmuxService.killSession(modelData.name)
                                        }
                                    }
                                }
                            }

                            Text {
                                visible: TmuxService.sessions.length === 0 && (TmuxService._hasTmux || TmuxService._hasZellij)
                                text: "No active sessions"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                            }
                        }

                        // ---- PORTS TAB ----
                        Column {
                            visible: root.activeTab === 5
                            width: parent.width
                            spacing: Theme.sp2

                            Row {
                                spacing: Theme.sp2

                                Text {
                                    text: PortService.status
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.Bold
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Item { width: 1; height: 1 }

                                YButton {
                                    label: "REFRESH"
                                    onClicked: PortService.refresh()
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // header
                            Row {
                                width: parent.width
                                spacing: 0
                                Text { width: 60; text: "PORT"; color: Theme.acid; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                Text { width: 120; text: "ADDRESS"; color: Theme.acid; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                Text { width: parent.width - 60 - 120; text: "PROCESS"; color: Theme.acid; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                            }

                            Rectangle { width: parent.width; height: 1; color: Theme.hairline }

                            Repeater {
                                model: PortService.ports

                                Row {
                                    required property var modelData
                                    width: parent.width
                                    height: 24

                                    Text {
                                        width: 60
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.port
                                        color: modelData.addr !== "127.0.0.1" && modelData.addr !== "::1" && modelData.addr !== "*" ? Theme.acid : Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        font.weight: Font.Bold
                                    }

                                    Text {
                                        width: 120
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.addr
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        width: parent.width - 60 - 120
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.process + (modelData.pid > 0 ? " (" + modelData.pid + ")" : "")
                                        color: Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            Text {
                                visible: PortService._exposed.length > 0
                                width: parent.width
                                text: "⚠ " + PortService._exposed.length + " port(s) exposed to network"
                                color: Theme.acid
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                                font.weight: Font.Bold
                                topPadding: Theme.sp2
                            }
                        }
                    }
                }
            }
        }
    }
}
