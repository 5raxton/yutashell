import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "ui"

PanelWindow {
    id: root

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: ShellState.panelOpen || hideDelay.running
    mask: Region {
        item: ShellState.panelOpen ? contentRoot : null
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int drawerW: 364
    readonly property int pad: 16
    readonly property int innerW: drawerW - pad * 2

    property int tabIndex: 0
    readonly property var tabs: ["APPEARANCE", "MODULES", "SYSTEM", "ABOUT"]

    Timer {
        id: hideDelay
        interval: 190
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: ShellState.panelOpen

        Keys.onEscapePressed: ShellState.closePanel()

        // ---- dim scrim ----
        Rectangle {
            id: scrim
            anchors.fill: parent
            color: "#000000"
            opacity: ShellState.panelOpen ? 0.55 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: ShellState.panelOpen
            onClicked: ShellState.closePanel()
        }

        // ---- drawer body ----
        Rectangle {
            id: drawer
            width: root.drawerW
            height: parent.height
            x: ShellState.panelOpen ? parent.width - width : parent.width
            color: Theme.bgAlt

            Behavior on x {
                NumberAnimation {
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }

            // left structure lines
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Theme.lineStrong
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                width: 2
                height: 26
                color: Theme.acid
            }

            // ---- header ----
            Item {
                id: header
                x: root.pad
                y: 14
                width: root.innerW
                height: 34

                Timer {
                    interval: 600
                    running: true
                    repeat: true
                    onTriggered: headerCursor.visible = !headerCursor.visible
                }

                Text {
                    id: headerTitle
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CONTROL.CORE //"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: 12
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    id: headerCursor
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: headerTitle.right
                    anchors.leftMargin: 4
                    width: 5
                    height: 13
                    color: Theme.acid
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    text: "V" + Theme.version
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: 8
                    font.letterSpacing: 1
                }

                Text {
                    anchors.bottom: parent.bottom
                    text: Theme.jpEnabled ? "SYS.SETTINGS // 設定" : "SYS.SETTINGS // SETTEI"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 7
                    font.letterSpacing: 2
                }
            }

            // ---- tab row ----
            Item {
                id: tabBar
                x: root.pad
                y: 56
                width: root.innerW
                height: 24

                Row {
                    anchors.fill: parent
                    spacing: 4

                    Repeater {
                        model: root.tabs

                        delegate: Rectangle {
                            id: tabBtn
                            required property int index
                            required property var modelData

                            readonly property bool isActive: root.tabIndex === index

                            width: (root.innerW - (root.tabs.length - 1) * 4) / root.tabs.length
                            height: parent.height
                            color: isActive ? Theme.acid : tabArea.containsMouse ? Theme.surface : "transparent"
                            border.width: isActive ? 0 : 1
                            border.color: tabArea.containsMouse ? Theme.lineStrong : Theme.hairline

                            Text {
                                anchors.centerIn: parent
                                text: tabBtn.modelData.toUpperCase()
                                color: tabBtn.isActive ? Theme.bg : tabArea.containsMouse ? Theme.ink : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 7
                                font.weight: tabBtn.isActive ? Font.Bold : Font.Normal
                                font.letterSpacing: 1
                            }

                            MouseArea {
                                id: tabArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.tabIndex = tabBtn.index
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                y: 86
                height: 1
                color: Theme.hairline
            }

            // ---- pages ----
            Flickable {
                id: pageScroll
                x: root.pad
                y: 98
                width: root.innerW
                height: parent.height - 98 - 30
                contentWidth: width
                contentHeight: pageHost.childrenRect.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Item {
                    id: pageHost
                    width: root.innerW

                    // ================= APPEARANCE =================
                    Column {
                        id: appearancePage
                        visible: root.tabIndex === 0
                        width: root.innerW
                        spacing: 12

                        SectionLabel {
                            width: parent.width
                            label: "SCHEME.PRESETS"
                        }

                        Grid {
                            columns: 2
                            spacing: 10

                            Repeater {
                                model: root.presetData

                                delegate: SwatchTile {
                                    required property var modelData

                                    width: (root.innerW - 10) / 2
                                    height: 64
                                    data_: modelData
                                    active: !Theme.followWallpaper && Theme.activeScheme === modelData.id
                                    onPicked: id => Theme.applyPreset(id)
                                }
                            }
                        }

                        SectionLabel {
                            width: parent.width
                            label: "WALLPAPER.INDEX // " + Wallpaper.entries.length + (Wallpaper.scanning ? " SCANNING" : "")
                        }

                        Text {
                            width: parent.width
                            visible: Wallpaper.entries.length === 0 && !Wallpaper.scanning
                            text: "no images indexed in ~/Pictures/Wallpapers"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                        }

                        Grid {
                            columns: 3
                            spacing: 6

                            Repeater {
                                model: Wallpaper.entries

                                delegate: WallTile {
                                    required property var modelData

                                    width: (root.innerW - 12) / 3
                                    height: 62
                                    path: modelData.path
                                    label: modelData.label
                                    active: Wallpaper.current === modelData.path
                                    onPicked: path => Wallpaper.apply(path)
                                }
                            }
                        }

                        Row {
                            spacing: 8

                            PanelButton {
                                width: root.innerW / 2 - 4
                                label: "RESCAN"
                                onClicked: Wallpaper.rescan()
                            }

                            PanelButton {
                                width: root.innerW / 2 - 4
                                label: "RANDOM"
                                onClicked: {
                                    if (Wallpaper.entries.length > 0)
                                        Wallpaper.apply(Wallpaper.entries[Math.floor(Math.random() * Wallpaper.entries.length)].path);
                                }
                            }
                        }

                        SectionLabel {
                            width: parent.width
                            label: "MATUGEN.TEMPLATES"
                        }

                        Repeater {
                            model: root.tplData

                            delegate: TemplateRow {
                                required property var modelData

                                width: parent.width
                                tplId: modelData.id
                                output: modelData.output
                                enabled_: modelData.enabled
                                onToggled: on => Wallpaper.setTemplateEnabled(modelData.id, on)
                                onRemoved: Wallpaper.removeTemplate(modelData.id)
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: addForm.visible ? addForm.height + 12 : 24
                            color: Theme.bg
                            border.width: 1
                            border.color: Theme.hairline

                            Text {
                                visible: !addForm.visible
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                text: "+ ADD.CUSTOM.TEMPLATE"
                                color: area.containsMouse ? Theme.acid : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.weight: Font.DemiBold
                                font.letterSpacing: 1.5

                                MouseArea {
                                    id: area
                                    anchors.fill: parent
                                    anchors.margins: -10
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: addForm.visible = true
                                }
                            }

                            Column {
                                id: addForm
                                visible: false
                                anchors.top: parent.top
                                anchors.margins: 6
                                anchors.left: parent.left
                                anchors.right: parent.right
                                spacing: 5

                                PathField {
                                    id: newTplId
                                    width: parent.width
                                    placeholder: "name (e.g. wezterm)"
                                }

                                PathField {
                                    id: newTplInput
                                    width: parent.width
                                    placeholder: "template input path"
                                }

                                PathField {
                                    id: newTplOutput
                                    width: parent.width
                                    placeholder: "output path"
                                }

                                Row {
                                    spacing: 6
                                    anchors.right: parent.right

                                    PanelButton {
                                        width: 56
                                        label: "ADD"
                                        onClicked: {
                                            if (Wallpaper.addTemplate(newTplId.text, newTplInput.text, newTplOutput.text, "")) {
                                                newTplId.text = "";
                                                newTplInput.text = "";
                                                newTplOutput.text = "";
                                                addForm.visible = false;
                                            }
                                        }
                                    }

                                    PanelButton {
                                        width: 56
                                        label: "CANCEL"
                                        onClicked: addForm.visible = false
                                    }
                                }
                            }
                        }

                        ToggleRow {
                            width: parent.width
                            label: "FOLLOW.WALLPAPER"
                            sub: "theme.json drives the palette // live recolor"
                            checked: Theme.followWallpaper
                            onToggled: Theme.setFollowWallpaper(!Theme.followWallpaper)
                        }

                        Text {
                            width: parent.width
                            text: "selecting a wallpaper repaints via awww and regenerates every enabled template through matugen."
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 7
                            font.letterSpacing: 0.5
                            wrapMode: Text.WordWrap
                        }
                    }

                    // ================= MODULES =================
                    Column {
                        id: modulesPage
                        visible: root.tabIndex === 1
                        width: root.innerW
                        spacing: 4

                        SectionLabel {
                            width: parent.width
                            label: "BAR.SEGMENTS"
                        }

                        ToggleRow {
                            width: parent.width
                            label: "TRAY.CLUSTER"
                            sub: "status notifier area"
                            checked: ShellState.barTray
                            onToggled: ShellState.set("barTray", !ShellState.barTray)
                        }

                        ToggleRow {
                            width: parent.width
                            label: "STATS.CLUSTER"
                            sub: "net cpu mem bat"
                            checked: ShellState.barStats
                            onToggled: ShellState.set("barStats", !ShellState.barStats)
                        }

                        ToggleRow {
                            width: parent.width
                            label: "CLOCK.BLOCK"
                            sub: "time // date // kanji weekday"
                            checked: ShellState.barClock
                            onToggled: ShellState.set("barClock", !ShellState.barClock)
                        }

                        SectionLabel {
                            width: parent.width
                            label: "NOTES"
                        }

                        Text {
                            width: parent.width
                            text: "segment visibility persists to state.json and applies instantly."
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 7
                            font.letterSpacing: 0.5
                            wrapMode: Text.WordWrap
                        }
                    }

                    // ================= SYSTEM =================
                    Column {
                        id: systemPage
                        visible: root.tabIndex === 2
                        width: root.innerW
                        spacing: 4

                        SectionLabel {
                            width: parent.width
                            label: "INTEGRATIONS.STUB"
                        }

                        Repeater {
                            model: [
                                { name: "NOTIFICATIONS", jp: "通知", phase: "PH.05" },
                                { name: "NETWORK.SUITE", jp: "網", phase: "PH.06" },
                                { name: "AUDIO.MEDIA", jp: "音", phase: "PH.07" },
                                { name: "SESSION.LOCK", jp: "錠", phase: "PH.08" }
                            ]

                            delegate: Item {
                                id: stubRow
                                required property var modelData

                                width: root.innerW
                                height: 30

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.bg
                                    border.width: 1
                                    border.color: Theme.hairline
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    text: stubRow.modelData.name + (Theme.jpEnabled ? " // " + stubRow.modelData.jp : "")
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 9
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1
                                }

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    width: phaseText.width + 12
                                    height: 14
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Theme.hairline

                                    Text {
                                        id: phaseText
                                        anchors.centerIn: parent
                                        text: stubRow.modelData.phase
                                        color: Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 7
                                        font.letterSpacing: 1
                                    }
                                }
                            }
                        }

                        Text {
                            width: parent.width
                            text: "wired in later phases — see ROADMAP.md."
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: 7
                            font.letterSpacing: 0.5
                        }
                    }

                    // ================= ABOUT =================
                    Column {
                        id: aboutPage
                        visible: root.tabIndex === 3
                        width: root.innerW
                        spacing: 8

                        Text {
                            text: "YUTA//OS"
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            font.weight: Font.ExtraBold
                            font.letterSpacing: 2
                        }

                        Text {
                            text: "neo-brutalist shell for hyprland // v" + Theme.version
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: 8
                            font.letterSpacing: 1
                        }

                        SectionLabel {
                            width: parent.width
                            label: "STATE"
                        }

                        Column {
                            spacing: 4
                            width: parent.width

                            Text {
                                text: "SCHEME   " + Theme.sourceLabel
                                color: Theme.acid
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.letterSpacing: 1
                            }

                            Text {
                                text: "FONT     JetBrainsMono Nerd Font // CJK " + (Theme.jpEnabled ? "ON" : "OFF")
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.letterSpacing: 1
                            }

                            Text {
                                text: "STACK    quickshell 0.3.1 // hyprland // matugen"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                                font.letterSpacing: 1
                            }
                        }

                        SectionLabel {
                            width: parent.width
                            label: "IPC.BINDINGS"
                        }

                        Column {
                            spacing: 4
                            width: parent.width

                            Text {
                                text: "qs ipc call panel toggle"
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }

                            Text {
                                text: "qs ipc call scheme set <name>"
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }

                            Text {
                                text: "qs ipc call wallpaper next"
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }

                            Text {
                                text: "qs ipc call wallpaper set <path>"
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }

                            Text {
                                text: "qs ipc call templates list"
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: 8
                            }
                        }
                    }
                }
            }

            // ---- footer ----
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 30
                color: Theme.bg

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: Theme.hairline
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: root.pad
                    text: "SRC: " + Theme.sourceLabel
                    color: Theme.acid
                    font.family: Theme.fontFamily
                    font.pixelSize: 7
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.pad
                    text: "ESC TO CLOSE // " + (Theme.jpEnabled ? "閉じる" : "CLOSE")
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: 7
                    font.letterSpacing: 1
                }
            }
        }
    }

    property var presetData: []

    readonly property var tplData: Wallpaper.templatesList()

    Component.onCompleted: {
        const out = [];
        for (const p of Theme.presets) {
            const m = Theme.previewOf(p.id) ?? {};
            out.push({
                id: p.id,
                label: p.label,
                bg: m.bg ?? "#111111",
                ink: m.ink ?? "#eeeeee",
                acid: m.acid ?? "#00ff00",
                alert: m.alert ?? "#ff0000"
            });
        }
        root.presetData = out;
    }
}
