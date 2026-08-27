import Quickshell
import Quickshell.Wayland
import Quickshell.Wayland._IdleInhibitor as IdleMod
import QtQuick
import qs.theme
import qs.modules.common
import "ui"
import "../net"
import "../audio"
import "../session"
import "../widgets"
import "../common/ui"
import "../profiles"
import "../automation"
import "../dev"
import "../focus"
import "."

// Bar v2 (PH.14) — a data-driven organism. The layout (which segments, in
// which zone, in what order) is persisted in ShellState.barSegments and
// resolved by the BarSegments singleton; each segment composes its own
// component and honors its click-action via BarActions. Scale + position
// are persisted too. The bar stays on the Overlay layer — popups slide out
// from behind it.
PanelWindow {
    id: root

    property var tip

    // Overlay: topmost layer. Popups land on Top, so anything sliding down
    // emerges from BEHIND this bar.
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property bool topBar: ShellState.barPosition !== "bottom"

    anchors {
        top: root.topBar
        bottom: !root.topBar
        left: true
        right: true
    }

    implicitHeight: Theme.scaledBarHeight
    color: "transparent"

    Rectangle {
        id: frame

        anchors.fill: parent
        opacity: 0
        y: root.topBar ? -6 : 6
        color: Theme.bg

        // hairline — bottom edge for a top bar, top edge for a bottom bar
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: root.topBar ? parent.bottom : undefined
            anchors.top: root.topBar ? undefined : parent.top
            height: 1
            color: Theme.hairline
        }

        // acid glow along the bar edge — subtle ambient depth
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: root.topBar ? parent.bottom : undefined
            anchors.top: root.topBar ? undefined : parent.top
            height: 4
            color: Theme.acid
            opacity: 0.04
        }

        // the living strip — pulses at the bar's leading edge
        YPulse {
            x: Theme.outerPad
            y: root.topBar ? 0 : parent.height - height
            width: 132
            height: 2
            color: Theme.acid
            lo: 0.55
        }

        // content — sized to the scaled bar height, no transform needed;
        // fonts/spacing/padding all use Theme.barFs* tokens for proportional
        // sizing instead of geometric stretch
        Item {
            id: content

            x: 0
            y: 0
            width: parent.width
            height: Theme.scaledBarHeight

            // ---- LEFT ZONE ----
            Row {
                id: leftRow

                anchors.left: parent.left
                anchors.leftMargin: Theme.outerPad
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: root.rowModel("left")

                    delegate: segDelegate
                }
            }

            // ---- CENTER ZONE — true center, yields only on collision ------
            // Segments assigned zone "center" hold the exact middle of the
            // bar regardless of how wide the flanks grow; if the three zones
            // can't fit side by side the cluster slides right until it clears
            // the left row (clamped before it may kiss the right row).
            Row {
                id: centerRow

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.centerOffset
                anchors.verticalCenter: parent.verticalCenter
                visible: root.centerList.length > 0

                Repeater {
                    model: root.centerList

                    delegate: segDelegate
                }
            }

            // ---- ACTIVE WINDOW — the elastic fill between zones ----------
            // Alone in the center it stretches across the whole middle; with
            // real center segments present it hands the middle over and hugs
            // the left cluster instead.
            ActiveWindow {
                anchors.left: leftRow.right
                anchors.leftMargin: Theme.sp3
                anchors.right: root.centerList.length > 0 ? centerRow.left : rightRow.left
                anchors.rightMargin: Theme.sp3
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                visible: BarSegments.present("activewindow")
            }

            // ---- RIGHT ZONE ----
            Row {
                id: rightRow

                anchors.right: parent.right
                anchors.rightMargin: Theme.outerPad
                anchors.verticalCenter: parent.verticalCenter

                Repeater {
                    model: root.rowModel("right")

                    delegate: segDelegate
                }
            }
        }
    }

    function _renderable(id) {
        if (id.startsWith("spacer-"))
            return BarSegments.enabled(id);
        return id !== "activewindow" && BarSegments.present(id);
    }

    // center-zone segments minus the active-window fill and stat embeds
    readonly property var centerList: {
        const list = BarSegments.centerVisible;
        const out = [];
        for (let i = 0; i < list.length; i++)
            if (root._renderable(list[i].id))
                out.push(list[i]);
        return out;
    }

    function rowModel(zone) {
        const list = BarSegments.zoneList(zone);
        const out = [];
        for (let i = 0; i < list.length; i++)
            if (root._renderable(list[i].id))
                out.push(list[i]);
        return out;
    }

    // 0 when the centered cluster owns its natural slot; otherwise the smallest
    // rightward shift that clears the left row, clamped so it never overlaps
    // the right row either.
    readonly property real centerOffset: {
        const mid = content.width / 2;
        const half = centerRow.width / 2 + Theme.sp3;
        const minOffset = leftRow.width + Theme.outerPad + half - mid;
        const maxOffset = mid - rightRow.width - Theme.outerPad - half;
        if (minOffset <= 0)
            return 0;
        return Math.min(minOffset, Math.max(0, maxOffset));
    }

    // ---- segment delegate: divider gutter (except first) + the segment ----
    Component {
        id: segDelegate

        Row {
            required property int index
            required property var modelData

            spacing: 0

            DividerV {
                visible: index > 0
            }

            // Filler absorbs Loader stretch so segment keeps its natural size
            Loader {
                id: segLoader
                property string segId: modelData.id
                sourceComponent: {
                    PluginService._barPluginMap;
                    return root.segComponent(modelData.id);
                }
                // Prevent Loader from stretching the loaded item
                width: segLoader.item ? segLoader.item.implicitWidth : 0
                height: segLoader.item ? segLoader.item.implicitHeight : Theme.scaledBarHeight
                opacity: 0
                onLoaded: {
                    if (item) {
                        item.width = undefined;
                        item.height = undefined;
                    }
                    segFadeIn.start();
                }

                NumberAnimation {
                    id: segFadeIn
                    target: segLoader
                    property: "opacity"
                    from: 0; to: 1
                    duration: Theme.movMed
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    function segComponent(id) {
        switch (id) {
        case "identity":
            return identityComp;
        case "workspaces":
            return workspacesComp;
        case "taskbar":
            return taskbarComp;
        case "tray":
            return trayComp;
        case "media":
            return mediaComp;
        case "net":
            return netComp;
        case "bt":
            return btComp;
        case "audio":
            return audioComp;
        case "cpu":
            return statsComp;
        case "mem":
            return memComp;
        case "bat":
            return batComp;
        case "cputemp":
            return cputempComp;
        case "gpu":
            return gpuComp;
        case "disk":
            return diskComp;
        case "nightlight":
            return nlComp;
        case "session":
            return sessComp;
        case "recording":
            return recComp;
        case "mixer":
            return mixerComp;
        case "scratchpad":
            return scratchpadComp;
        case "pluginwidgets":
            return pluginWidgetsComp;
        case "pomodoro":
            return pomodoroComp;
        case "cheatsheet":
            return cheatsheetComp;
        case "profiles":
            return profilesComp;
        case "automation":
            return automationComp;
        case "git":
            return gitComp;
        case "docker":
            return dockerComp;
        case "cicd":
            return cicdComp;
        case "focus":
            return focusComp;
        case "clock":
            return clockComp;
        case "spacer":
            return spacerComp;
        }
        // fallback: bar plugin segments
        if (PluginService._barPluginMap[id])
            return pluginBarComp;
        return null;
    }

    Component {
        id: identityComp

        IdentityBlock {}
    }

    Component {
        id: workspacesComp

        Workspaces {}
    }

    Component {
        id: taskbarComp

        Taskbar {
            tip: root.tip
        }
    }

    Component {
        id: trayComp

        TrayCluster {
            tip: root.tip
        }
    }

    Component {
        id: mediaComp

        MediaBlock {
            tip: root.tip
        }
    }

    Component {
        id: netComp

        NetBlock {
            tip: root.tip
        }
    }

    Component {
        id: btComp

        BtBlock {
            tip: root.tip
        }
    }

    Component {
        id: audioComp

        AudioBlock {
            tip: root.tip
        }
    }

    Component {
        id: statsComp

        StatCell {
            kind: "cpu"
            tip: root.tip
        }
    }

    Component {
        id: memComp

        StatCell {
            kind: "mem"
            tip: root.tip
        }
    }

    Component {
        id: batComp

        StatCell {
            kind: "bat"
            tip: root.tip
        }
    }

    Component {
        id: cputempComp

        StatCell {
            kind: "cputemp"
            tip: root.tip
        }
    }

    Component {
        id: gpuComp

        StatCell {
            kind: "gpu"
            tip: root.tip
        }
    }

    Component {
        id: diskComp

        StatCell {
            kind: "disk"
            tip: root.tip
        }
    }

    Component {
        id: nlComp

        // Item root so the block fills the bar line like every other segment —
        // a bare Text inside the zone Row would top-align and ride high
        Item {
            implicitWidth: moonText.width
            implicitHeight: Theme.scaledBarHeight

            Text {
                id: moonText

                anchors.verticalCenter: parent.verticalCenter
                text: "☾"
                color: Theme.acid
                font.family: Theme.fontFamily
                font.pixelSize: Theme.barFsBody
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: BarActions.dispatch(BarSegments.clickFor("nightlight"))
            }
        }
    }

    Component {
        id: sessComp

        // Caffeine / inhibit chip — click toggles manual idle inhibit;
        // shows logind inhibitor count when present.
        Item {
            implicitWidth: sessRow.width
            implicitHeight: Theme.scaledBarHeight

            Row {
                id: sessRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: IdleInhibitor.manualInhibit ? "CAFFEINE" : "INHIBIT"
                    color: IdleInhibitor.manualInhibit ? Theme.acid : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Session.inhibitCount > 0
                    text: String(Session.inhibitCount)
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsLabel
                    font.weight: Font.DemiBold
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: IdleInhibitor.toggle()
            }
        }
    }

    Component {
        id: recComp

        Item {
            implicitWidth: recRow.width
            implicitHeight: Theme.scaledBarHeight

            Row {
                id: recRow

                spacing: 6
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(7 * Theme.barScale)
                    height: Math.round(7 * Theme.barScale)
                    color: Theme.alert

                    SequentialAnimation on opacity {
                        running: true
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 1.0
                            to: 0.25
                            duration: 620
                            easing.type: Easing.InOutSine
                        }
                        NumberAnimation {
                            from: 0.25
                            to: 1.0
                            duration: 620
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "REC"
                    color: Theme.alert
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Recording.stop()
            }
        }
    }

    Component {
        id: mixerComp

        MixerBar {
            tip: root.tip
        }
    }

    Component {
        id: scratchpadComp

        Item {
            implicitWidth: scratchChip.implicitWidth
            implicitHeight: Theme.scaledBarHeight

            YChip {
                id: scratchChip
                anchors.verticalCenter: parent.verticalCenter
                visible: {
                    let count = 0;
                    const vals = Hyprland.toplevels.values;
                    for (let i = 0; i < vals.length; i++) {
                        const wsId = vals[i].workspace ? vals[i].workspace.id : 0;
                        const wsName = vals[i].workspace ? String(vals[i].workspace.name) : "";
                        if (wsId < 0 || wsName === "magic")
                            count++;
                    }
                    return count > 0;
                }
                label: {
                    let count = 0;
                    const vals = Hyprland.toplevels.values;
                    for (let i = 0; i < vals.length; i++) {
                        const wsId = vals[i].workspace ? vals[i].workspace.id : 0;
                        const wsName = vals[i].workspace ? String(vals[i].workspace.name) : "";
                        if (wsId < 0 || wsName === "magic")
                            count++;
                    }
                    return "⊞ " + count;
                }
                tone: "outline"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.toggleScratchpad()
            }
        }
    }

    Component {
        id: pomodoroComp

        Item {
            implicitWidth: pomoRow.width
            implicitHeight: Theme.scaledBarHeight

            Row {
                id: pomoRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "⏱"
                    color: Pomodoro.phase === "work" ? Theme.acid : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsBody
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Pomodoro.label + " " + Pomodoro.display
                    color: Pomodoro.running ? Theme.ink : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Pomodoro.toggle()
                onWheel: function(event) {
                    if (event.angleDelta.y > 0) Pomodoro.start();
                    else Pomodoro.reset();
                }
            }
        }
    }

    Component {
        id: cheatsheetComp

        Item {
            implicitWidth: cheatText.implicitWidth + 12
            implicitHeight: Theme.scaledBarHeight

            Text {
                id: cheatText
                anchors.verticalCenter: parent.verticalCenter
                x: 6
                text: "⌨"
                color: ShellState.cheatsheetOpen ? Theme.acid : Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.barFsBody
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.toggleCheatsheet()
            }
        }
    }

    Component {
        id: profilesComp

        Item {
            implicitWidth: profRow.width + 12
            implicitHeight: Theme.scaledBarHeight

            Row {
                id: profRow
                anchors.verticalCenter: parent.verticalCenter
                x: 6
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "◆"
                    color: ProfileService.activeName.length > 0 ? Theme.acid : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsBody
                }

                Text {
                    visible: ProfileService.activeName.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: ProfileService.activeName.toUpperCase()
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ProfileService.cycle()
                onWheel: function(event) {
                    if (event.angleDelta.y > 0)
                        ProfileService.cycle();
                    else
                        ShellState.toggleProfiles();
                }
            }
        }
    }

    Component {
        id: automationComp

        Item {
            implicitWidth: autoRow.width + 12
            implicitHeight: Theme.scaledBarHeight

            Row {
                id: autoRow
                anchors.verticalCenter: parent.verticalCenter
                x: 6
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u26A1"
                    color: RuleService.rules.some(r => r.enabled) ? Theme.acid : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsBody
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: RuleService.rules.filter(r => r.enabled).length + " ACTIVE"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.toggleAutomation()
            }
        }
    }

    Component {
        id: gitComp

        Item {
            implicitWidth: gitRow.width + 12
            implicitHeight: Theme.scaledBarHeight

            Row {
                id: gitRow
                anchors.verticalCenter: parent.verticalCenter
                x: 6
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u2387"
                    color: GitService.isRepo ? Theme.acid : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsBody
                }

                Text {
                    visible: GitService.branch.length > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: GitService.branch
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    visible: GitService.dirty > 0
                    width: dirtyNum.implicitWidth + 8
                    height: 16
                    radius: 4
                    color: Theme.acid + "22"
                    border.width: 1
                    border.color: Theme.acid
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                        id: dirtyNum
                        anchors.centerIn: parent
                        text: GitService.dirty
                        color: Theme.acid
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        font.weight: Font.Bold
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.toggleDev()
            }
        }
    }

    Component {
        id: dockerComp

        Item {
            implicitWidth: dkRow.width + 12
            implicitHeight: Theme.scaledBarHeight

            Row {
                id: dkRow
                anchors.verticalCenter: parent.verticalCenter
                x: 6
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\uD83D\uDC33"
                    color: DockerService.projects.length > 0 ? Theme.acid : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsBody
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: DockerService.projects.length + " PROJ"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.toggleDev()
            }
        }
    }

    Component {
        id: cicdComp

        Item {
            implicitWidth: ciRow.width + 12
            implicitHeight: Theme.scaledBarHeight

            Row {
                id: ciRow
                anchors.verticalCenter: parent.verticalCenter
                x: 6
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: CIService.runs.some(r => r.conclusion === "failure") ? "\u2717" : "\u2713"
                    color: CIService.runs.some(r => r.conclusion === "failure") ? "#ff4444" : Theme.acid
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsBody
                    font.weight: Font.Bold
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: CIService.runs.length + " RUNS"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.toggleDev()
            }
        }
    }

    Component {
        id: focusComp

        Item {
            implicitWidth: focRow.width + 12
            implicitHeight: Theme.scaledBarHeight

            Row {
                id: focRow
                anchors.verticalCenter: parent.verticalCenter
                x: 6
                spacing: 6

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: FocusMode.focusing ? "\u25C9" : "\u25CB"
                    color: FocusMode.focusing ? Theme.acid : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsBody
                    font.weight: Font.Bold
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: FocusMode.focusing ? FocusMode.display : "FOCUS"
                    color: FocusMode.focusing ? Theme.ink : Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.barFsMicro
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }

                Text {
                    visible: FocusMode.round > 0
                    anchors.verticalCenter: parent.verticalCenter
                    text: "R" + FocusMode.round
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: ShellState.toggleFocus()
            }
        }
    }

    Component {
        id: clockComp

        ClockBlock {}
    }

    Component {
        id: spacerComp

        Item {
            implicitWidth: Theme.barSp4
            implicitHeight: Theme.scaledBarHeight
        }
    }

    // ---- boot entrance animation ----
    // Frame slides in from off-screen with opacity fade; a vertical acid
    // scanline sweeps left-to-right across the bar at startup.
    Rectangle {
        id: bootScanline

        width: 2
        height: parent.height
        color: Theme.acid
        opacity: 0
        x: -4
    }

    Timer {
        id: bootTimer

        interval: 300
        running: true
        repeat: false
        onTriggered: bootScanSweep.start()
    }

    NumberAnimation {
        id: bootFadeIn

        target: frame
        property: "opacity"
        from: 0
        to: 1
        duration: Theme.movSlow
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: bootSlideIn

        target: frame
        property: "y"
        from: root.topBar ? -6 : 6
        to: 0
        duration: Theme.movSlow
        easing.type: Easing.OutCubic
    }

    ParallelAnimation {
        id: bootScanSweep

        running: false

        SequentialAnimation {
            NumberAnimation {
                target: bootScanline
                property: "opacity"
                from: 0
                to: 0.9
                duration: 80
            }
            NumberAnimation {
                target: bootScanline
                property: "x"
                from: -4
                to: root.width + 4
                duration: 420
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: bootScanline
                property: "opacity"
                from: 0.9
                to: 0
                duration: 140
            }
        }
    }

    Component.onCompleted: {
        bootFadeIn.start();
        bootSlideIn.start();
    }

    // PH.01.2: Wayland idle-inhibit surface attached to the bar window.
    // When IdleInhibitor.inhibited is true, the compositor suppresses
    // idle timeout (screen blank, lock) for as long as this surface exists.
    IdleMod.IdleInhibitor {
        enabled: IdleInhibitor.inhibited
        window: root
    }

    // PH.05: widget plugins from <config>/plugins, enabled via settings
    Component {
        id: pluginWidgetsComp

        Item {
            implicitWidth: plugRow.width
            implicitHeight: Theme.scaledBarHeight

            Row {
                id: plugRow

                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.sp2

                Repeater {
                    model: PluginService.enabledWidgets

                    Loader {
                        required property var modelData

                        source: PluginService.componentUrl(modelData)
                        asynchronous: true
                    }
                }
            }
        }
    }

    Component {
        id: pluginBarComp

        Item {
            id: plugBar

            property string segId: parent ? parent.segId : ""

            implicitWidth: barLoader.item ? barLoader.item.implicitWidth : 0
            implicitHeight: Theme.scaledBarHeight

            Loader {
                id: barLoader
                width: item ? item.implicitWidth : 0
                height: item ? item.implicitHeight : Theme.scaledBarHeight
                source: {
                    var _ = PluginService._barPluginMap;
                    const mf = _[plugBar.segId];
                    return mf ? PluginService.barComponentUrl(mf) : "";
                }
                asynchronous: true
            }
        }
    }
}
