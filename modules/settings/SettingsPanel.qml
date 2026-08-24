import Quickshell
import Quickshell.Wayland
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "../notify"
import "../audio"
import "../session"
import "../dock"
import "../bar"
import "../net"
import "../widgets"
import "ui"

// Control core v3 — right drawer built entirely from the shared kit
// (YButton/YRow/YSection/YField/YChip/YScroll). Pages are lazy Loaders so
// heavy lists only build when visited and scroll offsets never leak.
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
    visible: ShellState.panelOpen || hideDelay.running
    mask: Region {
        item: ShellState.panelOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // user-tunable presentation: width persists via ShellState; placement
    // (center|left|right) picks where the card rests below the bar
    readonly property int cardW: Math.max(640, Math.min(1200, ShellState.panelW, contentRoot.width - Theme.outerPad * 2))
    readonly property int cardH: Math.min(760, contentRoot.height - Theme.barHeight - Theme.outerPad * 2 - 24)
    readonly property string anchorX: ShellState.panelAnchor === "left" ? "left" : ShellState.panelAnchor === "right" ? "right" : "center"
    readonly property int padX: Theme.sp4
    readonly property int tabH: Theme.barHeight
    readonly property int titleBlockH: 56
    readonly property int railW: 170
    readonly property int contentW: cardW - railW - padX * 2 - 1

    function setPage(i) {
        // don't hijack a keystroke the user is typing into a field
        const afi = root.activeFocusItem;
        if (afi && (afi instanceof TextInput))
            return;
        tabIndex = i;
        ShellState.set("panelLastPage", i);
    }

    // a corrupt state.json string must degrade to empty, not kill the binding
    function _safeLen(json) {
        return _safeArr(json).length;
    }

    function _safeArr(json) {
        try {
            const v = JSON.parse(json);
            return Array.isArray(v) ? v : [];
        } catch (e) {
            return [];
        }
    }

    // ---- page registry (declarative; modules register settings pages here) ----
    readonly property var pages: [{
            id: "appearance",
            label: "APPEARANCE",
            jp: "外見",
            group: "LOOK",
            keywords: "scheme palette wallpaper accent light dark font scale animation templates matugen"
        }, {
            id: "dock",
            label: "DOCK",
            jp: "埠",
            group: "LOOK",
            keywords: "dock taskbar pin hide mode"
        }, {
            id: "panels",
            label: "PANELS",
            jp: "面",
            group: "LOOK",
            keywords: "settings picker notification osd width placement corner"
        }, {
            id: "launcher",
            label: "LAUNCHER",
            jp: "発",
            group: "LOOK",
            keywords: "launcher anchor grid list icon pins recents"
        }, {
            id: "controlcenter",
            label: "CONTROL CENTER",
            jp: "中枢",
            group: "LOOK",
            keywords: "control center cc anchor tabs"
        }, {
            id: "notifications",
            label: "NOTIFY",
            jp: "通知",
            group: "BEHAVIOR",
            keywords: "notification dnd timeout corner fields per-app"
        }, {
            id: "osd",
            label: "OSD",
            jp: "表",
            group: "BEHAVIOR",
            keywords: "osd volume brightness mic corner width fade"
        }, {
            id: "bar",
            label: "BAR",
            jp: "棒",
            group: "BEHAVIOR",
            keywords: "bar segment taskbar scale position click action tray stats clock"
        }, {
            id: "shell",
            label: "SHELL",
            jp: "殻",
            group: "SYSTEM",
            keywords: "avatar timezone clock 24h imperial metric weather clipboard screenshot"
        }, {
            id: "security",
            label: "SECURITY",
            jp: "安",
            group: "SYSTEM",
            keywords: "offline airplane lock idle pam"
        }, {
            id: "system",
            label: "SYSTEM",
            jp: "系",
            group: "SYSTEM",
            keywords: "monitor stats poll threshold"
        }, {
            id: "services",
            label: "SERVICES",
            jp: "務",
            group: "SYSTEM",
            keywords: "autostart calendar audio overdrive brightness night light"
        }, {
            id: "power",
            label: "POWER",
            jp: "電",
            group: "SYSTEM",
            keywords: "power plan session menu hold idle lock battery"
        }, {
            id: "plugins",
            label: "PLUGINS",
            jp: "拡",
            group: "SYSTEM",
            keywords: "plugins extensions widgets daemons scan qml"
        }, {
            id: "about",
            label: "ABOUT",
            jp: "情報",
            group: "SYSTEM",
            keywords: "about version state ipc"
        }]

    readonly property var groups: [
        { id: "LOOK", label: "LOOK" },
        { id: "BEHAVIOR", label: "BEHAVIOR" },
        { id: "SYSTEM", label: "SYSTEM" }
    ]

    property int tabIndex: 0
    readonly property var activePage: pages[Math.max(0, Math.min(tabIndex, pages.length - 1))]
    readonly property string activePageId: activePage.id

    // global search — filters the rail by label/jp/keywords; picking a result
    // jumps to its tab
    property string searchQuery: ""

    function matchesQuery(p) {
        const q = root.searchQuery.trim().toLowerCase();
        if (q.length === 0)
            return true;
        const hay = (p.label + " " + (p.jp ?? "") + " " + (p.keywords ?? "")).toLowerCase();
        return hay.indexOf(q) >= 0;
    }

    readonly property var visiblePages: root.pages.filter(p => root.matchesQuery(p))

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    // linger mapped after close so YSurface's exit ceremony renders
    Connections {
        target: ShellState

        function onPanelOpenChanged() {
            if (!ShellState.panelOpen)
                hideDelay.restart();
        }
    }

    // remember where the user left off across opens
    Connections {
        target: ShellState

        function onPanelOpenChanged() {
            if (ShellState.panelOpen)
                root.tabIndex = Math.max(0, Math.min(ShellState.panelLastPage, root.pages.length - 1));
        }
    }

    // identity blink — only worth ticking while the panel is on screen
    Timer {
        id: blinkTimer

        interval: 600
        running: ShellState.panelOpen
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
        Keys.onTabPressed: root.setPage((root.tabIndex + 1) % root.pages.length)

        // fullscreen click-catcher — a click anywhere outside the card closes
        // it; the card's own swallow area keeps in-card clicks from reaching it
        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closePanel()
        }

        // ===== CARD BODY =====
        // YSurface owns placement + the drop-from-behind-the-bar entrance
        YSurface {
            id: drawer

            open: ShellState.panelOpen
            anchorX: root.anchorX
            cardW: root.cardW
            cardH: root.cardH
            cascade: pageLoader.item as Item

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

            // ===== NAV RAIL (two-level: groups → tabs) =====
            // vertical rail: search field on top, then LOOK / BEHAVIOR / SYSTEM
            // groups, each with its tabs. Search filters the whole rail.
            Item {
                id: navRail

                x: 0
                y: Theme.headH + 1
                width: root.railW
                height: parent.height - y
                clip: true

                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: Theme.hairline
                }

                // search field
                YField {
                    id: searchField

                    x: Theme.sp2
                    y: Theme.sp2
                    width: parent.width - Theme.sp2 * 2
                    placeholder: Theme.jpEnabled ? "検索 // SEARCH" : "SEARCH…"
                    onAccepted: {
                        const idx = root.pages.findIndex(p => root.matchesQuery(p));
                        if (idx >= 0 && root.searchQuery.trim().length > 0)
                            root.setPage(idx);
                    }
                    text: root.searchQuery
                    onTextChanged: root.searchQuery = searchField.text
                }

                Column {
                    id: railCol

                    x: 0
                    y: searchField.y + searchField.height + Theme.sp2
                    width: parent.width
                    spacing: Theme.sp1

                        Repeater {
                            model: root.groups

                            delegate: Column {
                                id: groupCol

                                required property int index
                                required property var modelData

                                width: navRail.width
                                visible: root.pages.some(p => p.group === modelData.id && root.matchesQuery(p))

                                Text {
                                    x: Theme.sp3
                                    width: parent.width - Theme.sp3
                                    height: 20
                                    verticalAlignment: Text.AlignVCenter
                                    text: modelData.label
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                    font.weight: Font.Bold
                                    font.letterSpacing: 2
                                }

                                Repeater {
                                    model: root.pages.filter(p => p.group === groupCol.modelData.id && root.matchesQuery(p))

                                    delegate: Item {
                                        id: railRow

                                        required property var modelData

                                        readonly property bool active: root.activePageId === modelData.id

                                        width: navRail.width
                                        height: 30

                                        Rectangle {
                                            anchors.fill: parent
                                            color: railRow.active ? Theme.surface : railArea.containsMouse ? Theme.surface : "transparent"
                                            opacity: railRow.active || railArea.containsMouse ? 1 : 0

                                            Behavior on opacity {
                                                NumberAnimation {
                                                    duration: Theme.movFast
                                                }
                                            }

                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.top: parent.top
                                                anchors.bottom: parent.bottom
                                                width: 2
                                                color: railRow.active ? Theme.acid : "transparent"
                                            }
                                        }

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.sp3
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width - Theme.sp3 * 2
                                            elide: Text.ElideRight
                                            text: railRow.modelData.label
                                            color: railRow.active ? Theme.acid : railArea.containsMouse ? Theme.ink : Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsLabel
                                            font.weight: railRow.active ? Font.Bold : Font.Normal
                                            font.letterSpacing: 1
                                        }

                                        MouseArea {
                                            id: railArea

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                const idx = root.pages.findIndex(p => p.id === railRow.modelData.id);
                                                if (idx >= 0)
                                                    root.setPage(idx);
                                            }
                                        }
                                    }
                                }

                                Item {
                                    width: 1
                                    height: Theme.sp2
                                }
                            }
                        }
                    }

                    // search produced nothing — honest empty state
                    Text {
                        width: parent.width - Theme.sp3
                        x: Theme.sp3
                        y: searchField.y + searchField.height + Theme.sp3
                        visible: root.searchQuery.trim().length > 0 && root.visiblePages.length === 0
                        text: "NO MATCH"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        font.letterSpacing: 2
                    }
                }

            // ===== PAGE TITLE FRAME (fixed — doesn't scroll) =====
            Item {
                id: pageTitleBlock

                x: root.railW + root.padX
                y: Theme.headH + 1 + Theme.sp2
                width: root.contentW
                height: root.titleBlockH - Theme.sp2

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
                    text: root.activePageId === "appearance" ? Wallpaper.tplOnCount + " TPL ON" : ""
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
            // contentHeight is driven IMPERATIVELY: a plain binding on
            // pageLoader.item.height latches onto a dying item during page
            // switches and goes permanently stale (scroll dead). The
            // retargeted Connections below re-syncs on every real geometry
            // change of whichever page is alive.
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
                maximumFlickVelocity: 4200
                contentHeight: height

                function syncContentH() {
                    const it = pageLoader.item;
                    const h = it ? Math.max(it.height ?? 0, it.childrenRect?.height ?? 0) : 0;
                    contentHeight = Math.max(height, h + Theme.sp3);
                    if (Quickshell.env("YUTA_DEBUG_SCROLL") === "1")
                        console.log("[scroll-debug]", root.activePageId, "viewport", height, "content", contentHeight);
                }

                Component.onCompleted: syncContentH()
                onHeightChanged: syncContentH()

                FastWheel {
                }

                Loader {
                    id: pageLoader

                    width: parent.width
                    active: ShellState.panelOpen
                    sourceComponent: {
                        switch (root.activePageId) {
                        case "dock":
                            return dockPage;
                        case "panels":
                            return panelsPage;
                        case "launcher":
                            return launcherPage;
                        case "controlcenter":
                            return ccPage;
                        case "notifications":
                            return notificationsPage;
                        case "osd":
                            return osdPage;
                        case "bar":
                            return barPage;
                        case "shell":
                            return shellPage;
                        case "security":
                            return securityPage;
                        case "system":
                            return systemPage;
                        case "services":
                            return servicesPage;
                        case "power":
                            return powerPage;
                        case "plugins":
                            return pluginsPage;
                        case "about":
                            return aboutPage;
                        default:
                            return appearancePage;
                        }
                    }

                    onItemChanged: {
                        geoWatch.target = item;
                        pageScroll.syncContentH();
                        // tab switch: new page cascades in
                        if (ShellState.panelOpen && drawer.cascade)
                            drawer.reveal(item);
                    }

                    Connections {
                        id: geoWatch

                        ignoreUnknownSignals: true
                        function onHeightChanged() {
                            pageScroll.syncContentH();
                        }
                        function onChildrenRectChanged() {
                            pageScroll.syncContentH();
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
                            // theme scrim — survives light-mode recolor
                            color: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, 0.85)

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

                                // "" override = "follow palette" (the empty swatch);
                                // any other value matches case-insensitively
                                readonly property bool active: {
                                    const ao = String(Theme.accentOverride ?? "");
                                    return ao.length === 0 ? modelData.length === 0 : ao.toLowerCase() === modelData.toLowerCase();
                                }

                                width: 24
                                height: 24
                                color: modelData.length > 0 ? modelData : "transparent"
                                border.width: 1
                                border.color: active ? Theme.ink : swatchArea.containsMouse ? Theme.muted : Theme.hairline

                                Text {
                                    anchors.centerIn: parent
                                    visible: !parent.modelData || parent.modelData.length === 0
                                    text: "/"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
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
                        chip: root.anchorX + " · " + Math.max(640, Math.min(1200, ShellState.panelW)) + "px"
                    }

                    // placement — where the card rests below the bar
                    Item {
                        width: parent.width
                        height: Theme.ctlH + Theme.fsMicro * 2

                        Text {
                            anchors.top: parent.top
                            text: "PLACEMENT"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                            font.letterSpacing: 2
                        }

                        Row {
                            anchors.bottom: parent.bottom
                            spacing: Theme.sp1

                            YButton {
                                width: 96
                                tone: root.anchorX === "center" ? "acid" : "default"
                                label: "center"
                                onClicked: ShellState.set("panelAnchor", "center")
                            }

                            YButton {
                                width: 96
                                tone: root.anchorX === "left" ? "acid" : "default"
                                label: "left"
                                onClicked: ShellState.set("panelAnchor", "left")
                            }

                            YButton {
                                width: 96
                                tone: root.anchorX === "right" ? "acid" : "default"
                                label: "right"
                                onClicked: ShellState.set("panelAnchor", "right")
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
                                onClicked: ShellState.set("panelW", Math.max(640, ShellState.panelW - 32))
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
                                    text: Math.max(640, Math.min(1200, ShellState.panelW)) + " px"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.Bold
                                }
                            }

                            YButton {
                                width: 32
                                label: "+"
                                onClicked: ShellState.set("panelW", Math.min(1200, ShellState.panelW + 32))
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "640 – 1200"
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

                    YSection {
                        width: parent.width
                        index: "05"
                        label: "Matugen templates"
                        chip: Wallpaper.tplOnCount + " on"
                    }

                    TemplatesPage {
                        contentW: root.contentW
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }


            Component {
                id: notificationsPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Behavior"
                    }

                    YRow {
                        width: root.contentW
                        title: "Do not disturb"
                        sub: Notify.dnd ? Notify.suppressedCount + " suppressed since on" : "normal/low urgency held back; critical breaks through"
                        note: "DND"
                        on_: Notify.dnd

                        YSwitch {
                            checked: Notify.dnd
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: Notify.toggleDnd()
                        }
                    }

                    YRow {
                        width: root.contentW
                        title: "Show action buttons"
                        sub: "inline actions from apps on toast cards"
                        note: "ACT"
                        on_: ShellState.notifyActions

                        YSwitch {
                            checked: ShellState.notifyActions
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("notifyActions", !ShellState.notifyActions)
                        }
                    }

                    // corner picker
                    Item {
                        width: root.contentW
                        height: Theme.rowH

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Toast corner"
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBody
                        }

                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.sp1

                            Repeater {
                                model: [{
                                        id: "tr",
                                        label: "TOP-R"
                                    }, {
                                        id: "tl",
                                        label: "TOP-L"
                                    }]

                                delegate: YButton {
                                    required property var modelData

                                    readonly property bool activeCorner: ShellState.notifyCorner === modelData.id

                                    label: modelData.label
                                    tone: activeCorner ? "acid" : "default"
                                    onClicked: Notify.setCorner(modelData.id)
                                }
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "Timeouts"
                    }

                    YRow {
                        width: root.contentW
                        interactive: false
                        title: "Default timeout"
                        sub: ShellState.notifyTimeout === 0 ? "0 — honor each app's own timeout" : ShellState.notifyTimeout + "s (client may ask for less)"
                        note: "SEC"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.sp1

                            YButton {
                                label: "−"
                                onClicked: Notify.setTimeoutSec(ShellState.notifyTimeout - 1)
                            }

                            YButton {
                                label: "+"
                                onClicked: Notify.setTimeoutSec(ShellState.notifyTimeout + 1)
                            }
                        }
                    }

                    YRow {
                        width: root.contentW
                        interactive: false
                        title: "Max visible toasts"
                        sub: String(ShellState.notifyMaxVisible)
                        note: "MAX"

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.sp1

                            YButton {
                                label: "−"
                                onClicked: Notify.setMaxVisible(ShellState.notifyMaxVisible - 1)
                            }

                            YButton {
                                label: "+"
                                onClicked: Notify.setMaxVisible(ShellState.notifyMaxVisible + 1)
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "03"
                        label: "Card fields"
                    }

                    Repeater {
                        model: [{
                                key: "app",
                                title: "App name",
                                sub: "sender identity line"
                            }, {
                                key: "body",
                                title: "Body text",
                                sub: "message content under the summary"
                            }, {
                                key: "icon",
                                title: "App icon",
                                sub: "theme icon, acid initial as fallback"
                            }, {
                                key: "time",
                                title: "Timestamp",
                                sub: "history rows only"
                            }]

                        delegate: YRow {
                            id: fieldRow

                            required property var modelData

                            width: root.contentW
                            title: modelData.title
                            sub: modelData.sub
                            on_: Notify.fields[modelData.key]

                            YSwitch {
                                checked: Notify.fields[fieldRow.modelData.key]
                                anchors.verticalCenter: parent.verticalCenter
                                onToggled: {
                                    const p = {};
                                    p[fieldRow.modelData.key] = !Notify.fields[fieldRow.modelData.key];
                                    Notify.setFields(p);
                                }
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "04"
                        label: "Per-app overrides"
                        chip: Notify.overrides.length > 0 ? Notify.overrides.length + "" : ""
                    }

                    Repeater {
                        model: Notify.overrides

                        delegate: YRow {
                            id: ovRow

                            required property int index
                            required property var modelData

                            width: root.contentW
                            interactive: false
                            title: modelData.match
                            sub: modelData.mode === "block" ? "drop entirely — no toast, no history" : "quiet — history only unless critical"

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.sp1

                                YButton {
                                    label: ovRow.modelData.mode === "block" ? "QUIET" : "BLOCK"
                                    onClicked: Notify.setOverrideMode(ovRow.index, ovRow.modelData.mode === "block" ? "quiet" : "block")
                                }

                                YButton {
                                    label: "×"
                                    tone: "danger"
                                    onClicked: Notify.removeOverride(ovRow.index)
                                }
                            }
                        }
                    }

                    YField {
                        id: ovAdd

                        width: root.contentW
                        placeholder: "match app name substring… (enter to add as QUIET)"

                        onAccepted: {
                            if (Notify.addOverride(text, "quiet"))
                                text = "";
                        }
                    }

                    Row {
                        spacing: Theme.sp1

                        YButton {
                            label: "ADD QUIET RULE"
                            onClicked: {
                                if (Notify.addOverride(ovAdd.text, "quiet"))
                                    ovAdd.text = "";
                            }
                        }

                        YButton {
                            label: "ADD BLOCK RULE"
                            tone: "danger"
                            onClicked: {
                                if (Notify.addOverride(ovAdd.text, "block"))
                                    ovAdd.text = "";
                            }
                        }
                    }

                    Text {
                        // parent, not root — root.width is the whole panel
                        width: parent.width
                        text: "matching is case-insensitive against app name and desktop entry."
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
                id: dockPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Dock"
                        chip: ShellState.dockEnabled ? "ON" : "OFF"
                    }

                    YRow {
                        width: root.contentW
                        title: "Enable dock"
                        sub: "bottom app dock — pinned + running windows"
                        note: "DOCK"
                        on_: ShellState.dockEnabled

                        YSwitch {
                            checked: ShellState.dockEnabled
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: Dock.toggleEnabled()
                        }
                    }

                    YRow {
                        width: root.contentW
                        visible: ShellState.dockEnabled
                        title: "Reserve screen edge"
                        sub: ShellState.dockMode === "exclusive" ? "windows cannot overlap the dock strip" : "floats over windows"
                        note: "MODE"
                        on_: ShellState.dockMode === "exclusive"

                        YSwitch {
                            checked: ShellState.dockMode === "exclusive"
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("dockMode", ShellState.dockMode === "exclusive" ? "overlay" : "exclusive")
                        }
                    }

                    YSection {
                        width: parent.width
                        visible: ShellState.dockEnabled
                        index: "02"
                        label: "Auto-hide"
                        chip: ShellState.dockHide
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp1
                        visible: ShellState.dockEnabled

                        Repeater {
                            model: [{
                                    id: "never",
                                    label: "NEVER"
                                }, {
                                    id: "dodge",
                                    label: "DODGE"
                                }, {
                                    id: "always",
                                    label: "ALWAYS"
                                }]

                            delegate: YButton {
                                required property var modelData

                                tone: ShellState.dockHide === modelData.id ? "acid" : "default"
                                label: modelData.label
                                onClicked: ShellState.set("dockHide", modelData.id)
                            }
                        }
                    }

                    YRow {
                        width: root.contentW
                        visible: ShellState.dockEnabled
                        title: "All monitors"
                        sub: ShellState.dockMonitors === "all" ? "one dock per screen" : "primary screen only"
                        note: "MON"
                        on_: ShellState.dockMonitors === "all"

                        YSwitch {
                            checked: ShellState.dockMonitors === "all"
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("dockMonitors", ShellState.dockMonitors === "all" ? "primary" : "all")
                        }
                    }

                    Text {
                        width: parent.width
                        visible: ShellState.dockEnabled
                        text: "right-click a dock icon to pin or close · middle-click opens a fresh instance · scroll cycles that app's windows."
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
                        label: "System monitor"
                        chip: SystemStats.hostname.length > 0 ? SystemStats.hostname.toUpperCase() : ""
                    }

                    YRow {
                        width: root.contentW
                        title: "Uptime"
                        sub: SystemStats.uptime < 0 ? "--" : Math.floor(SystemStats.uptime / 3600) + "h " + Math.floor((SystemStats.uptime % 3600) / 60) + "m"
                        note: "UP"
                        interactive: false
                    }

                    YRow {
                        width: root.contentW
                        title: "GPU"
                        sub: SystemStats.gpuUtil < 0 ? "no gpu" : SystemStats.gpuUtil + "% · " + SystemStats.gpuTemp + "°C · " + SystemStats.fmtBytes(SystemStats.gpuMemUsed * 1048576)
                        note: "GPU"
                        interactive: false
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "Sensors"
                        chip: SystemStats.temps.length + " sensors"
                    }

                    Repeater {
                        model: SystemStats.temps

                        delegate: YRow {
                            required property var modelData

                            width: root.contentW
                            interactive: false
                            title: modelData.label
                            sub: modelData.id
                            note: modelData.temp + "°C"
                        }
                    }

                    Text {
                        width: parent.width
                        text: "cpu/mem/net/disk/load samples flow from the SystemStats singleton (FAST 2s · SLOW 5s)."
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        wrapMode: Text.WordWrap
                    }

                    YSection {
                        width: parent.width
                        index: "03"
                        label: "Power plan"
                        chip: Session.ppdAvailable ? Session.profileName.toUpperCase() : "NO PPD"
                    }

                    YRow {
                        width: root.contentW
                        title: "Power profile"
                        sub: Session.ppdAvailable ? "cycles saver → balanced → performance" : "install power-profiles-daemon to enable"
                        note: "PWR"
                        interactive: false

                        YButton {
                            anchors.verticalCenter: parent.verticalCenter
                            label: Session.ppdAvailable ? Session.profileName.toUpperCase() : "N/A"
                            tone: Session.ppdAvailable ? "acid" : "default"
                            enabled: Session.ppdAvailable
                            onClicked: Session.cycleProfile()
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "04"
                        label: "Idle"
                        chip: ShellState.idleAction === "none" ? "off" : ShellState.idleAction + " · " + ShellState.idleSecs + "s"
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        Repeater {
                            model: [{
                                    id: "none",
                                    label: "OFF"
                                }, {
                                    id: "lock",
                                    label: "LOCK"
                                }, {
                                    id: "suspend",
                                    label: "SUSPEND"
                                }, {
                                    id: "shutdown",
                                    label: "SHUTDOWN"
                                }]

                            delegate: YButton {
                                required property var modelData

                                tone: ShellState.idleAction === modelData.id ? "acid" : "default"
                                label: modelData.label
                                onClicked: ShellState.set("idleAction", modelData.id)
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: Theme.ctlH + Theme.fsMicro * 2
                        visible: ShellState.idleAction !== "none"

                        Text {
                            anchors.top: parent.top
                            text: "IDLE TIMEOUT"
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
                                onClicked: ShellState.set("idleSecs", Math.max(30, ShellState.idleSecs - 60))
                            }

                            Item {
                                width: 88
                                height: Theme.ctlH

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.bg
                                    border.width: 1
                                    border.color: Theme.hairline
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: ShellState.idleSecs + " s"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.Bold
                                }
                            }

                            YButton {
                                width: 32
                                label: "+"
                                onClicked: ShellState.set("idleSecs", Math.min(7200, ShellState.idleSecs + 60))
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "05"
                        label: "Power menu"
                        chip: ShellState.holdMs > 0 ? "hold " + ShellState.holdMs + "ms" : "no hold"
                    }

                    YRow {
                        width: root.contentW
                        title: "Hold to confirm"
                        sub: ShellState.holdMs > 0 ? "destructive tiles need a press-and-hold" : "destructive tiles fire immediately"
                        note: "HOLD"
                        on_: ShellState.holdMs > 0

                        YSwitch {
                            checked: ShellState.holdMs > 0
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("holdMs", ShellState.holdMs > 0 ? 0 : 1100)
                        }
                    }

                    Item {
                        width: parent.width
                        height: Theme.ctlH + Theme.fsMicro * 2
                        visible: ShellState.holdMs > 0

                        Text {
                            anchors.top: parent.top
                            text: "HOLD DURATION"
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
                                onClicked: ShellState.set("holdMs", Math.max(300, ShellState.holdMs - 200))
                            }

                            Item {
                                width: 88
                                height: Theme.ctlH

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.bg
                                    border.width: 1
                                    border.color: Theme.hairline
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: ShellState.holdMs + " ms"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.Bold
                                }
                            }

                            YButton {
                                width: 32
                                label: "+"
                                onClicked: ShellState.set("holdMs", Math.min(3000, ShellState.holdMs + 200))
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "06"
                        label: "Lock screen"
                        chip: "PAM " + ShellState.pamService
                    }

                    YRow {
                        width: root.contentW
                        title: "Lock on all monitors"
                        sub: ShellState.lockMonitors === "all" ? "every screen renders the auth card" : "primary screen only"
                        note: "MON"
                        on_: ShellState.lockMonitors === "all"

                        YSwitch {
                            checked: ShellState.lockMonitors === "all"
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("lockMonitors", ShellState.lockMonitors === "all" ? "primary" : "all")
                        }
                    }

                    YRow {
                        width: root.contentW
                        title: "Bar inhibit indicator"
                        sub: "a chip shows when an app holds the idle/sleep lock"
                        note: "INH"
                        on_: ShellState.barSession

                        YSwitch {
                            checked: ShellState.barSession
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("barSession", !ShellState.barSession)
                        }
                    }

                    YField {
                        id: avatarField

                        width: root.contentW
                        placeholder: "lock avatar path — blank uses ~/.face"

                        onAccepted: {
                            ShellState.set("lockAvatar", text.trim());
                            text = "";
                        }
                    }

                    Text {
                        width: parent.width
                        text: "avatar falls back to an initial when the file is missing · lock via IPC: qs ipc call session lock."
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
                id: panelsPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Settings panel"
                        chip: root.anchorX + " · " + Math.max(640, Math.min(1200, ShellState.panelW)) + "px"
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        Repeater {
                            model: [{
                                    id: "center",
                                    label: "CENTER"
                                }, {
                                    id: "left",
                                    label: "LEFT"
                                }, {
                                    id: "right",
                                    label: "RIGHT"
                                }]

                            delegate: YButton {
                                required property var modelData

                                tone: ShellState.panelAnchor === modelData.id ? "acid" : "default"
                                label: modelData.label
                                onClicked: ShellState.set("panelAnchor", modelData.id)
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "Notification stack"
                        chip: ShellState.notifyCorner.toUpperCase()
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        Repeater {
                            model: [{
                                    id: "tr",
                                    label: "TOP-R"
                                }, {
                                    id: "tl",
                                    label: "TOP-L"
                                }]

                            delegate: YButton {
                                required property var modelData

                                tone: ShellState.notifyCorner === modelData.id ? "acid" : "default"
                                label: modelData.label
                                onClicked: Notify.setCorner(modelData.id)
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "03"
                        label: "Control center"
                        chip: ShellState.ccAnchor.toUpperCase()
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        Repeater {
                            model: [{
                                    id: "center",
                                    label: "CENTER"
                                }, {
                                    id: "left",
                                    label: "LEFT"
                                }, {
                                    id: "right",
                                    label: "RIGHT"
                                }]

                            delegate: YButton {
                                required property var modelData

                                tone: ShellState.ccAnchor === modelData.id ? "acid" : "default"
                                label: modelData.label
                                onClicked: ShellState.set("ccAnchor", modelData.id)
                            }
                        }
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }

            Component {
                id: launcherPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "View"
                        chip: ShellState.launcherMode.toUpperCase()
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        Repeater {
                            model: [{
                                    id: "grid",
                                    label: "GRID"
                                }, {
                                    id: "list",
                                    label: "LIST"
                                }]

                            delegate: YButton {
                                required property var modelData

                                tone: ShellState.launcherMode === modelData.id ? "acid" : "default"
                                label: modelData.label
                                onClicked: ShellState.set("launcherMode", modelData.id)
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "Placement"
                        chip: ShellState.launcherAnchor.toUpperCase()
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        Repeater {
                            model: [{
                                    id: "center",
                                    label: "CENTER"
                                }, {
                                    id: "left",
                                    label: "LEFT"
                                }, {
                                    id: "right",
                                    label: "RIGHT"
                                }]

                            delegate: YButton {
                                required property var modelData

                                tone: ShellState.launcherAnchor === modelData.id ? "acid" : "default"
                                label: modelData.label
                                onClicked: ShellState.set("launcherAnchor", modelData.id)
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "03"
                        label: "Width"
                        chip: ShellState.launcherW + "px"
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp2

                        YButton {
                            width: 32
                            label: "−"
                            onClicked: ShellState.set("launcherW", Math.max(480, ShellState.launcherW - 32))
                        }

                        YButton {
                            width: 32
                            label: "+"
                            onClicked: ShellState.set("launcherW", Math.min(960, ShellState.launcherW + 32))
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "04"
                        label: "Memory"
                        chip: "pins " + _safeLen(ShellState.launcherPins) + " · recents " + _safeLen(ShellState.launcherRecents)
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp2

                        YButton {
                            label: "CLEAR PINS"
                            onClicked: ShellState.set("launcherPins", "[]")
                        }

                        YButton {
                            label: "CLEAR RECENTS"
                            onClicked: ShellState.set("launcherRecents", "[]")
                        }
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }

            Component {
                id: ccPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Tabs"
                        chip: _safeLen(ShellState.ccTabs) + " visible"
                    }

                    Repeater {
                        model: [{
                                id: "home",
                                label: "HOME"
                            }, {
                                id: "media",
                                label: "MEDIA"
                            }, {
                                id: "audio",
                                label: "AUDIO"
                            }, {
                                id: "monitors",
                                label: "MONITORS"
                            }, {
                                id: "system",
                                label: "SYSTEM"
                            }, {
                                id: "power",
                                label: "POWER"
                            }, {
                                id: "network",
                                label: "NETWORK"
                            }, {
                                id: "bluetooth",
                                label: "BLUETOOTH"
                            }, {
                                id: "weather",
                                label: "WEATHER"
                            }, {
                                id: "calendar",
                                label: "CALENDAR"
                            }, {
                                id: "notifications",
                                label: "NOTIFICATIONS"
                            }]

                        delegate: YRow {
                            id: ctRow

                            required property var modelData

                            readonly property var ids: root._safeArr(ShellState.ccTabs)
                            readonly property bool shown: ids.indexOf(modelData.id) >= 0

                            width: root.contentW
                            title: modelData.label
                            sub: ctRow.shown ? "shown in the strip" : "hidden"
                            on_: ctRow.shown

                            YSwitch {
                                checked: ctRow.shown
                                anchors.verticalCenter: parent.verticalCenter
                                onToggled: {
                                    let ids = root._safeArr(ShellState.ccTabs);
                                    if (ids.indexOf(ctRow.modelData.id) >= 0)
                                        ids = ids.filter(x => x !== ctRow.modelData.id);
                                    else
                                        ids.push(ctRow.modelData.id);
                                    ShellState.set("ccTabs", JSON.stringify(ids));
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "hiding a tab keeps its page lazy — re-enable anytime."
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
                id: osdPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Corner"
                        chip: ShellState.osdCorner.toUpperCase()
                    }

                    // 2×3 screen map — pick where the OSD card parks
                    Grid {
                        columns: 3
                        columnSpacing: Theme.sp1
                        rowSpacing: Theme.sp1

                        Repeater {
                            model: ["tl", "tc", "tr", "bl", "bc", "br"]

                            delegate: YButton {
                                required property var modelData

                                width: 64
                                tone: ShellState.osdCorner === modelData ? "acid" : "default"
                                label: modelData.toUpperCase()
                                onClicked: ShellState.set("osdCorner", modelData)
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: 14

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 1
                            color: Theme.hairline
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "Kinds"
                        chip: (ShellState.osdVolume ? "V" : "") + (ShellState.osdMic ? "M" : "") + (ShellState.osdBright ? "B" : "")
                    }

                    YRow {
                        width: parent.width
                        title: "Volume"
                        sub: "sink + player changes"

                        YSwitch {
                            checked: ShellState.osdVolume
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("osdVolume", checked)
                        }
                    }

                    YRow {
                        width: parent.width
                        title: "Microphone"
                        sub: "input level changes"

                        YSwitch {
                            checked: ShellState.osdMic
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("osdMic", checked)
                        }
                    }

                    YRow {
                        width: parent.width
                        title: "Brightness"
                        sub: DisplayService.available ? DisplayService.displays.map(d => d.label).join(", ").toLowerCase() : "no backend (install brightnessctl or ddcutil)"

                        YSwitch {
                            checked: ShellState.osdBright
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("osdBright", checked)
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        YButton {
                            label: "TEST VOL"
                            onClicked: AudioService.osdPing("volume")
                        }

                        YButton {
                            label: "TEST MIC"
                            onClicked: AudioService.osdPing("mic")
                        }

                        YButton {
                            label: "TEST BRIGHT"
                            enabled: DisplayService.available
                            onClicked: AudioService.osdPing("bright")
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "03"
                        label: "Size"
                        chip: ShellState.osdWidth + "px"
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp2

                        YButton {
                            width: 32
                            label: "−"
                            onClicked: ShellState.set("osdWidth", Math.max(300, ShellState.osdWidth - 40))
                        }

                        YButton {
                            width: 32
                            label: "+"
                            onClicked: ShellState.set("osdWidth", Math.min(720, ShellState.osdWidth + 40))
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "04"
                        label: "Fade"
                        chip: ShellState.osdFadeMs + "ms"
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp2

                        YButton {
                            width: 32
                            label: "−"
                            onClicked: ShellState.set("osdFadeMs", Math.max(600, ShellState.osdFadeMs - 200))
                        }

                        YButton {
                            width: 32
                            label: "+"
                            onClicked: ShellState.set("osdFadeMs", Math.min(4000, ShellState.osdFadeMs + 200))
                        }
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }

            Component {
                id: barPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Layout"
                        chip: ShellState.barScale + "× · " + ShellState.barPosition.toUpperCase()
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp2

                        YButton {
                            width: 32
                            label: "−"
                            onClicked: ShellState.set("barScale", Math.max(0.8, ShellState.barScale - 0.1))
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ShellState.barScale.toFixed(1) + "×"
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBody
                            font.weight: Font.Bold
                        }

                        YButton {
                            width: 32
                            label: "+"
                            onClicked: ShellState.set("barScale", Math.min(1.4, ShellState.barScale + 0.1))
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        Repeater {
                            model: [{
                                    id: "top",
                                    label: "TOP"
                                }, {
                                    id: "bottom",
                                    label: "BOTTOM"
                                }]

                            delegate: YButton {
                                required property var modelData

                                tone: ShellState.barPosition === modelData.id ? "acid" : "default"
                                label: modelData.label
                                onClicked: ShellState.set("barPosition", modelData.id)
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "Workspaces"
                        chip: (ShellState.wsMode === "active" ? "ACTIVE ONLY" : ShellState.wsMode.toUpperCase())
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        Repeater {
                            model: [{
                                    id: "default",
                                    label: "DEFAULT"
                                }, {
                                    id: "numbers",
                                    label: "NUMBERS"
                                }, {
                                    id: "pills",
                                    label: "PILLS"
                                }, {
                                    id: "active",
                                    label: "ACTIVE ONLY"
                                }]

                            delegate: YButton {
                                required property var modelData

                                tone: ShellState.wsMode === modelData.id ? "acid" : "default"
                                label: modelData.label
                                onClicked: ShellState.set("wsMode", modelData.id)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "DEFAULT numbered pills · NUMBERS bare digits · PILLS boxes without digits · ACTIVE ONLY occupied/focused workspaces"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        wrapMode: Text.WordWrap
                    }

                    YSection {
                        width: parent.width
                        index: "03"
                        label: "Segments"
                        chip: BarSegments.model.length + " · " + (BarSegments.leftVisible.length + BarSegments.rightVisible.length) + " visible"
                    }

                    Repeater {
                        model: BarSegments.model

                        delegate: Item {
                            id: segRow

                            required property int index
                            required property var modelData

                            readonly property var meta: BarSegments.meta[modelData.id] ?? { label: modelData.id, jp: "" }
                            readonly property bool on_: modelData.enabled !== false
                            // these three render inside the stats cluster box,
                            // not as placeable bar blocks
                            readonly property bool embedded: ["cputemp", "gpu", "disk"].indexOf(modelData.id) >= 0
                            // state-driven chips only appear while active — tell
                            // the user why the bar looks unchanged after enabling
                            readonly property string inactiveWhy: {
                                if (!segRow.on_ || BarSegments.present(modelData.id))
                                    return "";
                                switch (modelData.id) {
                                case "media":
                                    return "inactive · shows when media plays";
                                case "bt":
                                    return "inactive · shows when bluetooth is on";
                                case "nightlight":
                                    return "inactive · toggle night light first";
                                case "session":
                                    return "inactive · shows while idle inhibitors run";
                                case "recording":
                                    return "inactive · shows while recording";
                                case "pluginwidgets":
                                    return "inactive · enable a plugin first";
                                default:
                                    return "";
                                }
                            }

                            width: root.contentW
                            height: 40

                            Rectangle {
                                anchors.fill: parent
                                color: segArea.containsMouse ? Theme.surface : "transparent"
                            }

                            Text {
                                id: segLabel

                                anchors.left: parent.left
                                anchors.leftMargin: Theme.sp2
                                anchors.right: statusNote.left
                                anchors.rightMargin: Theme.sp1
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: segRow.meta.label
                                color: segRow.on_ ? Theme.ink : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                                font.weight: Font.DemiBold
                            }

                            Text {
                                id: statusNote

                                anchors.right: actChip.left
                                anchors.rightMargin: Theme.sp2
                                anchors.verticalCenter: parent.verticalCenter
                                width: visible ? contentWidth : 0
                                visible: segRow.inactiveWhy.length > 0
                                text: segRow.inactiveWhy
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                            }

                            // click-action chip — cycles the segment's click
                            // target; DEFAULT clears the override back to the
                            // built-in sane default
                            Rectangle {
                                id: actChip

                                readonly property bool hasPref: {
                                    try {
                                        const m = JSON.parse(ShellState.barClick);
                                        return !!m[segRow.modelData.id];
                                    } catch (e) {
                                        return false;
                                    }
                                }
                                readonly property string effective: BarSegments.clickFor(segRow.modelData.id)
                                readonly property var cycle: ["", "calendar", "network", "bluetooth", "audio", "media", "controlcenter", "launcher", "settings", "nightlight", "power", "notifications"]

                                function bump() {
                                    let idx = cycle.indexOf(effective);
                                    if (idx < 0)
                                        idx = 0;
                                    BarSegments.setClick(segRow.modelData.id, cycle[(idx + 1) % cycle.length]);
                                }

                                anchors.right: rightCluster.left
                                anchors.rightMargin: Theme.sp2
                                anchors.verticalCenter: parent.verticalCenter
                                width: actText.width + 14
                                height: 16
                                color: actArea.containsMouse && segRow.on_ ? Theme.acid : "transparent"
                                border.width: 1
                                border.color: hasPref ? (actArea.containsMouse && segRow.on_ ? Theme.acid : Theme.acidDeep) : Theme.lineStrong

                                Text {
                                    id: actText

                                    anchors.centerIn: parent
                                    text: actChip.hasPref ? actChip.effective.toUpperCase() : "DEFAULT"
                                    color: actArea.containsMouse && segRow.on_ ? Theme.bg : actChip.hasPref ? Theme.acid : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.5
                                }

                                MouseArea {
                                    id: actArea

                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: actChip.bump()
                                }
                            }

                            // zone chips — replaced by a static STATS tag on
                            // the cluster-embedded rows
                            Item {
                                id: rightCluster

                                anchors.right: segSwitch.left
                                anchors.rightMargin: Theme.sp2
                                anchors.verticalCenter: parent.verticalCenter
                                height: 16
                                width: segRow.embedded ? statsTag.width : zoneChips.width

                                Row {
                                    id: zoneChips

                                    visible: !segRow.embedded
                                    spacing: 2

                                    Repeater {
                                        model: ["left", "center", "right"]

                                        delegate: Item {
                                            required property var modelData

                                            width: 22
                                            height: 16

                                            Rectangle {
                                                anchors.fill: parent
                                                color: segRow.modelData.zone === modelData ? Theme.acid : "transparent"
                                                border.width: 1
                                                border.color: Theme.lineStrong
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData.charAt(0).toUpperCase()
                                                color: segRow.modelData.zone === modelData ? Theme.bg : Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsMicro
                                                font.weight: Font.Bold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: BarSegments.setZone(segRow.modelData.id, modelData)
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: statsTag

                                    visible: segRow.embedded
                                    width: tagText.width + 12
                                    height: 16
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Theme.lineStrong

                                    Text {
                                        id: tagText

                                        anchors.centerIn: parent
                                        text: "STATS+"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        font.weight: Font.Bold
                                        font.letterSpacing: 0.5
                                    }
                                }
                            }

                            YSwitch {
                                id: segSwitch

                                checked: segRow.on_
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.sp2
                                onToggled: BarSegments.setEnabled(segRow.modelData.id, !segRow.modelData.enabled)
                            }

                            // up/down reorder
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.sp2
                                visible: segArea.containsMouse && !segRow.embedded
                                spacing: 1

                                Text {
                                    text: "▲"
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: BarSegments.move(segRow.modelData.id, -1)
                                    }
                                }

                                Text {
                                    text: "▼"
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro

                                    MouseArea {
                                        anchors.fill: parent
                                        anchors.margins: -4
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: BarSegments.move(segRow.modelData.id, 1)
                                    }
                                }
                            }

                            MouseArea {
                                id: segArea

                                anchors.fill: parent
                                anchors.leftMargin: 30
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp2

                        YButton {
                            label: "RESET SEGMENTS"
                            onClicked: BarSegments.reset()
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "restore the default order, zones and toggles"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                        }
                    }

                    Text {
                        width: parent.width
                        text: "hover a row for ▲▼ reorder · L/C/R picks which zone it renders in (C = true screen center) · state chips (media/bluetooth/night light/inhibit/recording) only appear on the bar while their condition is active · STATS+ rows render inside the stats box · the action chip cycles what a click opens — DEFAULT restores the built-in"
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
                id: shellPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Clock"
                        chip: ShellState.clock24h ? "24H" : "12H"
                    }

                    YRow {
                        width: root.contentW
                        title: "24-hour clock"
                        sub: ShellState.clock24h ? "HH:MM" : "12-hour with AM/PM"
                        note: "CLK"
                        on_: ShellState.clock24h

                        YSwitch {
                            checked: ShellState.clock24h
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("clock24h", !ShellState.clock24h)
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "Location"
                        chip: Weather.configured ? Weather.locLabel.toUpperCase() : "UNSET"
                    }

                    // AUTO resolves by IP (drives weather + timezone);
                    // MANUAL uses static coords. Legacy "" behaves as auto.
                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        YButton {
                            tone: Geo.modeAuto ? "acid" : "default"
                            label: "AUTO · IP"
                            onClicked: ShellState.set("weatherMode", "auto")
                        }

                        YButton {
                            tone: !Geo.modeAuto ? "acid" : "default"
                            label: "MANUAL"
                            onClicked: ShellState.set("weatherMode", "manual")
                        }

                        Item {
                            width: Theme.sp2
                            height: 1
                        }

                        YButton {
                            label: Geo.resolving ? "…" : "REDETECT"
                            enabled: Geo.modeAuto && Geo.available && !Geo.resolving
                            onClicked: Geo.detect(true)
                        }
                    }

                    Text {
                        width: parent.width
                        visible: Geo.modeAuto
                        text: {
                            if (!Geo.available)
                                return "curl missing — install curl for IP location";
                            if (Geo.resolving)
                                return "resolving by ip…";
                            if (Geo.error.length > 0)
                                return "lookup failed — will retry";
                            return Weather.configured ? Weather.locLabel + "  ·  " + (Geo.tz.length > 0 ? Geo.tz : "tz n/a") + "  ·  " + Geo.latStr + ", " + Geo.lonStr : "no fix yet";
                        }
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        elide: Text.ElideRight
                    }

                    Item {
                        width: parent.width
                        height: 8
                        visible: Geo.modeManual
                    }

                    // manual coordinate entry (visible in MANUAL mode; applying
                    // from AUTO switches modes implicitly via weatherMode=manual)
                    YField {
                        id: weatherLatField

                        width: root.contentW
                        visible: Geo.modeManual
                        placeholder: "latitude (e.g. 35.68)"
                    }

                    YField {
                        id: weatherLonField

                        width: root.contentW
                        visible: Geo.modeManual
                        placeholder: "longitude (e.g. 139.69)"
                    }

                    YField {
                        id: weatherLabelField

                        width: root.contentW
                        visible: Geo.modeManual
                        placeholder: "location label (e.g. TOKYO)"
                    }

                    YButton {
                        visible: Geo.modeManual
                        label: "APPLY LOCATION"
                        tone: "acid"
                        onClicked: {
                            if (weatherLatField.text.length > 0 && weatherLonField.text.length > 0) {
                                ShellState.set("weatherLat", weatherLatField.text.trim());
                                ShellState.set("weatherLon", weatherLonField.text.trim());
                                ShellState.set("weatherLabel", weatherLabelField.text.trim());
                                ShellState.set("weatherMode", "manual");
                                Weather.refresh();
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "03"
                        label: "Screenshot"
                        chip: Screenshot.status()
                    }

                    YField {
                        id: shotDirField

                        width: root.contentW
                        placeholder: "save directory (default ~/Pictures/Shots)"
                        onAccepted: {
                            if (text.trim().length > 0)
                                ShellState.set("shotDir", text.trim());
                            text = "";
                        }
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }

            Component {
                id: securityPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Offline mode"
                        chip: Connectivity.airplane ? "AIRPLANE" : "ONLINE"
                    }

                    YRow {
                        width: root.contentW
                        title: "Airplane mode"
                        sub: Connectivity.airplane ? "wifi + bluetooth radios down" : "radios up"
                        note: "AIR"
                        on_: Connectivity.airplane

                        YSwitch {
                            checked: Connectivity.airplane
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: {
                                const next = !Connectivity.airplane;
                                Networking.wifiEnabled = !next;
                                if (Bluetooth.defaultAdapter)
                                    Bluetooth.defaultAdapter.enabled = !next;
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "Lock screen"
                        chip: "PAM " + ShellState.pamService
                    }

                    YRow {
                        width: root.contentW
                        title: "Lock on all monitors"
                        sub: ShellState.lockMonitors === "all" ? "every screen renders the auth card" : "primary screen only"
                        note: "MON"
                        on_: ShellState.lockMonitors === "all"

                        YSwitch {
                            checked: ShellState.lockMonitors === "all"
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("lockMonitors", ShellState.lockMonitors === "all" ? "primary" : "all")
                        }
                    }

                    YRow {
                        width: root.contentW
                        title: "Bar inhibit indicator"
                        sub: "a chip shows when an app holds the idle/sleep lock"
                        note: "INH"
                        on_: ShellState.barSession

                        YSwitch {
                            checked: ShellState.barSession
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("barSession", !ShellState.barSession)
                        }
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }

            Component {
                id: servicesPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Audio"
                        chip: "overdrive " + ShellState.audioCeiling + "%"
                    }

                    YRow {
                        width: root.contentW
                        title: "Overdrive ceiling"
                        sub: "volume allowed past 100%, flagged in acid"
                        note: "VOL"
                        interactive: false

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.sp1

                            YButton {
                                width: 30
                                label: "−"
                                onClicked: ShellState.set("audioCeiling", Math.max(100, ShellState.audioCeiling - 10))
                            }

                            YButton {
                                width: 30
                                label: "+"
                                onClicked: ShellState.set("audioCeiling", Math.min(200, ShellState.audioCeiling + 10))
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "Display"
                        chip: DisplayService.available ? "DDC/CI" : "UNAVAILABLE"
                    }

                    YRow {
                        width: root.contentW
                        title: "Monitor brightness"
                        sub: DisplayService.available ? DisplayService.displays.length + " display(s) · " + DisplayService.brightPct + "%" : "install ddcutil for DDC/CI control"
                        note: "SUN"
                        interactive: false
                    }

                    YSection {
                        width: parent.width
                        index: "03"
                        label: "Night light"
                        chip: NightLight.available ? (NightLight.active ? "ACTIVE" : "IDLE") : "NO HYPRSUNSET"
                    }

                    YRow {
                        width: root.contentW
                        title: "Night light filter"
                        sub: NightLight.available ? NightLight.temp + "K warmth" : "install hyprsunset"
                        note: "☾"
                        on_: NightLight.active

                        YSwitch {
                            checked: NightLight.active
                            enabled: NightLight.available
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: NightLight.toggle()
                        }
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }

            Component {
                id: powerPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Power plan"
                        chip: Session.ppdAvailable ? Session.profileName.toUpperCase() : "NO PPD"
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        Repeater {
                            model: [{
                                    id: "saver",
                                    label: "SAVER"
                                }, {
                                    id: "balanced",
                                    label: "BALANCED"
                                }, {
                                    id: "performance",
                                    label: "PERF"
                                }]

                            delegate: YButton {
                                required property var modelData

                                tone: Session.ppdAvailable && Session.profileName === modelData.id ? "acid" : "default"
                                label: modelData.label
                                enabled: Session.ppdAvailable
                                onClicked: Session.setProfile(modelData.id)
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "02"
                        label: "Idle"
                        chip: ShellState.idleAction === "none" ? "off" : ShellState.idleAction + " · " + ShellState.idleSecs + "s"
                    }

                    Row {
                        width: parent.width
                        spacing: Theme.sp1

                        Repeater {
                            model: [{
                                    id: "none",
                                    label: "OFF"
                                }, {
                                    id: "lock",
                                    label: "LOCK"
                                }, {
                                    id: "suspend",
                                    label: "SUSPEND"
                                }, {
                                    id: "shutdown",
                                    label: "SHUTDOWN"
                                }]

                            delegate: YButton {
                                required property var modelData

                                tone: ShellState.idleAction === modelData.id ? "acid" : "default"
                                label: modelData.label
                                onClicked: ShellState.set("idleAction", modelData.id)
                            }
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "03"
                        label: "Power menu"
                        chip: ShellState.holdMs > 0 ? "hold " + ShellState.holdMs + "ms" : "no hold"
                    }

                    YRow {
                        width: root.contentW
                        title: "Hold to confirm"
                        sub: ShellState.holdMs > 0 ? "destructive tiles need a press-and-hold" : "destructive tiles fire immediately"
                        note: "HOLD"
                        on_: ShellState.holdMs > 0

                        YSwitch {
                            checked: ShellState.holdMs > 0
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: ShellState.set("holdMs", ShellState.holdMs > 0 ? 0 : 1100)
                        }
                    }

                    YSection {
                        width: parent.width
                        index: "04"
                        label: "Battery"
                        chip: UPower.displayDevice && UPower.displayDevice.isPresent ? Math.round(UPower.displayDevice.percentage) + "%" : "NO BAT"
                    }

                    YRow {
                        width: root.contentW
                        title: "Battery"
                        sub: UPower.displayDevice && UPower.displayDevice.isPresent ? "present" : "no battery on this machine"
                        note: "BAT"
                        interactive: false
                        on_: UPower.displayDevice && UPower.displayDevice.isPresent
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }

            Component {
                id: pluginsPage

                PluginsPage {
                    contentW: root.contentW
                }
            }

            Component {
                id: aboutPage

                Column {
                    width: root.contentW
                    spacing: Theme.sp3

                    // frame already prints "About" — version line carries the identity
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
