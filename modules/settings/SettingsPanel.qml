import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "ui"

// Control core v3 — right drawer built entirely from the shared kit
// (YButton/YRow/YSection/YField/YChip/YScroll). Pages are lazy Loaders so
// heavy lists only build when visited and scroll offsets never leak.
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

    // user-tunable presentation: width persists via ShellState, mode flips
    // between right drawer and centered popout card
    readonly property int drawerW: Math.max(400, Math.min(760, ShellState.panelW))
    readonly property bool popout: ShellState.panelPopout
    readonly property int railW: 132
    readonly property int padX: Theme.sp4
    readonly property int navItemH: 44
    readonly property int titleBlockH: 66
    readonly property int contentW: drawerW - railW - padX - Theme.sp4

    // ---- page registry (declarative; modules register settings pages here) ----
    readonly property var pages: [{
            id: "appearance",
            label: "APPEARANCE",
            jp: "外見"
        }, {
            id: "templates",
            label: "TEMPLATES",
            jp: "型板"
        }, {
            id: "modules",
            label: "MODULES",
            jp: "部品"
        }, {
            id: "system",
            label: "SYSTEM",
            jp: "系統"
        }, {
            id: "about",
            label: "ABOUT",
            jp: "情報"
        }]

    property int tabIndex: 0
    readonly property var activePage: pages[Math.max(0, Math.min(tabIndex, pages.length - 1))]
    readonly property string activePageId: activePage.id

    Timer {
        id: hideDelay

        interval: 190
    }

    Timer {
        id: blinkTimer

        interval: 600
        running: true
        repeat: true
        onTriggered: root.blinkOn = !root.blinkOn
    }

    property bool blinkOn: true

    // YUTA_DEBUG_CYCLE=1 walks every tab on a timer — validates all lazy pages
    // build cleanly without manual clicking
    Timer {
        interval: 350
        running: Quickshell.env("YUTA_DEBUG_CYCLE") === "1"
        repeat: true
        triggeredOnStart: true
        onTriggered: root.tabIndex = (root.tabIndex + 1) % root.pages.length
    }

    Item {
        id: contentRoot

        anchors.fill: parent

        focus: ShellState.panelOpen

        Keys.onEscapePressed: ShellState.closePanel()
        Keys.onTabPressed: root.tabIndex = (root.tabIndex + 1) % root.pages.length

        // ---- dim scrim ----
        Rectangle {
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

        // ===== DRAWER / POPOUT BODY =====
        // layer.enabled rasters the panel once and moves the texture — the
        // slide animates at compositor cost instead of full repaints (jank fix)
        Rectangle {
            id: drawer

            width: root.drawerW
            height: root.popout ? parent.height - 96 : parent.height
            x: {
                if (!ShellState.panelOpen)
                    return root.popout ? (parent.width - width) / 2 : parent.width;
                return root.popout ? (parent.width - width) / 2 : parent.width - width;
            }
            y: root.popout ? (ShellState.panelOpen ? (parent.height - height) / 2 : parent.height) : 0
            opacity: ShellState.panelOpen ? 1 : 0
            color: Theme.bgAlt
            border.width: root.popout ? 1 : 0
            border.color: Theme.lineStrong
            layer.enabled: true
            layer.smooth: true

            Behavior on x {
                NumberAnimation {
                    duration: Theme.movMed
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on y {
                NumberAnimation {
                    duration: Theme.movMed
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.movFast
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on height {
                NumberAnimation {
                    duration: Theme.movMed
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Theme.lineStrong
            }

            // corner tick motif
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                width: 2
                height: 26
                color: Theme.acid
            }

            // ===== HEADER BAND =====
            Item {
                id: header

                x: 0
                y: 0
                width: parent.width
                height: Theme.headH

                // logo mark
                Rectangle {
                    id: logo

                    x: root.padX
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    color: Theme.acid

                    Text {
                        anchors.centerIn: parent
                        text: "Y"
                        color: Theme.bg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsTitle
                        font.weight: Font.ExtraBold
                    }
                }

                Text {
                    id: wordmark

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: logo.right
                    anchors.leftMargin: Theme.sp2
                    text: "YUTA//OS"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: wordmark.right
                    anchors.leftMargin: Theme.sp2
                    width: 1
                    height: 14
                    color: Theme.lineStrong
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: wordmark.right
                    anchors.leftMargin: Theme.sp3
                    text: "CONTROL.CORE"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 2
                }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: closeBtn.left
                    anchors.rightMargin: Theme.sp2
                    spacing: Theme.sp1

                    YChip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "v" + Theme.version
                    }
                }

                YButton {
                    id: closeBtn

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.padX - 6
                    width: 30
                    label: "×"
                    onClicked: ShellState.closePanel()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                y: Theme.headH
                height: 1
                color: Theme.hairline
            }

            // ===== NAV RAIL =====
            Item {
                id: railHost

                x: 0
                y: Theme.headH + 1
                width: root.railW
                height: root.navItemH * root.pages.length

                Repeater {
                    model: root.pages

                    delegate: Item {
                        id: navItem

                        required property int index
                        required property var modelData

                        readonly property bool isActive: root.tabIndex === index

                        x: 0
                        y: index * root.navItemH
                        width: root.railW
                        height: root.navItemH

                        Rectangle {
                            visible: navItem.isActive
                            anchors.fill: parent
                            color: Theme.bg
                        }

                        Text {
                            id: navNum

                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: root.padX - 4
                            text: "0" + (navItem.index + 1)
                            color: navItem.isActive ? Theme.acid : Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                            font.weight: Font.Bold
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: navNum.right
                            anchors.leftMargin: Theme.sp2
                            spacing: 1

                            Text {
                                text: navItem.modelData.label
                                color: navItem.isActive ? Theme.ink : navArea.containsMouse ? Theme.ink : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                                font.weight: navItem.isActive ? Font.Bold : Font.Normal
                                font.letterSpacing: 1.5
                            }

                            Text {
                                visible: Theme.jpEnabled
                                text: navItem.modelData.jp
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                            }
                        }

                        MouseArea {
                            id: navArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tabIndex = navItem.index
                        }
                    }
                }

                // single sliding acid tick (positional — animated)
                Rectangle {
                    x: 0
                    width: 3
                    height: root.navItemH
                    y: root.tabIndex * root.navItemH
                    color: Theme.acid

                    Behavior on y {
                        NumberAnimation {
                            duration: Theme.movFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.leftMargin: root.railW
                width: 1
                color: Theme.hairline
            }

            // ===== PAGE TITLE FRAME (fixed — doesn't scroll) =====
            Item {
                id: pageTitleBlock

                x: root.railW + root.padX
                y: Theme.headH + 1 + Theme.sp3
                width: root.contentW
                height: root.titleBlockH - Theme.sp3 * 2

                Text {
                    id: pageTitle

                    anchors.top: parent.top
                    text: root.activePage.label.charAt(0) + root.activePage.label.slice(1).toLowerCase()
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsDisplay
                    font.weight: Font.ExtraBold
                }

                Rectangle {
                    anchors.verticalCenter: pageTitle.verticalCenter
                    anchors.left: pageTitle.right
                    anchors.leftMargin: 5
                    width: 5
                    height: 14
                    color: Theme.acid
                    visible: root.blinkOn
                }

                Text {
                    anchors.baseline: pageTitle.baseline
                    anchors.right: parent.right
                    text: root.activePageId === "templates" ? Wallpaper.templatesList().filter(t => t.enabled).length + " ON" : ""
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 1
                }

                Text {
                    anchors.top: pageTitle.bottom
                    anchors.topMargin: 3
                    text: Theme.jpEnabled ? root.activePage.jp + " — settings" : "settings"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 1
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.hairline
                }
            }

            // ===== PAGE HOST =====
            Flickable {
                id: pageScroll

                x: root.railW + root.padX
                y: Theme.headH + 1 + root.titleBlockH
                width: root.contentW
                height: parent.height - y - Theme.footH - Theme.sp3
                contentWidth: width
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 4000
                contentHeight: Math.max(height, pageLoader.item ? pageLoader.item.height + Theme.sp3 : 0)

                Loader {
                    id: pageLoader

                    width: parent.width
                    active: ShellState.panelOpen
                    sourceComponent: {
                        switch (root.activePageId) {
                        case "templates":
                            return templatesPage;
                        case "modules":
                            return modulesPage;
                        case "system":
                            return systemPage;
                        case "about":
                            return aboutPage;
                        default:
                            return appearancePage;
                        }
                    }
                }
            }

            YScroll {
                target: pageScroll
                x: pageScroll.x + pageScroll.width + 3
                y: pageScroll.y
                width: 3
                height: pageScroll.height
            }

            // ===== FOOTER =====
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.footH
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
                    anchors.leftMargin: root.padX
                    text: "SRC " + Theme.sourceLabel.toUpperCase()
                    color: Theme.acid
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "ESC CLOSE · TAB NEXT"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.padX
                    text: Theme.jpEnabled ? "閉じる" : "CLOSE"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                }
            }

            // =====================================================
            // PAGES
            // =====================================================

            Component {
                id: appearancePage

                Column {
                    id: appearanceCol

                    width: root.contentW
                    spacing: Theme.sp3

                    // adaptive swatch layout once the panel grows
                    readonly property int swCols: width > 560 ? 3 : 2

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Scheme presets"
                        chip: Theme.followWallpaper ? "auto" : Theme.sourceLabel.toLowerCase()
                    }

                    Grid {
                        columns: appearanceCol.swCols
                        spacing: Theme.sp2

                        Repeater {
                            model: root.presetData

                            delegate: SwatchTile {
                                required property var modelData

                                width: (root.contentW - Theme.sp2 * (appearanceCol.swCols - 1)) / appearanceCol.swCols
                                height: 72
                                data_: modelData
                                active: !Theme.followWallpaper && Theme.activeScheme === modelData.id
                                onPicked: id => Theme.applyPreset(id)
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "Wallpaper"
                    }

                    // current wallpaper card
                    Rectangle {
                        id: currentWallCard

                        width: parent.width
                        height: 112
                        color: Theme.bg
                        border.width: 1
                        border.color: Theme.hairline

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            source: Wallpaper.current.length > 0 && ShellState.panelOpen ? "file://" + Wallpaper.current : ""
                            sourceSize.width: 512
                            sourceSize.height: 320
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }

                        // empty state
                        Text {
                            anchors.centerIn: parent
                            visible: Wallpaper.current.length === 0
                            text: "NO WALLPAPER SET"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                            font.letterSpacing: 2
                        }

                        // name strip
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 20
                            visible: Wallpaper.current.length > 0
                            color: "#d9000000"

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.sp2
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.sp2
                                elide: Text.ElideMiddle
                                text: Wallpaper.current.split("/").pop()
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.letterSpacing: 0.5
                            }
                        }

                        Rectangle {
                            visible: Wallpaper.current.length > 0
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 2
                            width: 9
                            height: 9
                            color: Theme.acid
                        }
                    }

                    Row {
                        spacing: Theme.sp2

                        YButton {
                            width: 118
                            tone: "acid"
                            label: "open picker"
                            onClicked: {
                                ShellState.closePanel();
                                ShellState.openPicker();
                            }
                        }

                        YButton {
                            width: 84
                            label: "random"
                            onClicked: Wallpaper.applyRandom()
                        }

                        YButton {
                            width: 84
                            label: "rescan"
                            onClicked: Wallpaper.rescan()
                        }
                    }

                    YRow {
                        width: parent.width
                        title: "Follow wallpaper"
                        sub: "palette regenerates from every applied image"
                        on_: Theme.followWallpaper

                        YSwitch {
                            checked: Theme.followWallpaper
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: Theme.setFollowWallpaper(!Theme.followWallpaper)
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "03"
                        label: "Mode & accent"
                        chip: Theme.dark ? "dark" : "light"
                    }

                    // light/dark — segmented, snaps instantly like all state toggles
                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        YButton {
                            width: (parent.width - Theme.sp1) / 2
                            tone: Theme.dark ? "acid" : "default"
                            label: "dark"
                            onClicked: Theme.setDark(true)
                        }

                        YButton {
                            width: (parent.width - Theme.sp1) / 2
                            tone: !Theme.dark ? "acid" : "default"
                            label: "light"
                            onClicked: Theme.setDark(false)
                        }
                    }

                    Text {
                        width: parent.width
                        text: "light mode regenerates every palette at runtime — paper surfaces, ink text, contrast-fitted accents."
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        text: "ACCENT OVERRIDE"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        font.letterSpacing: 2
                    }

                    Row {
                        spacing: 5

                        Repeater {
                            model: root.accentChoices

                            delegate: Rectangle {
                                id: swatch

                                required property int index
                                required property string modelData

                                readonly property bool active: (Theme.accentOverride.length === 0 && modelData.length === 0) || Theme.accentOverride.toLowerCase() === modelData.toLowerCase()

                                width: 24
                                height: 24
                                color: modelData.length > 0 ? modelData : "transparent"
                                border.width: 1
                                border.color: active ? Theme.ink : swatchArea.containsMouse ? Theme.muted : Theme.hairline

                                Text {
                                    anchors.centerIn: parent
                                    visible: parent.modelData.length === 0
                                    text: "/"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    font.weight: Font.Bold
                                }

                                Rectangle {
                                    visible: swatch.active
                                    x: parent.width - 7
                                    y: parent.height - 7
                                    width: 6
                                    height: 6
                                    color: Theme.acid
                                }

                                MouseArea {
                                    id: swatchArea

                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Theme.setAccent(swatch.modelData)
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "slash tile follows the scheme — overrides recolor live and persist."
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        wrapMode: Text.WordWrap
                    }

                    YSection {
                        width: parent.width
                        index: "04"
                        label: "Control core"
                        chip: root.popout ? "popout" : root.drawerW + "px drawer"
                    }

                    // presentation mode — segmented
                    Item {
                        width: parent.width
                        height: Theme.ctlH + Theme.fsMicro * 2

                        Text {
                            anchors.top: parent.top
                            text: "PRESENTATION"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                            font.letterSpacing: 2
                        }

                        Row {
                            anchors.bottom: parent.bottom
                            spacing: Theme.sp1

                            YButton {
                                width: (appearanceCol.width - Theme.sp1) / 2
                                tone: root.popout ? "default" : "acid"
                                label: "side drawer"
                                onClicked: ShellState.set("panelPopout", false)
                            }

                            YButton {
                                width: (appearanceCol.width - Theme.sp1) / 2
                                tone: root.popout ? "acid" : "default"
                                label: "popout card"
                                onClicked: ShellState.set("panelPopout", true)
                            }
                        }
                    }

                    // width stepper
                    Item {
                        width: parent.width
                        height: Theme.ctlH + Theme.fsMicro * 2

                        Text {
                            anchors.top: parent.top
                            text: "PANEL WIDTH"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                            font.letterSpacing: 2
                        }

                        Row {
                            anchors.bottom: parent.bottom
                            spacing: Theme.sp2

                            YButton {
                                width: 32
                                label: "−"
                                onClicked: ShellState.set("panelW", Math.max(400, ShellState.panelW - 16))
                            }

                            Item {
                                width: 72
                                height: Theme.ctlH

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.bg
                                    border.width: 1
                                    border.color: Theme.hairline
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: Math.max(400, Math.min(760, ShellState.panelW)) + " px"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.Bold
                                }
                            }

                            YButton {
                                width: 32
                                label: "+"
                                onClicked: ShellState.set("panelW", Math.min(760, ShellState.panelW + 16))
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "400 – 760"
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "the picker is its own panel — bind it to a key with qs ipc call picker toggle."
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        wrapMode: Text.WordWrap
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }

            Component {
                id: templatesPage

                TemplatesPage {
                    contentW: root.contentW
                }
            }

            Component {
                id: modulesPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Bar segments"
                    }

                    Repeater {
                        model: [
                            {
                                key: "barTray",
                                title: "Tray cluster",
                                sub: "status notifier icons"
                            },
                            {
                                key: "barStats",
                                title: "Stats cluster",
                                sub: "network · cpu · memory · battery"
                            },
                            {
                                key: "barMedia",
                                title: "Media segment",
                                sub: "mpris now-playing ticker"
                            },
                            {
                                key: "barClock",
                                title: "Clock block",
                                sub: "time · date" + (Theme.jpEnabled ? " · kanji weekday" : "")
                            }
                        ]

                        delegate: YRow {
                            id: segRow

                            required property var modelData

                            width: root.contentW
                            title: segRow.modelData.title
                            sub: segRow.modelData.sub
                            on_: ShellState[segRow.modelData.key]

                            YSwitch {
                                checked: ShellState[segRow.modelData.key]
                                anchors.verticalCenter: parent.verticalCenter
                                onToggled: ShellState.set(segRow.modelData.key, !ShellState[segRow.modelData.key])
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "segment visibility persists to state.json and applies instantly."
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        wrapMode: Text.WordWrap
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }

            Component {
                id: systemPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Integrations"
                        chip: "planned"
                    }

                    Repeater {
                        model: [{
                                title: "Notifications",
                                jp: "通知",
                                phase: "PH.05"
                            }, {
                                title: "Network suite",
                                jp: "網",
                                phase: "PH.06"
                            }, {
                                title: "Audio & media",
                                jp: "音",
                                phase: "PH.07"
                            }, {
                                title: "Session lock",
                                jp: "錠",
                                phase: "PH.08"
                            }]

                        delegate: YRow {
                            id: stubRow

                            required property var modelData

                            width: root.contentW
                            interactive: false
                            title: modelData.title + (Theme.jpEnabled ? "  ·  " + modelData.jp : "")

                            YChip {
                                label: stubRow.modelData.phase
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "wired in later phases — see ROADMAP.md."
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }

            Component {
                id: aboutPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    Text {
                        text: "YUTA//OS"
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsDisplay
                        font.weight: Font.ExtraBold
                        font.letterSpacing: 3
                    }

                    Text {
                        text: "neo-brutalist shell for hyprland — v" + Theme.version
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "State"
                    }

                    Column {
                        spacing: 4
                        width: parent.width

                        Repeater {
                            model: [{
                                    k: "scheme",
                                    v: Theme.sourceLabel
                                }, {
                                    k: "font",
                                    v: "JetBrainsMono NF · CJK " + (Theme.jpEnabled ? "on" : "off")
                                }, {
                                    k: "stack",
                                    v: "quickshell 0.3.1 · hyprland · matugen"
                                }, {
                                    k: "wallpapers",
                                    v: Wallpaper.entries.length + " indexed"
                                }]

                            delegate: Item {
                                id: kvRow

                                required property var modelData

                                width: root.contentW
                                height: 18

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.left: parent.left
                                    text: kvRow.modelData.k.toUpperCase()
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.5
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.right: parent.right
                                    text: kvRow.modelData.v
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                }
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "IPC cheatsheet"
                    }

                    Rectangle {
                        width: parent.width
                        height: ipcCol.height + Theme.sp2 * 2
                        color: Theme.bg
                        border.width: 1
                        border.color: Theme.hairline

                        Column {
                            id: ipcCol

                            anchors.centerIn: parent
                            spacing: 3
                            width: parent.width - Theme.sp2 * 2

                            Repeater {
                                model: ["qs ipc call panel toggle", "qs ipc call picker toggle", "qs ipc call scheme set <name>", "qs ipc call wallpaper set <path>", "qs ipc call theme dark on|off|toggle", "qs ipc call theme accent <#hex|none>", "qs ipc call templates list|on|off"]

                                delegate: Text {
                                    required property var modelData

                                    text: modelData
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: TemplateCatalog.credit
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }
        }
    }

    // ---- scheme preview data for swatches ----
    property var presetData: []

    // curated override candidates (data, not chrome — the live acid token
    // still decides selection/active visuals)
    property var accentChoices: ["", "#c8ff3d", "#3dffc0", "#35d0ff", "#3da9ff", "#b96bff", "#ff5cd0", "#ff3b52", "#ffd23d", "#eae8e0"]

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
