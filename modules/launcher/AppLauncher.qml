import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "fuzzy.js" as Fuzzy

// App launcher — centered overlay indexing every installed .desktop entry.
// Fuzzy subsequence ranking, grid/list modes, pins + recents weighting,
// ":command" mode driving the shell's own IPC implementations, inline
// calculator row, desktop-action rows. Prefs persist through ShellState.
PanelWindow {
    id: root

    readonly property bool open: ShellState.launcherOpen
    property bool everOpened: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.open || hideDelay.running
    // input lands ONLY on the card — desktop around it stays live
    mask: Region {
        item: root.open && uiLoader.item ? uiLoader.item : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // placement persists so PH.16's launcher tab can just edit values
    readonly property string anchorMode: ShellState.launcherAnchor === "left" ? "left" : ShellState.launcherAnchor === "right" ? "right" : "center"

    Timer {
        id: hideDelay

        interval: Theme.movMed
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: root.open

        Keys.onEscapePressed: ShellState.closeLauncher()

        // whole UI builds lazily on first open, then stays warm so every
        // later open paints instantly
        Loader {
            id: uiLoader

            anchors.fill: parent
            active: root.everOpened
            sourceComponent: cardComponent
        }
    }

    onVisibleChanged: {
        if (!visible)
            return;
        everOpened = true;
        if (uiLoader.item)
            uiLoader.item.resetForOpen();
    }

    Component {
        id: cardComponent

        YSurface {
            id: card

            open: root.open
            anchorX: root.anchorMode
            // compact center box — never a fullscreen feel
            cardW: Math.max(460, Math.min(820, ShellState.launcherW, Math.round(parent.width * 0.46)))
            cardH: Math.min(500, Math.round(parent.height * 0.55), parent.height - Theme.barHeight - 48)

            function resetForOpen() {
                searchField.text = "";
                selIdx = 0;
                searchField.forceFocus();
            }

            // ---- selection ----
            property int selIdx: 0
            readonly property int selCount: commandMode ? cmdMatches.length : results.length

            function clampSel() {
                selIdx = Math.max(0, Math.min(selIdx, Math.max(0, selCount - 1)));
            }

            function moveSel(d) {
                const n = selCount;
                if (n === 0)
                    return;
                selIdx = ((selIdx + d) % n + n) % n;
            }

            // ---- pins / recents (JSON id arrays in state.json) ----
            function parseIds(s) {
                try {
                    const v = JSON.parse(s);
                    return Array.isArray(v) ? v.filter(x => typeof x === "string") : [];
                } catch (err) {
                    return [];
                }
            }

            function pushRecent(id) {
                const r = parseIds(ShellState.launcherRecents).filter(x => x !== id);
                r.unshift(id);
                ShellState.set("launcherRecents", JSON.stringify(r.slice(0, 8)));
            }

            function removeRecent(id) {
                ShellState.set("launcherRecents", JSON.stringify(parseIds(ShellState.launcherRecents).filter(x => x !== id)));
            }

            function togglePin(id) {
                let p = parseIds(ShellState.launcherPins);
                p = p.includes(id) ? p.filter(x => x !== id) : [id].concat(p);
                ShellState.set("launcherPins", JSON.stringify(p));
            }

            readonly property var pinIds: parseIds(ShellState.launcherPins)

            // ---- data ----
            readonly property var allApps: DesktopEntries.applications.values.filter(e => !e.noDisplay)
            readonly property string query: searchField.text
            readonly property bool commandMode: query.trimStart().startsWith(":")
            readonly property int mode: ShellState.launcherMode === "list" ? 1 : 0

            function byName(a, b) {
                return a.name.localeCompare(b.name);
            }

            function wrapApp(e) {
                return {
                    kind: "app",
                    entry: e,
                    action: null
                };
            }

            readonly property var results: {
                const q = query.trim();
                const apps = allApps;
                let out = [];

                if (q.length === 0) {
                    const pinList = parseIds(ShellState.launcherPins).map(id => apps.find(e => e.id === id)).filter(Boolean);
                    const recs = parseIds(ShellState.launcherRecents).map(id => apps.find(e => e.id === id)).filter(e => e && !pinList.includes(e));
                    const rest = apps.filter(e => !pinList.includes(e) && !recs.includes(e)).sort(byName);
                    out = pinList.concat(recs, rest).map(wrapApp);
                } else {
                    const scored = [];
                    for (let i = 0; i < apps.length; i++) {
                        const s = Fuzzy.entryScore(q, apps[i]);
                        if (s >= 0)
                            scored.push({
                                s: s,
                                item: wrapApp(apps[i]),
                                name: apps[i].name
                            });
                        // desktop-action rows ride along once the query is real
                        if (q.length >= 2) {
                            const acts = apps[i].actions ?? [];
                            for (let j = 0; j < acts.length; j++) {
                                const as = Fuzzy.score(q, acts[j].name) * 0.85;
                                if (as > 0)
                                    scored.push({
                                        s: as,
                                        item: {
                                            kind: "action",
                                            entry: apps[i],
                                            action: acts[j]
                                        },
                                        name: acts[j].name
                                    });
                            }
                        }
                    }
                    scored.sort((a, b) => b.s - a.s || a.name.localeCompare(b.name));
                    out = scored.slice(0, 64).map(x => x.item);
                }
                return out;
            }

            // keep selection valid WITHOUT touching it inside the bindings —
            // clampSel reads selCount -> results, so calling it there loops
            onResultsChanged: clampSel()
            onCmdMatchesChanged: if (commandMode)
                clampSel()

            // ---- :command mode ----
            readonly property var commands: [{
                    cmd: ":scheme",
                    argHint: "<preset>",
                    desc: "apply scheme preset",
                    fn: a => Theme.applyPreset(String(a))
                }, {
                    cmd: ":wall",
                    argHint: "<next|random>",
                    desc: "cycle wallpaper",
                    fn: a => a === "random" ? Wallpaper.applyRandom() : Wallpaper.applyNext()
                }, {
                    cmd: ":dark",
                    argHint: "",
                    desc: "toggle light / dark",
                    fn: () => Theme.setDark(!Theme.dark)
                }, {
                    cmd: ":accent",
                    argHint: "<#hex|none>",
                    desc: "accent override",
                    fn: a => Theme.setAccent(String(a))
                }, {
                    cmd: ":panel",
                    argHint: "",
                    desc: "toggle control core",
                    fn: () => ShellState.togglePanel()
                }, {
                    cmd: ":picker",
                    argHint: "",
                    desc: "toggle wallpaper picker",
                    fn: () => ShellState.togglePicker()
                }]

            readonly property var cmdMatches: {
                if (!commandMode)
                    return [];
                const body = query.trimStart().slice(1);
                const sp = body.indexOf(" ");
                const head = (sp === -1 ? body : body.slice(0, sp)).toLowerCase();
                const args = sp === -1 ? "" : body.slice(sp + 1).trim();
                const m = commands.filter(c => head === "" || c.cmd.slice(1).startsWith(head)).map(c => ({
                            kind: "cmd",
                            c: c,
                            args: args
                        }));
                return m;
            }

            function runCommand(m) {
                try {
                    m.c.fn(m.args);
                } catch (err) {
                    console.warn("[launcher] command failed:", m.c.cmd, err);
                }
                ShellState.closeLauncher();
            }

            // calculator — charset whitelist means no identifiers reach eval
            readonly property string calcText: {
                const q = query.trim();
                if (q.startsWith(":") || !/[0-9]/.test(q) || !/[+\-*/^]/.test(q) || !/^[0-9+\-*/().^\s]+$/.test(q))
                    return "";
                try {
                    const v = Function('"use strict";return (' + q.replace(/\^/g, "**") + ')')();
                    if (typeof v !== "number" || !isFinite(v))
                        return "";
                    return String(Math.round(v * 1e10) / 1e10);
                } catch (err) {
                    return "";
                }
            }

            Process {
                id: copyProc

                command: ["wl-copy", card.calcText]
            }

            function acceptCurrent() {
                if (commandMode && selCount > 0) {
                    runCommand(cmdMatches[Math.min(selIdx, selCount - 1)]);
                    return;
                }
                if (calcText !== "") {
                    copyProc.exec();
                    ShellState.closeLauncher();
                    return;
                }
                activate(results[selIdx]);
            }

            function activate(r) {
                if (!r)
                    return;
                try {
                    if (r.kind === "action")
                        r.action.execute();
                    else
                        r.entry.execute();
                } catch (err) {
                    console.warn("[launcher] execute failed:", err);
                    return;
                }
                pushRecent(r.entry.id);
                ShellState.closeLauncher();
            }

            Component.onCompleted: if (root.open)
                resetForOpen()

            // ===== HEADER =====
            Item {
                id: header

                y: 0
                width: parent.width
                height: 46

                Text {
                    x: Theme.sp4
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.jpEnabled ? "アプリ // APP.LAUNCHER" : "APP.LAUNCHER"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.weight: Font.Bold
                    font.letterSpacing: 1.5
                }

                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp4
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp1

                    YButton {
                        label: "GRID"
                        tone: card.mode === 0 ? "acid" : "default"

                        onClicked: ShellState.set("launcherMode", "grid")
                    }

                    YButton {
                        label: "LIST"
                        tone: card.mode === 1 ? "acid" : "default"

                        onClicked: ShellState.set("launcherMode", "list")
                    }
                }
            }

            Rectangle {
                id: hairlineTop

                anchors.left: parent.left
                anchors.right: parent.right
                y: header.height
                height: 1
                color: Theme.hairline
            }

            // ===== SEARCH =====
            Item {
                id: searchBand

                anchors.top: hairlineTop.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: Theme.ctlH + Theme.sp3 * 2

                YField {
                    id: searchField

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: Theme.sp4
                    anchors.rightMargin: Theme.sp4
                    anchors.verticalCenter: parent.verticalCenter
                    placeholder: Theme.jpEnabled ? "検索 // SEARCH OR :COMMANDS" : "SEARCH OR :COMMANDS"
                    navKeys: true

                    onAccepted: card.acceptCurrent()
                    onNavUp: card.moveSel(-1)
                    onNavDown: card.moveSel(1)
                    onNavLeft: if (!card.commandMode && card.mode === 0)
                        card.moveSel(-gridView.cols)
                    onNavRight: if (!card.commandMode && card.mode === 0)
                        card.moveSel(gridView.cols)
                    onNavTab: {
                        ShellState.set("launcherMode", ShellState.launcherMode === "grid" ? "list" : "grid");
                        card.clampSel();
                    }
                    onNavEscape: ShellState.closeLauncher()
                    onNavShiftDel: {
                        const r = card.results[card.selIdx];
                        if (r && r.kind === "app")
                            card.removeRecent(r.entry.id);
                    }
                }
            }

            // ===== CALC STRIP =====
            Rectangle {
                id: calcStrip

                anchors.top: searchBand.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: card.calcText !== "" ? 34 : 0
                visible: height > 0
                color: Theme.surface

                Behavior on height {
                    NumberAnimation {
                        duration: Theme.movFast
                        easing.type: Easing.OutCubic
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: card.calcText !== ""

                    onClicked: {
                        copyProc.exec();
                        ShellState.closeLauncher();
                    }
                }

                Text {
                    x: Theme.sp4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "= " + card.calcText
                    color: Theme.acid
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.Bold
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp4
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.jpEnabled ? "クリックでコピー" : "CLICK TO COPY"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 0.8
                }
            }

            // ===== RESULTS =====
            Item {
                id: resultsArea

                anchors.top: calcStrip.bottom
                anchors.bottom: footer.top
                anchors.left: parent.left
                anchors.right: parent.right

                Text {
                    anchors.centerIn: parent
                    visible: !card.commandMode && card.results.length === 0
                    text: Theme.jpEnabled ? "該当なし // NO MATCH" : "NO MATCH"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 2
                }

                Text {
                    anchors.centerIn: parent
                    visible: card.commandMode && card.cmdMatches.length === 0
                    text: Theme.jpEnabled ? "不明なコマンド // UNKNOWN COMMAND" : "UNKNOWN COMMAND"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 2
                }

                ListView {
                    id: commandList

                    anchors.fill: parent
                    anchors.margins: Theme.sp2
                    visible: card.commandMode
                    clip: true
                    model: card.cmdMatches
                    currentIndex: card.selIdx
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: cmdRoot

                        required property var modelData
                        required property int index

                        readonly property bool sel: index === card.selIdx

                        width: commandList.width
                        height: 36

                        Rectangle {
                            anchors.fill: parent
                            color: cmdRoot.sel ? Theme.surface : "transparent"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 2
                                color: cmdRoot.sel ? Theme.acid : "transparent"
                            }
                        }

                        Text {
                            x: Theme.sp3
                            width: parent.width * 0.38
                            anchors.verticalCenter: parent.verticalCenter
                            text: cmdRoot.modelData.c.cmd + (cmdRoot.modelData.c.argHint !== "" ? " " + cmdRoot.modelData.c.argHint : "")
                            color: cmdRoot.sel ? Theme.acid : Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBody
                            elide: Text.ElideRight
                        }

                        Text {
                            x: parent.width * 0.38 + Theme.sp3
                            width: parent.width - parent.width * 0.38 - Theme.sp3 * 2
                            anchors.verticalCenter: parent.verticalCenter
                            text: cmdRoot.modelData.c.desc + (cmdRoot.modelData.args !== "" ? "  →  " + cmdRoot.modelData.args : "")
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBody
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            anchors.fill: parent

                            onClicked: card.runCommand(cmdRoot.modelData)
                        }
                    }
                }

                GridView {
                    id: gridView

                    readonly property int gridW: width - Theme.sp2 * 2
                    readonly property int cols: Math.max(4, Math.floor(gridW / 104))

                    anchors.fill: parent
                    anchors.margins: Theme.sp2
                    visible: !card.commandMode && card.mode === 0
                    clip: true
                    model: card.results
                    currentIndex: card.selIdx
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                    cellWidth: Math.floor(gridW / cols)
                    cellHeight: 92
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: tileRoot

                        required property var modelData
                        required property int index

                        width: gridView.cellWidth
                        height: gridView.cellHeight

                        readonly property bool sel: index === card.selIdx
                        readonly property bool isAction: modelData.kind === "action"
                        readonly property string iconSrc: isAction ? (modelData.action.icon ?? "") : (modelData.entry.icon ?? "")
                        readonly property string iconUrl: iconSrc === "" ? "" : Quickshell.iconPath(iconSrc)
                        readonly property string label: isAction ? modelData.action.name : modelData.entry.name

                        Rectangle {
                            id: tileBox

                            x: 4
                            y: 4
                            width: parent.width - 8
                            height: parent.height - 8
                            color: tileRoot.sel || area.containsMouse ? Theme.surface : "transparent"
                            border.width: 1
                            border.color: tileRoot.sel ? Theme.acid : "transparent"

                            Rectangle {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                width: 5
                                height: 5
                                color: Theme.acid
                                visible: !tileRoot.isAction && card.pinIds.includes(tileRoot.modelData.entry.id)
                            }

                            // acid square + initial when no icon resolves
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 10
                                width: 34
                                height: 34
                                color: Theme.acid
                                visible: tileRoot.iconSrc === "" || gTileIcon.status === Image.Error || gTileIcon.status === Image.Null

                                Text {
                                    anchors.centerIn: parent
                                    text: tileRoot.label.charAt(0).toUpperCase()
                                    color: Theme.bg
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsTitle
                                    font.weight: Font.ExtraBold
                                }
                            }

                            IconImage {
                                id: gTileIcon

                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: 10
                                implicitSize: 36
                                visible: tileRoot.iconUrl !== "" && gTileIcon.status !== Image.Error && gTileIcon.status !== Image.Null
                                source: tileRoot.iconUrl
                                asynchronous: true
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 8
                                text: tileRoot.label + (tileRoot.isAction ? " ↩" : "")
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                                horizontalAlignment: Text.AlignHCenter
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }
                        }

                        MouseArea {
                            id: area

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    if (!tileRoot.isAction)
                                        card.togglePin(tileRoot.modelData.entry.id);
                                    return;
                                }
                                if (mouse.button === Qt.LeftButton)
                                    card.activate(tileRoot.modelData);
                            }
                        }
                    }
                }

                ListView {
                    id: listView

                    anchors.fill: parent
                    anchors.margins: Theme.sp2
                    visible: !card.commandMode && card.mode === 1
                    clip: true
                    model: card.results
                    currentIndex: card.selIdx
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                    spacing: 1
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Item {
                        id: rowRoot

                        required property var modelData
                        required property int index

                        width: listView.width
                        height: 36

                        readonly property bool sel: index === card.selIdx
                        readonly property bool isAction: modelData.kind === "action"
                        readonly property string iconSrc: isAction ? (modelData.action.icon ?? "") : (modelData.entry.icon ?? "")
                        readonly property string iconUrl: iconSrc === "" ? "" : Quickshell.iconPath(iconSrc)
                        readonly property string label: isAction ? modelData.action.name : modelData.entry.name
                        readonly property string sub: isAction ? modelData.entry.name : (modelData.entry.genericName ?? "")

                        Rectangle {
                            anchors.fill: parent
                            color: rowRoot.sel ? Theme.surface : areaR.containsMouse ? Theme.bg : "transparent"

                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 2
                                color: rowRoot.sel ? Theme.acid : "transparent"
                            }

                            Rectangle {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                width: 5
                                height: 5
                                color: Theme.acid
                                visible: !rowRoot.isAction && card.pinIds.includes(rowRoot.modelData.entry.id)
                            }

                            Item {
                                x: 26
                                anchors.verticalCenter: parent.verticalCenter
                                width: 22
                                height: 22

                                Rectangle {
                                    anchors.fill: parent
                                    color: Theme.acid
                                    visible: rowRoot.iconSrc === "" || rRowIcon.status === Image.Error || rRowIcon.status === Image.Null

                                    Text {
                                        anchors.centerIn: parent
                                        text: rowRoot.label.charAt(0).toUpperCase()
                                        color: Theme.bg
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsLabel
                                        font.weight: Font.ExtraBold
                                    }
                                }

                                IconImage {
                                    id: rRowIcon

                                    anchors.fill: parent
                                    implicitSize: 22
                                    visible: rowRoot.iconUrl !== "" && rRowIcon.status !== Image.Error && rRowIcon.status !== Image.Null
                                    source: rowRoot.iconUrl
                                    asynchronous: true
                                }
                            }

                            Text {
                                x: 60
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 60 - subLabel.width - Theme.sp3 * 3
                                text: rowRoot.label + (rowRoot.isAction ? " ↩" : "")
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                            }

                            Text {
                                id: subLabel

                                anchors.right: parent.right
                                anchors.rightMargin: Theme.sp3
                                anchors.verticalCenter: parent.verticalCenter
                                text: rowRoot.sub
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                                width: Math.min(implicitWidth, parent.width * 0.35)
                            }
                        }

                        MouseArea {
                            id: areaR

                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton

                            onClicked: mouse => {
                                if (mouse.button === Qt.RightButton) {
                                    if (!rowRoot.isAction)
                                        card.togglePin(rowRoot.modelData.entry.id);
                                    return;
                                }
                                card.activate(rowRoot.modelData);
                            }
                        }
                    }
                }
            }

            // ===== FOOTER =====
            Rectangle {
                id: footer

                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 30
                color: Theme.bgAlt

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.hairline
                }

                YChip {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.sp4
                    anchors.verticalCenter: parent.verticalCenter
                    label: String(card.selCount) + (card.commandMode ? " CMD" : " APPS")
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp4
                    anchors.verticalCenter: parent.verticalCenter
                    text: "↵ RUN · ↑↓ NAV · ←→ GRID · TAB MODE · RCLICK PIN · ⇧DEL FORGET · ESC CLOSE"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 0.8
                }
            }
        }
    }
}
