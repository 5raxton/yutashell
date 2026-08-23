import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import Quickshell.Networking
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "../audio"
import "../net"
import "../widgets"
import "../notify"
import "../session"

// Control center (PH.15) — one themed popup falling from the bar that answers
// "what's going on / quick toggle / quick adjust". Read-mostly: deep config
// stays in settings. Eleven lazy tabs behind a sliding acid underline; every
// list builds only when its tab is visited.
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
    visible: ShellState.ccOpen || hideDelay.running
    mask: Region {
        item: ShellState.ccOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.ccOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(720, contentRoot.width - Theme.outerPad * 2)
    readonly property int cardH: Math.min(560, contentRoot.height - Theme.barHeight - Theme.outerPad * 2)
    readonly property int padX: Theme.sp4
    readonly property int tabH: Theme.barHeight
    readonly property int contentW: cardW - padX * 2 - 1

    property int tabIndex: 0

    readonly property var pages: [
        { id: "home", label: "HOME", jp: "家" },
        { id: "media", label: "MEDIA", jp: "媒" },
        { id: "audio", label: "AUDIO", jp: "音" },
        { id: "monitors", label: "MON", jp: "画" },
        { id: "system", label: "SYS", jp: "系" },
        { id: "power", label: "PWR", jp: "電" },
        { id: "network", label: "NET", jp: "網" },
        { id: "bluetooth", label: "BT", jp: "歯" },
        { id: "weather", label: "WX", jp: "天" },
        { id: "calendar", label: "CAL", jp: "暦" },
        { id: "notifications", label: "NOTIF", jp: "知" }
    ]

    readonly property var activePage: visiblePages[Math.max(0, Math.min(tabIndex, visiblePages.length - 1))]
    readonly property string activePageId: activePage.id

    // visible tabs, in the persisted order (PH.16 CC tab edits this)
    readonly property var visiblePages: {
        try {
            const ids = JSON.parse(ShellState.ccTabs);
            if (Array.isArray(ids) && ids.length > 0)
                return ids.map(id => root.pages.find(p => p.id === id)).filter(Boolean);
        } catch (e) {}
        return root.pages;
    }

    readonly property string anchorX: ShellState.ccAnchor === "left" ? "left" : ShellState.ccAnchor === "right" ? "right" : "center"

    // MPRIS player resolution (shared by HOME + MEDIA tabs)
    readonly property var players: Mpris.players.values ?? []
    readonly property var player: players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool playing: root.player?.isPlaying ?? false

    Timer {
        id: hideDelay

        interval: 190
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeCc()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeCc()
        }

        YSurface {
            id: surface

            open: ShellState.ccOpen
            anchorX: root.anchorX
            cardW: root.cardW
            cardH: root.cardH
            cascade: pageLoader.item

            // ---- header ----
            Item {
                x: root.padX
                y: 0
                width: surface.width - root.padX * 2 - 1
                height: Theme.headH

                Rectangle {
                    id: mark

                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.acid

                    Text {
                        anchors.centerIn: parent
                        text: "◈"
                        color: Theme.acid
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: mark.right
                    anchors.leftMargin: Theme.sp2
                    text: "CONTROL.CENTER"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 168
                    visible: Theme.jpEnabled
                    text: "中枢"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                }

                YButton {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    width: 30
                    label: "×"
                    onClicked: ShellState.closeCc()
                }
            }

            Rectangle {
                x: root.padX
                y: Theme.headH
                width: surface.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            // ---- tab strip ----
            Item {
                id: tabStrip

                x: root.padX
                y: Theme.headH + 1
                width: surface.width - root.padX * 2 - 1
                height: root.tabH

                Repeater {
                    model: root.visiblePages

                    delegate: Item {
                        id: tabSeg

                        required property int index
                        required property var modelData

                        readonly property bool isActive: root.tabIndex === index

                        x: index * (tabStrip.width / root.visiblePages.length)
                        width: tabStrip.width / root.visiblePages.length
                        height: tabStrip.height

                        Text {
                            anchors.centerIn: parent
                            text: tabSeg.modelData.label
                            color: tabSeg.isActive ? Theme.acid : tabArea.containsMouse ? Theme.ink : Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                            font.weight: tabSeg.isActive ? Font.Bold : Font.Normal
                            font.letterSpacing: 1.5
                        }

                        MouseArea {
                            id: tabArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tabIndex = tabSeg.index
                        }
                    }
                }

                Rectangle {
                    y: parent.height - 2
                    x: root.tabIndex * (parent.width / root.visiblePages.length)
                    width: parent.width / root.visiblePages.length
                    height: 2
                    color: Theme.acid

                    Behavior on x {
                        NumberAnimation {
                            duration: Theme.movFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.hairline
                }
            }

            // ---- page host ----
            Loader {
                id: pageLoader

                x: root.padX
                y: Theme.headH + 1 + root.tabH
                width: root.contentW
                height: surface.height - y - Theme.sp3
                active: ShellState.ccOpen
                sourceComponent: {
                    switch (root.activePageId) {
                    case "media":
                        return mediaPage;
                    case "audio":
                        return audioPage;
                    case "monitors":
                        return monitorsPage;
                    case "system":
                        return systemPage;
                    case "power":
                        return powerPage;
                    case "network":
                        return networkPage;
                    case "bluetooth":
                        return bluetoothPage;
                    case "weather":
                        return weatherPage;
                    case "calendar":
                        return calendarPage;
                    case "notifications":
                        return notificationsPage;
                    default:
                        return homePage;
                    }
                }
            }
        }
    }

    // ============================ HOME ============================
    Component {
        id: homePage

        Flickable {
            id: homeFlick

            width: root.contentW
            height: parent.height
            clip: true
            contentWidth: width
            contentHeight: homeCol.height
            boundsBehavior: Flickable.StopAtBounds

            FastWheel {}

            Column {
                id: homeCol

                width: parent.width
                spacing: Theme.sp3

                YSection {
                    width: parent.width
                    index: "01"
                    label: "Quick toggles"
                }

                // wifi / bt / night light / DND
                Grid {
                    width: parent.width
                    columns: 2
                    columnSpacing: Theme.sp2
                    rowSpacing: Theme.sp2

                    Repeater {
                        model: [{
                                key: "wifi",
                                title: "Wi-Fi",
                                on: Networking.wifiEnabled,
                                act: () => {
                                    Networking.wifiEnabled = !Networking.wifiEnabled;
                                }
                            }, {
                                key: "bt",
                                title: "Bluetooth",
                                on: Connectivity.btOn,
                                act: () => {
                                    if (Bluetooth.defaultAdapter)
                                        Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled;
                                }
                            }, {
                                key: "nightlight",
                                title: "Night light",
                                on: NightLight.active,
                                act: () => NightLight.toggle()
                            }, {
                                key: "dnd",
                                title: "Do not disturb",
                                on: Notify.dnd,
                                act: () => Notify.toggleDnd()
                            }]

                        delegate: Rectangle {
                            id: qtt

                            required property int index
                            required property var modelData

                            width: (homeCol.width - Theme.sp2) / 2
                            height: 52
                            color: qttArea.containsMouse ? Theme.surface : Theme.bg
                            border.width: 1
                            border.color: modelData.on ? Theme.acid : (qttArea.containsMouse ? Theme.lineStrong : Theme.hairline)

                            Row {
                                anchors.fill: parent
                                anchors.margins: Theme.sp2
                                spacing: Theme.sp2

                                Column {
                                    width: parent.width - 36
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1

                                    Text {
                                        text: qtt.modelData.title.toUpperCase()
                                        color: qtt.modelData.on ? Theme.acid : Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsLabel
                                        font.weight: Font.Bold
                                        font.letterSpacing: 1
                                    }

                                    Text {
                                        text: qtt.modelData.on ? "ON" : "OFF"
                                        color: Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                    }
                                }

                                YSwitch {
                                    anchors.verticalCenter: parent.verticalCenter
                                    checked: qtt.modelData.on
                                    onToggled: qtt.modelData.act()
                                }
                            }

                            MouseArea {
                                id: qttArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: qtt.modelData.act()
                            }
                        }
                    }
                }

                YSection {
                    width: parent.width
                    index: "02"
                    label: "Now"
                }

                // now-playing + weather + time line
                YRow {
                    width: parent.width
                    title: "Now playing"
                    sub: root.player ? (root.player.trackTitle || "—") : "nothing"
                    note: "MPRIS"
                    interactive: false
                }

                YRow {
                    width: parent.width
                    title: "Weather"
                    sub: Weather.configured ? (Weather.current ? Weather.current.temp + "° · " + Weather.codeInfo(Weather.current.code)[1] : "loading…") : "no location set"
                    note: "WX"
                    interactive: false
                }

                YRow {
                    width: parent.width
                    title: "Power plan"
                    sub: Session.ppdAvailable ? Session.profileName.toUpperCase() : "unavailable"
                    note: "PWR"
                    onToggled: Session.cycleProfile()
                }

                Item {
                    width: 1
                    height: Theme.sp2
                }
            }
        }
    }

    // ============================ MEDIA ============================
    Component {
        id: mediaPage

        Column {
            width: root.contentW
            spacing: Theme.sp3

            YSection {
                width: parent.width
                index: "01"
                label: "Player"
                chip: root.player ? root.player.identity.toUpperCase() : "NONE"
            }

            // art + transport (reuses the MediaWidget's player resolution)
            Row {
                width: parent.width
                spacing: Theme.sp3

                Rectangle {
                    width: 96
                    height: 96
                    color: Theme.acid

                    Image {
                        anchors.fill: parent
                        visible: root.player && root.player.trackArtUrl.length > 0 && status === Image.Ready
                        source: root.player && root.player.trackArtUrl.length > 0 ? root.player.trackArtUrl : ""
                        sourceSize.width: 192
                        sourceSize.height: 192
                        fillMode: Image.PreserveAspectCrop
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !(root.player && root.player.trackArtUrl.length > 0)
                        text: "♪"
                        color: Theme.bg
                        font.family: Theme.fontFamily
                        font.pixelSize: 34
                        font.weight: Font.ExtraBold
                    }
                }

                Column {
                    width: parent.width - 96 - Theme.sp3
                    spacing: Theme.sp1

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: (root.player?.trackTitle || "NOTHING PLAYING").toUpperCase()
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsTitle
                        font.weight: Font.ExtraBold
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: root.player?.trackArtist || ""
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                    }

                    Item {
                        height: Theme.sp2
                        width: 1
                    }

                    Row {
                        spacing: Theme.sp2

                        YButton {
                            width: 44
                            label: "⏮"
                            onClicked: {
                                if (root.player && root.player.canGoPrevious)
                                    root.player.previous();
                            }
                        }

                        YButton {
                            width: 56
                            tone: "acid"
                            label: root.playing ? "❚❚" : "▶"
                            onClicked: {
                                if (root.player && root.player.canTogglePlaying)
                                    root.player.togglePlaying();
                            }
                        }

                        YButton {
                            width: 44
                            label: "⏭"
                            onClicked: {
                                if (root.player && root.player.canGoNext)
                                    root.player.next();
                            }
                        }
                    }
                }
            }

            YSection {
                width: parent.width
                index: "02"
                label: "Visualizer"
                chip: "CAVA"
            }

            // static hairline baseline — the cava feed arrives in a later pass
            Row {
                width: parent.width
                height: 40
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 2

                Repeater {
                    model: 48

                    delegate: Rectangle {
                        anchors.bottom: parent.bottom
                        width: (parent.width - 47 * 2) / 48
                        height: 2 + (index % 5)
                        color: Theme.hairline
                    }
                }
            }

            Item {
                width: 1
                height: Theme.sp2
            }
        }
    }

    // ============================ AUDIO ============================
    Component {
        id: audioPage

        Flickable {
            width: root.contentW
            height: parent.height
            clip: true
            contentWidth: width
            contentHeight: audCol.height
            boundsBehavior: Flickable.StopAtBounds

            FastWheel {}

            Column {
                id: audCol

                width: parent.width
                spacing: Theme.sp3

                YSection {
                    width: parent.width
                    index: "01"
                    label: "Output"
                    chip: AudioService.sinks.length + " DEV"
                }

                Repeater {
                    model: AudioService.sinks

                    delegate: YRow {
                        id: sinkRow

                        required property var modelData

                        readonly property bool isDef: modelData === AudioService.sink

                        width: root.contentW
                        interactive: false
                        title: AudioService.deviceLabel(modelData).toUpperCase()
                        sub: (modelData.audio && modelData.audio.muted ? "muted" : AudioService.nodePct(modelData) + "%")
                        note: sinkRow.isDef ? "★ DEFAULT" : ""
                        on_: sinkRow.isDef

                        YSlider {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 140
                            value: AudioService.nodeFrac(sinkRow.modelData)
                            onMoved: v => AudioService.setFrac(sinkRow.modelData, v)
                        }
                    }
                }

                YSection {
                    width: parent.width
                    index: "02"
                    label: "Input"
                    chip: AudioService.sources.length + " DEV"
                }

                Repeater {
                    model: AudioService.sources

                    delegate: YRow {
                        id: srcRow

                        required property var modelData

                        width: root.contentW
                        interactive: false
                        title: AudioService.deviceLabel(modelData).toUpperCase()
                        sub: (modelData.audio && modelData.audio.muted ? "muted" : AudioService.nodePct(modelData) + "%")

                        YSwitch {
                            checked: modelData.audio && !modelData.audio.muted
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: AudioService.toggleMute(srcRow.modelData)
                        }
                    }
                }

                YSection {
                    width: parent.width
                    index: "03"
                    label: "Streams"
                    chip: AudioService.streams.length + " LIVE"
                }

                Repeater {
                    model: AudioService.streams

                    delegate: YRow {
                        id: strRow

                        required property var modelData

                        readonly property bool smut: modelData.audio ? modelData.audio.muted : false

                        width: root.contentW
                        interactive: false
                        title: AudioService.streamLabel(modelData).toUpperCase()
                        sub: strRow.smut ? "muted" : AudioService.nodePct(modelData) + "%"
                        on_: !strRow.smut

                        YSwitch {
                            checked: !strRow.smut
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: AudioService.toggleMute(strRow.modelData)
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

    // ============================ MONITORS ============================
    Component {
        id: monitorsPage

        Column {
            width: root.contentW
            spacing: Theme.sp3

            YSection {
                width: parent.width
                index: "01"
                label: "Brightness"
                chip: DisplayService.available ? "DDC/CI" : "UNAVAILABLE"
            }

            YRow {
                width: parent.width
                title: "External monitors"
                sub: DisplayService.available ? DisplayService.displays.length + " display(s) · " + DisplayService.brightPct + "%" : "install ddcutil for DDC/CI control"
                note: "SUN"
                interactive: false
            }

            YSlider {
                width: parent.width
                visible: DisplayService.available
                value: DisplayService.brightPct / 100
                onMoved: v => DisplayService.setBright(Math.round(v * 100))
            }

            Text {
                width: parent.width
                visible: !DisplayService.available
                text: "this box has no backlight and no ddcutil — brightness is unavailable."
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

    // ============================ SYSTEM ============================
    Component {
        id: systemPage

        Column {
            width: root.contentW
            spacing: Theme.sp3

            YSection {
                width: parent.width
                index: "01"
                label: "Live"
                chip: "FAST 2s · SLOW 5s"
            }

            // sparklines sample SystemStats while the tab is visible
            Timer {
                interval: 1000
                running: root.activePageId === "system" && ShellState.ccOpen
                repeat: true
                triggeredOnStart: true
                onTriggered: {
                    cpuSpark.push(SystemStats.cpuPct < 0 ? 0 : SystemStats.cpuPct / 100);
                    gpuSpark.push(SystemStats.gpuUtil < 0 ? 0 : SystemStats.gpuUtil / 100);
                    memSpark.push(SystemStats.memPct < 0 ? 0 : SystemStats.memPct / 100);
                    const net = Math.max(SystemStats.netDown, SystemStats.netUp);
                    netSpark.push(net < 0 ? 0 : Math.min(1, net / 2097152));
                }
            }

            // one spark row per metric
            Item {
                width: parent.width
                height: 40

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CPU"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemStats.cpuPct < 0 ? "--" : SystemStats.cpuPct + "%"
                    color: SystemStats.cpuPct >= 85 ? Theme.alert : Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.Bold
                }

                YSpark {
                    id: cpuSpark

                    anchors.left: parent.left
                    anchors.leftMargin: 52
                    anchors.right: parent.right
                    anchors.rightMargin: 60
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 4
                }
            }

            Item {
                width: parent.width
                height: 40

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "GPU"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemStats.gpuUtil < 0 ? "--" : SystemStats.gpuUtil + "%"
                    color: SystemStats.gpuUtil >= 95 ? Theme.alert : Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.Bold
                }

                YSpark {
                    id: gpuSpark

                    anchors.left: parent.left
                    anchors.leftMargin: 52
                    anchors.right: parent.right
                    anchors.rightMargin: 60
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 4
                }
            }

            Item {
                width: parent.width
                height: 40

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "MEM"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemStats.memPct < 0 ? "--" : SystemStats.memPct + "%"
                    color: SystemStats.memPct >= 90 ? Theme.alert : Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.Bold
                }

                YSpark {
                    id: memSpark

                    anchors.left: parent.left
                    anchors.leftMargin: 52
                    anchors.right: parent.right
                    anchors.rightMargin: 60
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 4
                }
            }

            Item {
                width: parent.width
                height: 40

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NET"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: SystemStats.fmtRate(Math.max(SystemStats.netDown, SystemStats.netUp))
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.Bold
                }

                YSpark {
                    id: netSpark

                    anchors.left: parent.left
                    anchors.leftMargin: 52
                    anchors.right: parent.right
                    anchors.rightMargin: 60
                    anchors.verticalCenter: parent.verticalCenter
                    height: parent.height - 4
                }
            }

            YSection {
                width: parent.width
                index: "02"
                label: "Sensors"
            }

            Repeater {
                model: SystemStats.temps

                delegate: YRow {
                    required property var modelData

                    width: root.contentW
                    interactive: false
                    title: modelData.label
                    sub: "temperature sensor"
                    note: modelData.temp + "°C"
                }
            }

            Item {
                width: 1
                height: Theme.sp2
            }
        }
    }

    // ============================ POWER ============================
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
                label: "Battery"
                chip: UPower.displayDevice && UPower.displayDevice.isPresent ? Math.round(UPower.displayDevice.percentage) + "%" : "NO BAT"
            }

            YRow {
                width: parent.width
                title: "Battery"
                sub: UPower.displayDevice && UPower.displayDevice.isPresent ? "battery present" : "no battery on this machine"
                note: "BAT"
                interactive: false
                on_: UPower.displayDevice && UPower.displayDevice.isPresent
            }

            YSection {
                width: parent.width
                index: "03"
                label: "Session"
            }

            YRow {
                width: parent.width
                title: "Power menu"
                sub: "lock · suspend · reboot · poweroff (hold-to-confirm)"
                note: "SESS"
                onToggled: Session.toggleMenu()
            }

            Item {
                width: 1
                height: Theme.sp2
            }
        }
    }

    // ============================ NETWORK ============================
    Component {
        id: networkPage

        Flickable {
            width: root.contentW
            height: parent.height
            clip: true
            contentWidth: width
            contentHeight: netCol.height
            boundsBehavior: Flickable.StopAtBounds

            FastWheel {}

            Column {
                id: netCol

                width: parent.width
                spacing: Theme.sp3

                YSection {
                    width: parent.width
                    index: "01"
                    label: "Radios"
                    chip: Connectivity.airplane ? "airplane" : ""
                }

                YRow {
                    width: parent.width
                    title: "Wi-Fi"
                    sub: !Connectivity.wifiDev ? "no wifi hardware" : (Networking.wifiEnabled ? "on" : "off")
                    note: "WFI"
                    interactive: Connectivity.wifiDev !== null
                    on_: Networking.wifiEnabled

                    YSwitch {
                        checked: Networking.wifiEnabled
                        enabled: Connectivity.wifiDev !== null
                        anchors.verticalCenter: parent.verticalCenter
                        onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
                    }
                }

                YSection {
                    width: parent.width
                    index: "02"
                    label: "Networks"
                    chip: Connectivity.activeWifi ? Connectivity.activeWifi.name.toUpperCase() : ""
                }

                Repeater {
                    model: Connectivity.wifiDev && Networking.wifiEnabled ? Connectivity.wifiDev.networks.values.slice().sort((a, b) => b.signalStrength - a.signalStrength).slice(0, 8) : []

                    delegate: YRow {
                        id: nrow

                        required property var modelData

                        width: parent.width
                        interactive: false
                        title: modelData.name
                        sub: "signal " + modelData.signalStrength + "%" + (modelData.connected ? " · connected" : "")
                        note: modelData.connected ? "●" : ""
                        on_: modelData.connected

                        YButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !modelData.connected
                            label: modelData.known ? "CONNECT" : "JOIN"
                            tone: "acid"
                            onClicked: modelData.known ? modelData.connect() : modelData.connect()
                        }
                    }
                }

                YSection {
                    width: parent.width
                    index: "03"
                    label: "VPN"
                    chip: Connectivity.vpnList.filter(v => v.active).length + " UP"
                }

                Repeater {
                    model: Connectivity.vpnList

                    delegate: YRow {
                        required property var modelData

                        width: parent.width
                        interactive: false
                        title: modelData.name
                        sub: modelData.type
                        note: modelData.active ? "UP" : ""

                        YSwitch {
                            checked: modelData.active
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: Connectivity.vpnToggle(modelData)
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

    // ============================ BLUETOOTH ============================
    Component {
        id: bluetoothPage

        Flickable {
            width: root.contentW
            height: parent.height
            clip: true
            contentWidth: width
            contentHeight: btCol.height
            boundsBehavior: Flickable.StopAtBounds

            FastWheel {}

            Column {
                id: btCol

                width: parent.width
                spacing: Theme.sp3

                YSection {
                    width: parent.width
                    index: "01"
                    label: "Adapter"
                    chip: Bluetooth.defaultAdapter ? (Bluetooth.defaultAdapter.enabled ? "ON" : "OFF") : "NONE"
                }

                YRow {
                    width: parent.width
                    title: "Bluetooth power"
                    sub: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled ? "radio up" : "radio down"
                    note: "PWR"
                    interactive: Bluetooth.defaultAdapter !== null
                    on_: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.enabled

                    YSwitch {
                        checked: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
                        enabled: Bluetooth.defaultAdapter !== null
                        anchors.verticalCenter: parent.verticalCenter
                        onToggled: if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                    }
                }

                YRow {
                    width: parent.width
                    visible: Bluetooth.defaultAdapter !== null && Bluetooth.defaultAdapter.enabled
                    title: "Scanning"
                    sub: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering ? "discovering…" : "idle"
                    note: "SCN"
                    on_: Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.discovering

                    YSwitch {
                        checked: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.discovering : false
                        anchors.verticalCenter: parent.verticalCenter
                        onToggled: if (Bluetooth.defaultAdapter)
                            Bluetooth.defaultAdapter.discovering = !Bluetooth.defaultAdapter.discovering
                    }
                }

                YSection {
                    width: parent.width
                    index: "02"
                    label: "Devices"
                    chip: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices.values.length + "" : "0"
                }

                Repeater {
                    model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices.values : []

                    delegate: YRow {
                        id: drow

                        required property var modelData

                        readonly property bool conn: modelData.connected

                        width: parent.width
                        interactive: false
                        title: modelData.deviceName.length > 0 ? modelData.deviceName : modelData.name
                        sub: drow.conn ? "connected" : (modelData.paired ? "paired" : "unpaired")
                        note: modelData.batteryAvailable ? Math.round(modelData.battery * 100) + "%" : ""
                        on_: drow.conn

                        YButton {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: modelData.paired
                            label: drow.conn ? "DISC" : "CONN"
                            tone: drow.conn ? "danger" : "acid"
                            onClicked: drow.conn ? modelData.disconnect() : modelData.connect()
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

    // ============================ WEATHER ============================
    Component {
        id: weatherPage

        Column {
            width: root.contentW
            spacing: Theme.sp3

            YSection {
                width: parent.width
                index: "01"
                label: "Conditions"
                chip: Weather.configured ? ShellState.weatherLabel.toUpperCase() : "UNSET"
            }

            Text {
                width: parent.width
                visible: !Weather.configured
                text: "no location — set via qs ipc call weather set <lat> <lon> <label>"
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLabel
                wrapMode: Text.WordWrap
            }

            Row {
                width: parent.width
                visible: Weather.configured && Weather.current !== null
                spacing: Theme.sp3

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Weather.current ? Weather.codeInfo(Weather.current.code)[0] : "·"
                    color: Theme.acid
                    font.family: Theme.fontFamily
                    font.pixelSize: 40
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Text {
                        text: (Weather.current ? Weather.current.temp : 0) + "°"
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: 34
                        font.weight: Font.ExtraBold
                    }

                    Text {
                        text: Weather.current ? Weather.codeInfo(Weather.current.code)[1] : ""
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                    }
                }
            }

            // 5-day strip
            Row {
                width: parent.width
                spacing: Theme.sp1
                visible: Weather.forecast.length > 0

                Repeater {
                    model: Weather.forecast

                    delegate: Rectangle {
                        required property int index
                        required property var modelData

                        width: (parent.width - Theme.sp1 * 4) / 5
                        height: 76
                        color: Theme.bg
                        border.width: 1
                        border.color: Theme.hairline

                        Column {
                            anchors.fill: parent
                            anchors.margins: Theme.sp2
                            spacing: 3

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][new Date(modelData.date).getDay()]
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.letterSpacing: 1
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: Weather.codeInfo(modelData.code)[0]
                                color: Theme.acid
                                font.family: Theme.fontFamily
                                font.pixelSize: 14
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.max + "°"
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                                font.weight: Font.Bold
                            }
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

    // ============================ CALENDAR ============================
    Component {
        id: calendarPage

        Column {
            width: root.contentW
            spacing: Theme.sp2

            property int calYear: new Date().getFullYear()
            property int calMonth: new Date().getMonth()
            readonly property string calMonthLabel: ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"][calMonth]

            YSection {
                width: parent.width
                index: "01"
                label: "Month"
                chip: calMonthLabel + " " + calYear
            }

            Row {
                width: parent.width
                spacing: Theme.sp2

                YButton {
                    width: 34
                    label: "◀"
                    onClicked: {
                        let m = calMonth - 1;
                        let y = calYear;
                        if (m < 0) {
                            m = 11;
                            y -= 1;
                        }
                        calMonth = m;
                        calYear = y;
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: calMonthLabel + " " + calYear
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsTitle
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 2
                }

                YButton {
                    width: 34
                    label: "▶"
                    onClicked: {
                        let m = calMonth + 1;
                        let y = calYear;
                        if (m > 11) {
                            m = 0;
                            y += 1;
                        }
                        calMonth = m;
                        calYear = y;
                    }
                }
            }

            CalendarGrid {
                width: parent.width
                year: calYear
                month: calMonth
            }

            Item {
                width: 1
                height: Theme.sp2
            }
        }
    }

    // ============================ NOTIFICATIONS ============================
    Component {
        id: notificationsPage

        Column {
            width: root.contentW
            spacing: Theme.sp3

            YSection {
                width: parent.width
                index: "01"
                label: "Do not disturb"
                chip: Notify.dnd ? "ON" : "OFF"
            }

            YRow {
                width: parent.width
                title: "Do not disturb"
                sub: Notify.dnd ? Notify.suppressedCount + " suppressed" : "toasts land normally"
                note: "DND"
                on_: Notify.dnd

                YSwitch {
                    checked: Notify.dnd
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: Notify.toggleDnd()
                }
            }

            YSection {
                width: parent.width
                index: "02"
                label: "History"
                chip: Notify.history.length + " KEPT"
            }

            Flickable {
                width: parent.width
                height: Math.min(300, parent.height - Theme.headH - Theme.sp4)
                clip: true
                contentWidth: width
                contentHeight: histCol.height
                boundsBehavior: Flickable.StopAtBounds

                FastWheel {}

                Column {
                    id: histCol

                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: Notify.history.slice(0, 30)

                        delegate: YRow {
                            id: hrow

                            required property int index
                            required property var modelData

                            width: parent.width
                            interactive: false
                            title: modelData.app.toUpperCase()
                            sub: modelData.sum + (modelData.body.length > 0 ? " — " + modelData.body.replace(/\n/g, " ").replace(/<[^>]*>/g, "") : "")
                            note: modelData.urg === 2 ? "CRIT" : (modelData.sup ? "QUIET" : "")

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.sp1

                                YButton {
                                    label: "↺"
                                    onClicked: Notify.replay(hrow.modelData)
                                }

                                YButton {
                                    label: "×"
                                    tone: "danger"
                                    onClicked: Notify.removeHistory(hrow.index)
                                }
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: Notify.history.length === 0
                        text: "NO HISTORY"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        font.letterSpacing: 3
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            YButton {
                label: "CLEAR ALL"
                tone: "danger"
                visible: Notify.history.length > 0
                onClicked: Notify.clearHistory()
            }

            Item {
                width: 1
                height: Theme.sp2
            }
        }
    }
}
