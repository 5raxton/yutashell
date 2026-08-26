import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.notify
import "../common/ui"
import "fuzzy.js" as Fuzzy

// App launcher v2 — hacker-native command interface. Terminal-style search,
// category filtering, rich detail panel, grid/list/detail modes, pins + recents.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

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
    mask: Region {
        item: root.open ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property string anchorMode: ShellState.launcherAnchor === "left" ? "left" : ShellState.launcherAnchor === "right" ? "right" : "center"

    Timer {
        id: hideDelay
        interval: Theme.lingerMs
    }

    onOpenChanged: if (!root.open) hideDelay.restart()

    Item {
        id: contentRoot
        anchors.fill: parent
        focus: root.open

        Keys.onEscapePressed: ShellState.closeLauncher()

        YClickAway {
            id: clickAway
            onOutsideClicked: ShellState.closeLauncher()
        }

        Loader {
            id: uiLoader
            anchors.fill: parent
            active: root.everOpened
            sourceComponent: cardComponent
        }
    }

    onVisibleChanged: {
        if (!visible) return;
        everOpened = true;
        if (uiLoader.item) uiLoader.item.surface.resetForOpen();
    }

    // ---- frecency tracking ----
    function trackLaunch(appId) {
        let stats = {};
        try { stats = JSON.parse(ShellState.launcherStats); } catch (e) {}
        const existing = stats[appId] || {count: 0, lastLaunch: 0};
        existing.count += 1;
        existing.lastLaunch = Date.now();
        stats[appId] = existing;
        ShellState.set("launcherStats", JSON.stringify(stats));
    }

    // ---- safe calculator (recursive descent parser) ----
    function safeCalc(expr) {
        let pos = 0;
        const s = expr.replace(/\s+/g, "");

        function peek() { return pos < s.length ? s[pos] : null; }
        function advance() { return s[pos++]; }

        function parseExpr() { return parseAddSub(); }

        function parseAddSub() {
            let left = parseMulDiv();
            while (peek() === "+" || peek() === "-") {
                const op = advance();
                const right = parseMulDiv();
                left = op === "+" ? left + right : left - right;
            }
            return left;
        }

        function parseMulDiv() {
            let left = parsePower();
            while (peek() === "*" || peek() === "/" || peek() === "%") {
                const op = advance();
                const right = parsePower();
                if (op === "*") left *= right;
                else if (op === "/") left = right !== 0 ? left / right : NaN;
                else left = left % right;
            }
            return left;
        }

        function parsePower() {
            let left = parseUnary();
            if (peek() === "^") {
                advance();
                const right = parsePower();
                left = Math.pow(left, right);
            }
            return left;
        }

        function parseUnary() {
            if (peek() === "-") { advance(); return -parseAtom(); }
            if (peek() === "+") { advance(); return parseAtom(); }
            return parseAtom();
        }

        function parseAtom() {
            // parentheses
            if (peek() === "(") {
                advance();
                const v = parseExpr();
                if (peek() === ")") advance();
                return v;
            }
            // functions
            const funcs = {
                "sqrt": Math.sqrt, "abs": Math.abs, "sin": Math.sin,
                "cos": Math.cos, "tan": Math.tan, "log": Math.log10,
                "ln": Math.log, "floor": Math.floor, "ceil": Math.ceil,
                "round": Math.round
            };
            const consts = { "pi": Math.PI, "e": Math.E, "phi": (1 + Math.sqrt(5)) / 2 };

            let name = "";
            while (pos < s.length && /[a-zA-Z_]/.test(s[pos])) name += advance();
            if (name.length > 0) {
                if (consts[name] !== undefined) return consts[name];
                if (funcs[name]) {
                    if (peek() === "(") {
                        advance();
                        const arg = parseExpr();
                        if (peek() === ")") advance();
                        return funcs[name](arg);
                    }
                    return NaN;
                }
                return NaN; // unknown identifier
            }
            // number
            let num = "";
            while (pos < s.length && /[0-9.]/.test(s[pos])) num += advance();
            if (num.length === 0) return NaN;
            return parseFloat(num);
        }

        try {
            const result = parseExpr();
            if (pos < s.length || !isFinite(result)) return null;
            return result;
        } catch (e) { return null; }
    }

    // ---- color converter (#hex → rgb/hsl) ----
    function parseColor(input) {
        let hex = input.replace(/^#/, "").trim();
        if (hex.length === 3) hex = hex[0]+hex[0]+hex[1]+hex[1]+hex[2]+hex[2];
        if (hex.length !== 6 || !/^[0-9a-fA-F]{6}$/.test(hex)) return "ERR";
        const r = parseInt(hex.substring(0, 2), 16);
        const g = parseInt(hex.substring(2, 4), 16);
        const b = parseInt(hex.substring(4, 6), 16);
        // HSL conversion
        const rn = r / 255, gn = g / 255, bn = b / 255;
        const max = Math.max(rn, gn, bn), min = Math.min(rn, gn, bn);
        const l = (max + min) / 2;
        let h = 0, s = 0;
        if (max !== min) {
            const d = max - min;
            s = l > 0.5 ? d / (2 - max - min) : d / (max + min);
            if (max === rn) h = ((gn - bn) / d + (gn < bn ? 6 : 0)) / 6;
            else if (max === gn) h = ((bn - rn) / d + 2) / 6;
            else h = ((rn - gn) / d + 4) / 6;
        }
        return "#" + hex + " rgb(" + r + "," + g + "," + b + ") hsl(" + Math.round(h*360) + "," + Math.round(s*100) + "%," + Math.round(l*100) + "%)";
    }

    // ---- shell command execution ----
    property string _shellOutput: ""

    function runShellCmd(cmd) {
        _shellOutput = "";
        shellExec.command = ["sh", "-c", cmd];
        shellExec.running = true;
    }

    Process {
        id: shellExec
        stdout: StdioCollector {
            onStreamFinished: {
                root._shellOutput = this.text;
                Notify.announce("SHELL", root._shellOutput.slice(0, 200) || "(no output)", 4);
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.length > 0) {
                    root._shellOutput = this.text;
                    Notify.announce("SHELL ERR", root._shellOutput.slice(0, 200), 4);
                }
            }
        }
    }

    Component {
        id: cardComponent

        Item {
            id: filler
            anchors.fill: parent

            readonly property alias surface: card

            YSurface {
                spawnId: "launcher"
                id: card

                open: root.open
                anchorX: root.anchorMode
                cardW: Math.min(Math.max(520, ShellState.launcherW), Math.round(parent.width * 0.42))
                cardH: Math.min(580, Math.round(parent.height * 0.54))

                function resetForOpen() {
                    searchField.text = "";
                    selIdx = 0;
                    catFilter = "all";
                    searchField.forceFocus();
                }

                // ---- selection ----
                property int selIdx: 0
                readonly property int selCount: specialMode ? (commandMode ? cmdMatches.length : shellMode ? shellResults.length : notifySearchMode ? notifyResults.length : colorMode ? 1 : recentFilesMode ? recentFilesResults.length : 1) : results.length
                onQueryChanged: selIdx = 0

                function clampSel() {
                    selIdx = Math.max(0, Math.min(selIdx, Math.max(0, selCount - 1)));
                }

                function moveSel(d) {
                    const n = selCount;
                    if (n === 0) return;
                    selIdx = ((selIdx + d) % n + n) % n;
                }

                // ---- category filter ----
                property string catFilter: "all"

                readonly property var categories: {
                    const map = {};
                    const apps = allApps;
                    for (let i = 0; i < apps.length; i++) {
                        const cats = apps[i].categories;
                        if (cats && Array.isArray(cats)) {
                            for (let j = 0; j < cats.length; j++) {
                                const c = cats[j];
                                if (c && c.length > 0) {
                                    const key = c.charAt(0).toUpperCase() + c.slice(1).toLowerCase();
                                    map[key] = (map[key] || 0) + 1;
                                }
                            }
                        }
                    }
                    const sorted = Object.keys(map).sort((a, b) => map[b] - map[a]);
                    return { names: sorted.slice(0, 8), counts: map };
                }

                readonly property var categoryLabels: {
                    const out = [{label: "ALL", count: allApps.length}];
                    for (let i = 0; i < categories.names.length; i++) {
                        out.push({label: categories.names[i].toUpperCase(), count: categories.counts[categories.names[i]] || 0});
                    }
                    return out;
                }

                // ---- pins / recents ----
                function parseIds(s) {
                    try {
                        const v = JSON.parse(s);
                        return Array.isArray(v) ? v.filter(x => typeof x === "string") : [];
                    } catch (err) { return []; }
                }

                function pushRecent(id) {
                    const r = parseIds(ShellState.launcherRecents).filter(x => x !== id);
                    r.unshift(id);
                    ShellState.set("launcherRecents", JSON.stringify(r.slice(0, 10)));
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
                readonly property string queryLs: query.replace(/^\s+/, "")
                readonly property bool commandMode: queryLs.startsWith(":")
                readonly property bool shellMode: queryLs.startsWith(">")
                readonly property bool notifySearchMode: queryLs.startsWith("@")
                readonly property bool colorMode: queryLs.startsWith("#")
                readonly property bool recentFilesMode: queryLs.startsWith("~")
                readonly property bool calcMode: queryLs.startsWith("=")
                readonly property bool specialMode: commandMode || shellMode || notifySearchMode || colorMode || recentFilesMode || calcMode
                readonly property int mode: ShellState.launcherMode === "grid" ? 0 : ShellState.launcherMode === "detail" ? 2 : 1

                function byName(a, b) { return a.name.localeCompare(b.name); }

                function wrapApp(e) {
                    return {kind: "app", entry: e, action: null};
                }

                function appMatchesCat(e) {
                    if (catFilter === "all") return true;
                    const cats = e.categories;
                    if (!cats || !Array.isArray(cats)) return false;
                    for (let i = 0; i < cats.length; i++) {
                        if (cats[i] && cats[i].toLowerCase() === catFilter.toLowerCase()) return true;
                    }
                    return false;
                }

                readonly property var results: {
                    const q = query.trim();
                    if (specialMode && !calcMode) return [];
                    const apps = allApps;
                    let pool = catFilter === "all" ? apps : apps.filter(e => appMatchesCat(e));
                    let out = [];

                    // frecency stats
                    let stats = {};
                    try { stats = JSON.parse(ShellState.launcherStats); } catch (e) {}
                    const now = Date.now();
                    const DAY_MS = 86400000;

                    function frecencyScore(entry) {
                        const s = stats[entry.id];
                        if (!s) return 0;
                        const daysSince = Math.max(1, (now - s.lastLaunch) / DAY_MS);
                        // decay: score drops if not used recently
                        return s.count * (1 / (1 + daysSince * 0.1));
                    }

                    if (q.length === 0) {
                        const pinList = parseIds(ShellState.launcherPins).map(id => pool.find(e => e.id === id)).filter(Boolean);
                        const recs = parseIds(ShellState.launcherRecents).map(id => pool.find(e => e.id === id)).filter(e => e && !pinList.includes(e));
                        const rest = pool.filter(e => !pinList.includes(e) && !recs.includes(e)).sort((a, b) => frecencyScore(b) - frecencyScore(a) || byName(a, b));
                        out = pinList.concat(recs, rest).map(wrapApp);
                    } else if (calcMode) {
                        // calc mode: no app results, show result in calc strip
                        out = [];
                    } else if (recentFilesMode) {
                        const rq = q.substring(1).trim().toLowerCase();
                        const rFiles = (RecentFiles.files ?? []).filter(f => {
                            if (rq.length === 0) return true;
                            return f.name.toLowerCase().indexOf(rq) >= 0 || f.uri.toLowerCase().indexOf(rq) >= 0;
                        });
                        out = rFiles.map(f => ({kind: "recentfile", entry: null, recentFile: f}));
                    } else {
                        const scored = [];
                        for (let i = 0; i < apps.length; i++) {
                            if (catFilter !== "all" && !appMatchesCat(apps[i])) continue;
                            let s = Fuzzy.entryScore(q, apps[i]);
                            if (s >= 0) {
                                // frecency boost: up to +30% for frequently-used apps
                                const fScore = frecencyScore(apps[i]);
                                s += s * Math.min(0.3, fScore * 0.03);
                                scored.push({s: s, item: wrapApp(apps[i]), name: apps[i].name});
                            }
                            if (q.length >= 2) {
                                const acts = apps[i].actions ?? [];
                                for (let j = 0; j < acts.length; j++) {
                                    const as = Fuzzy.score(q, acts[j].name) * 0.85;
                                    if (as > 0) scored.push({s: as, item: {kind: "action", entry: apps[i], action: acts[j]}, name: acts[j].name});
                                }
                            }
                        }
                        scored.sort((a, b) => b.s - a.s || a.name.localeCompare(b.name));
                        out = scored.slice(0, 64).map(x => x.item);
                    }
                    return out;
                }

                // ---- > shell mode ----
                readonly property var shellResults: {
                    if (!shellMode) return [];
                    const cmd = queryLs.substring(1).trim();
                    if (cmd.length === 0) return [];
                    return [{kind: "shellcmd", cmd: cmd}];
                }

                // ---- @ notification search ----
                readonly property var notifyResults: {
                    if (!notifySearchMode) return [];
                    const nq = queryLs.substring(1).trim().toLowerCase();
                    if (nq.length === 0) return [];
                    let hist = [];
                    try { hist = JSON.parse(ShellState.notifyHistory); } catch (e) {}
                    if (!Array.isArray(hist)) return [];
                    return hist.filter(n => {
                        const hay = ((n.app ?? "") + " " + (n.summary ?? "") + " " + (n.body ?? "")).toLowerCase();
                        return hay.indexOf(nq) >= 0;
                    }).slice(0, 32).map(n => ({kind: "notifyitem", notifyItem: n}));
                }

                // ---- ~ recent files ----
                // (uses results property above with recentFilesMode check)

                // ---- # color converter ----
                readonly property string colorText: {
                    if (!colorMode) return "";
                    const cq = queryLs.substring(1).trim();
                    if (cq.length === 0) return "";
                    return root.parseColor(cq);
                }

                onResultsChanged: clampSel()
                onCmdMatchesChanged: if (commandMode) clampSel()
                onShellResultsChanged: if (shellMode) clampSel()
                onNotifyResultsChanged: if (notifySearchMode) clampSel()

                // ---- :command mode ----
                readonly property var commands: [{
                    cmd: ":scheme", argHint: "<preset>", desc: "apply scheme preset",
                    fn: a => Theme.applyPreset(String(a))
                }, {
                    cmd: ":wall", argHint: "<next|random>", desc: "cycle wallpaper",
                    fn: a => a === "random" ? Wallpaper.applyRandom() : Wallpaper.applyNext()
                }, {
                    cmd: ":dark", argHint: "", desc: "toggle light / dark",
                    fn: () => Theme.setDark(!Theme.dark)
                }, {
                    cmd: ":accent", argHint: "<#hex|none>", desc: "accent override",
                    fn: a => Theme.setAccent(String(a))
                }, {
                    cmd: ":panel", argHint: "", desc: "toggle control core",
                    fn: () => ShellState.togglePanel()
                }, {
                    cmd: ":picker", argHint: "", desc: "toggle wallpaper picker",
                    fn: () => ShellState.togglePicker()
                }]

                readonly property var cmdMatches: {
                    if (!commandMode) return [];
                    const body = queryLs.slice(1);
                    const sp = body.indexOf(" ");
                    const head = (sp === -1 ? body : body.slice(0, sp)).toLowerCase();
                    const args = sp === -1 ? "" : body.slice(sp + 1).trim();
                    return commands.filter(c => head === "" || c.cmd.slice(1).startsWith(head)).map(c => ({kind: "cmd", c: c, args: args}));
                }

                function runCommand(m) {
                    try { m.c.fn(m.args); } catch (err) { console.warn("[launcher] command failed:", m.c.cmd, err); }
                    ShellState.closeLauncher();
                }

                // ---- calculator (safe parser, no eval) ----
                readonly property string calcText: {
                    const q = query.trim();
                    if (q.length === 0 || q.startsWith(":") || q.startsWith(">") || q.startsWith("@") || q.startsWith("#") || q.startsWith("~")) return "";
                    if (!q.startsWith("=")) return "";
                    const expr = q.substring(1).trim();
                    if (expr.length === 0) return "";
                    const v = root.safeCalc(expr);
                    if (v === null) return "ERR";
                    return String(Math.round(v * 1e10) / 1e10);
                }

                Process {
                    id: copyProc
                    stdout: StdioCollector {}
                    stderr: StdioCollector {}
                }

                property bool wlCopyOk: false

                Process {
                    id: wlProbe
                    command: ["sh", "-c", "command -v wl-copy >/dev/null 2>&1 && echo yes || echo no"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            card.wlCopyOk = text.trim() === "yes";
                            if (!card.wlCopyOk)
                                Health.report("wl-clipboard", "launcher calculator copy unavailable (install wl-clipboard)");
                        }
                    }
                }

                Component.onCompleted: {
                    wlProbe.running = true;
                    if (root.open) resetForOpen();
                }

                function acceptCurrent() {
                    if (commandMode) {
                        if (selCount > 0) runCommand(cmdMatches[Math.min(selIdx, selCount - 1)]);
                        return;
                    }
                    if (shellMode) {
                        const cmd = queryLs.substring(1).trim();
                        if (cmd.length > 0) root.runShellCmd(cmd);
                        return;
                    }
                    if (colorMode && card.colorText.length > 0) {
                        copyProc.command = ["wl-copy", card.colorText];
                        copyProc.running = true;
                        ShellState.closeLauncher();
                        return;
                    }
                    if (calcText !== "") {
                        if (card.wlCopyOk) {
                            copyProc.command = ["wl-copy", calcText];
                            copyProc.running = true;
                            ShellState.closeLauncher();
                        } else {
                            Notify.announce("LAUNCHER", "copy unavailable (install wl-clipboard)", 2);
                        }
                        return;
                    }
                    activate(results[selIdx]);
                }

                function activate(r) {
                    if (!r) return;
                    if (r.kind === "recentfile") {
                        RecentFiles.openFile(r.recentFile.uri);
                        ShellState.closeLauncher();
                        return;
                    }
                    try {
                        if (r.kind === "action") r.action.execute(); else r.entry.execute();
                    } catch (err) { console.warn("[launcher] execute failed:", err); return; }
                    pushRecent(r.entry.id);
                    // track frecency
                    root.trackLaunch(r.entry.id);
                    ShellState.closeLauncher();
                }

                // ---- selected app detail ----
                readonly property var selectedEntry: {
                    if (commandMode || results.length === 0 || selIdx >= results.length) return null;
                    const r = results[selIdx];
                    return r ? r.entry : null;
                }

                readonly property var selectedActions: {
                    if (!selectedEntry || !selectedEntry.actions) return [];
                    return selectedEntry.actions;
                }

                readonly property bool selectedPinned: selectedEntry ? pinIds.includes(selectedEntry.id) : false

                readonly property string selectedCategories: {
                    if (!selectedEntry || !selectedEntry.categories) return "";
                    return selectedEntry.categories.join(" · ");
                }

                // ===== HEADER =====
                Item {
                    id: header
                    y: 0
                    width: parent.width
                    height: Theme.headH

                    Rectangle {
                        x: Theme.sp4
                        anchors.verticalCenter: parent.verticalCenter
                        width: 24
                        height: 24
                        color: Theme.acid

                        Text {
                            anchors.centerIn: parent
                            text: ">"
                            color: Theme.bg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsTitle
                            font.weight: Font.ExtraBold
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.right
                        anchors.leftMargin: Theme.sp2
                        text: Theme.jpEnabled ? "アプリ // LAUNCHER" : "APP.LAUNCHER"
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
                            label: "LIST"
                            tone: card.mode === 1 ? "acid" : "default"
                            onClicked: ShellState.set("launcherMode", "list")
                        }

                        YButton {
                            label: "GRID"
                            tone: card.mode === 0 ? "acid" : "default"
                            onClicked: ShellState.set("launcherMode", "grid")
                        }

                        YButton {
                            label: "DETAIL"
                            tone: card.mode === 2 ? "acid" : "default"
                            onClicked: ShellState.set("launcherMode", "detail")
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: header.height
                    height: 1
                    color: Theme.hairline
                }

                // ===== SEARCH BAR =====
                Item {
                    id: searchBand
                    anchors.top: header.bottom
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
                        placeholder: Theme.jpEnabled ? "検索 // SEARCH" : "SEARCH  :cmd  >run  @notify  #color  ~files  =math"
                        navKeys: true

                        onAccepted: card.acceptCurrent()
                        onNavUp: card.mode === 0 && !card.commandMode ? card.moveSel(-gridView.cols) : card.moveSel(-1)
                        onNavDown: card.mode === 0 && !card.commandMode ? card.moveSel(gridView.cols) : card.moveSel(1)
                        onNavLeft: if (!card.commandMode && card.mode === 0) card.moveSel(-1)
                        onNavRight: if (!card.commandMode && card.mode === 0) card.moveSel(1)
                        onNavTab: {
                            const modes = ["list", "grid", "detail"];
                            const cur = modes.indexOf(ShellState.launcherMode);
                            ShellState.set("launcherMode", modes[(cur + 1) % modes.length]);
                            card.clampSel();
                        }
                        onNavEscape: ShellState.closeLauncher()
                        onNavShiftDel: {
                            const r = card.results[card.selIdx];
                            if (r && r.kind === "app") card.removeRecent(r.entry.id);
                        }
                    }
                }

                // ===== CATEGORY FILTER BAR =====
                Item {
                    id: catBar
                    anchors.top: searchBand.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 26
                    visible: !card.commandMode

                    Flickable {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.sp4
                        anchors.rightMargin: Theme.sp4
                        contentWidth: catRow.width
                        clip: true
                        interactive: contentWidth > width
                        boundsBehavior: Flickable.StopAtBounds
                        FastWheel {}

                        Row {
                            id: catRow
                            spacing: Theme.sp1
                            anchors.verticalCenter: parent.verticalCenter

                            Repeater {
                                model: card.categoryLabels

                                delegate: Rectangle {
                                    id: catChip
                                    required property var modelData
                                    required property int index
                                    readonly property bool active: card.catFilter === modelData.label.toLowerCase()

                                    width: catLabel.implicitWidth + Theme.sp2 * 2
                                    height: 20
                                    radius: 2
                                    color: active ? Theme.acid : "transparent"
                                    border.width: 1
                                    border.color: active ? Theme.acid : Theme.lineStrong

                                    Text {
                                        id: catLabel
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: active ? Theme.bg : Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        font.weight: Font.Bold
                                        font.letterSpacing: 1
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.sp1
                                        anchors.verticalCenter: parent.verticalCenter
                                        visible: !active
                                        text: modelData.count
                                        color: Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 7
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: card.catFilter = catChip.modelData.label.toLowerCase()
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    y: catBar.y + catBar.height
                    height: catBar.visible ? 1 : 0
                    color: Theme.hairline
                }

                // ===== CALC STRIP =====
                Rectangle {
                    id: calcStrip
                    anchors.top: catBar.visible ? catBar.bottom : searchBand.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: card.calcText !== "" || card.colorText !== "" ? 34 : 0
                    visible: height > 0
                    color: Theme.surface

                    MouseArea {
                        anchors.fill: parent
                        enabled: card.wlCopyOk && card.calcText !== ""
                        onClicked: {
                            copyProc.command = ["wl-copy", card.calcText];
                            copyProc.running = true;
                            ShellState.closeLauncher();
                        }
                    }

                    Text {
                        x: Theme.sp4
                        anchors.verticalCenter: parent.verticalCenter
                        text: card.colorText !== "" ? card.colorText : "= " + card.calcText
                        color: Theme.acid
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBody
                        font.weight: Font.Bold
                        opacity: (card.calcText !== "" || card.colorText !== "") ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.movFast } }
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.sp4
                        anchors.verticalCenter: parent.verticalCenter
                        text: !card.wlCopyOk ? "wl-copy missing" : Theme.jpEnabled ? "クリックでコピー" : "CLICK TO COPY"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        font.letterSpacing: 0.8
                        opacity: (card.calcText !== "" || card.colorText !== "") ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.movFast } }
                    }
                }

                // ===== RESULTS =====
                Item {
                    id: resultsArea
                    anchors.top: calcStrip.bottom
                    anchors.bottom: footer.top
                    anchors.bottomMargin: detailPanel.height
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

                    // ---- command list ----
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
                        FastWheel {}

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

                    // ---- shell mode: run command card ----
                    Item {
                        anchors.fill: parent
                        anchors.margins: Theme.sp2
                        visible: card.shellMode

                        Rectangle {
                            anchors.fill: parent
                            color: Theme.surface
                            radius: Theme.sp1
                            border.width: 1
                            border.color: Theme.hairline

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.sp3
                                spacing: Theme.sp2

                                Row {
                                    spacing: Theme.sp1

                                    Rectangle {
                                        width: 20; height: 20
                                        radius: 3
                                        color: Theme.acid

                                        Text {
                                            anchors.centerIn: parent
                                            text: ">"
                                            color: Theme.bg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsLabel
                                            font.weight: Font.Bold
                                        }
                                    }

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "RUN COMMAND"
                                        color: Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsLabel
                                        font.weight: Font.Bold
                                    }
                                }

                                Rectangle {
                                    width: parent.width
                                    height: 1
                                    color: Theme.hairline
                                }

                                Text {
                                    width: parent.width
                                    text: card.queryLs.substring(1).trim()
                                    color: Theme.acid
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 3
                                    elide: Text.ElideRight
                                }

                                Text {
                                    width: parent.width
                                    text: "ENTER to execute · output via notification"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                }
                            }
                        }
                    }

                    // ---- @ notification search list ----
                    ListView {
                        anchors.fill: parent
                        anchors.margins: Theme.sp2
                        visible: card.notifySearchMode
                        clip: true
                        model: card.notifyResults
                        currentIndex: card.selIdx
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        spacing: 1
                        boundsBehavior: Flickable.StopAtBounds
                        FastWheel {}

                        delegate: Item {
                            id: nRoot
                            required property var modelData
                            required property int index
                            readonly property bool sel: index === card.selIdx

                            width: parent.width
                            height: 36

                            Rectangle {
                                anchors.fill: parent
                                color: nRoot.sel ? Theme.surface : "transparent"

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top; anchors.bottom: parent.bottom
                                    width: 2
                                    color: nRoot.sel ? Theme.acid : "transparent"
                                }
                            }

                            Text {
                                x: Theme.sp3
                                width: parent.width * 0.3
                                anchors.verticalCenter: parent.verticalCenter
                                text: nRoot.modelData.notifyItem.app ?? ""
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                                elide: Text.ElideRight
                            }

                            Text {
                                x: parent.width * 0.3 + Theme.sp3
                                width: parent.width * 0.7 - Theme.sp3 * 2
                                anchors.verticalCenter: parent.verticalCenter
                                text: nRoot.modelData.notifyItem.summary ?? nRoot.modelData.notifyItem.body ?? ""
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                                elide: Text.ElideRight
                            }
                        }
                    }

                    // ---- ~ recent files: shown via standard list view with updated delegate ----

                    // ---- grid view ----
                    GridView {
                        id: gridView
                        readonly property int gridW: width - Theme.sp2 * 2
                        readonly property int cols: Math.max(4, Math.floor(gridW / 104))

                        anchors.fill: parent
                        anchors.margins: Theme.sp2
                        visible: !card.specialMode && card.mode === 0
                        clip: true
                        model: card.results
                        currentIndex: card.selIdx
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)
                        cellWidth: Math.floor(gridW / cols)
                        cellHeight: 92
                        boundsBehavior: Flickable.StopAtBounds
                        FastWheel {}

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

                            opacity: 1
                            scale: tileRoot.sel ? 1.04 : (area.containsMouse ? 1.02 : 1)

                            Behavior on scale {
                                NumberAnimation {
                                    duration: Theme.movSnap
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 0.2
                                }
                            }

                            // selection glow — acid aura behind selected tile
                            Rectangle {
                                anchors.centerIn: tileBox
                                width: tileBox.width + 8
                                height: tileBox.height + 8
                                radius: 3
                                color: Theme.acid
                                opacity: tileRoot.sel ? 0.1 : 0
                                visible: tileRoot.sel

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Theme.movMed
                                    }
                                }
                            }

                            Rectangle {
                                id: tileBox
                                x: 4; y: 4
                                width: parent.width - 8; height: parent.height - 8
                                color: tileRoot.sel || area.containsMouse ? Theme.surface : "transparent"
                                border.width: 1
                                border.color: tileRoot.sel ? Theme.acid : "transparent"

                                Rectangle {
                                    anchors.right: parent.right; anchors.top: parent.top
                                    width: 5; height: 5
                                    color: Theme.acid
                                    visible: !tileRoot.isAction && card.pinIds.includes(tileRoot.modelData.entry.id)
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top; anchors.topMargin: 10
                                    width: 34; height: 34
                                    color: Theme.acid
                                    visible: tileRoot.iconSrc === "" || gTileIcon.status === Image.Error || gTileIcon.status === Image.Null || gTileIcon.status === Image.Loading

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
                                    anchors.top: parent.top; anchors.topMargin: 10
                                    implicitSize: 36
                                    visible: tileRoot.iconUrl !== "" && gTileIcon.status !== Image.Error && gTileIcon.status !== Image.Null
                                    source: tileRoot.iconUrl
                                    asynchronous: true
                                }

                                Text {
                                    anchors.left: parent.left; anchors.right: parent.right
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 8
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
                                        if (!tileRoot.isAction) card.togglePin(tileRoot.modelData.entry.id);
                                        return;
                                    }
                                    if (mouse.button === Qt.LeftButton) card.activate(tileRoot.modelData);
                                }
                            }
                        }
                    }

                    // ---- list view ----
                    ListView {
                        id: listView
                        anchors.fill: parent
                        anchors.margins: Theme.sp2
                        visible: !card.specialMode && card.mode === 1
                        clip: true
                        model: card.results
                        currentIndex: card.selIdx
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        spacing: 1
                        boundsBehavior: Flickable.StopAtBounds
                        FastWheel {}

                        delegate: Item {
                            id: rowRoot
                            required property var modelData
                            required property int index

                            width: listView.width
                            height: 36

                            readonly property bool sel: index === card.selIdx
                            readonly property bool isAction: modelData.kind === "action"
                            readonly property bool isRecentFile: modelData.kind === "recentfile"
                            readonly property bool isNotify: modelData.kind === "notifyitem"
                            readonly property string iconSrc: isAction ? (modelData.action.icon ?? "") : isRecentFile ? "" : isNotify ? "" : (modelData.entry.icon ?? "")
                            readonly property string iconUrl: iconSrc === "" ? "" : Quickshell.iconPath(iconSrc)
                            readonly property string label: isAction ? modelData.action.name : isRecentFile ? (modelData.recentFile.name ?? modelData.recentFile.uri ?? "") : isNotify ? (modelData.notifyItem.summary ?? modelData.notifyItem.body ?? "") : modelData.entry.name
                            readonly property string sub: isAction ? modelData.entry.name : isRecentFile ? (modelData.recentFile.mimeType ?? "") : isNotify ? (modelData.notifyItem.app ?? "") : (modelData.entry.genericName ?? "")

                            Rectangle {
                                anchors.fill: parent
                                color: rowRoot.sel ? Theme.surface : areaR.containsMouse ? Theme.bg : "transparent"

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top; anchors.bottom: parent.bottom
                                    width: 2
                                    color: rowRoot.sel ? Theme.acid : "transparent"
                                }

                                Rectangle {
                                    anchors.left: parent.left; anchors.leftMargin: 10
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 5; height: 5
                                    color: Theme.acid
                                    visible: rowRoot.modelData.kind === "app" && card.pinIds.includes(rowRoot.modelData.entry.id)
                                }

                                Item {
                                    x: 26
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22; height: 22

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Theme.acid
                                        visible: rowRoot.iconSrc === "" || rRowIcon.status === Image.Error || rRowIcon.status === Image.Null || rRowIcon.status === Image.Loading

                                        Text {
                                            anchors.centerIn: parent
                                            text: rowRoot.isRecentFile ? "~" : rowRoot.isNotify ? "@" : rowRoot.label.charAt(0).toUpperCase()
                                            color: Theme.bg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: rowRoot.isRecentFile || rowRoot.isNotify ? 12 : Theme.fsLabel
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
                                    anchors.right: parent.right; anchors.rightMargin: Theme.sp3
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
                                        if (!rowRoot.isAction) card.togglePin(rowRoot.modelData.entry.id);
                                        return;
                                    }
                                    card.activate(rowRoot.modelData);
                                }
                            }
                        }
                    }

                    // ---- detail view: single-column rich list ----
                    ListView {
                        id: detailList
                        anchors.fill: parent
                        anchors.margins: Theme.sp2
                        visible: !card.specialMode && card.mode === 2
                        clip: true
                        model: card.results
                        currentIndex: card.selIdx
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
                        spacing: 2
                        boundsBehavior: Flickable.StopAtBounds
                        FastWheel {}

                        delegate: Item {
                            id: detRoot
                            required property var modelData
                            required property int index

                            width: detailList.width
                            height: 58

                            readonly property bool sel: index === card.selIdx
                            readonly property bool isAction: modelData.kind === "action"
                            readonly property string iconSrc: isAction ? (modelData.action.icon ?? "") : (modelData.entry.icon ?? "")
                            readonly property string iconUrl: iconSrc === "" ? "" : Quickshell.iconPath(iconSrc)
                            readonly property string label: isAction ? modelData.action.name : modelData.entry.name
                            readonly property string sub: isAction ? modelData.entry.name : (modelData.entry.genericName ?? "")
                            readonly property string catStr: {
                                if (isAction || !modelData.entry.categories) return "";
                                return modelData.entry.categories.slice(0, 3).join(" · ");
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: detRoot.sel ? Theme.surface : areaD.containsMouse ? Theme.bg : "transparent"
                                border.width: 1
                                border.color: detRoot.sel ? Theme.acid : "transparent"

                                Behavior on border.color { ColorAnimation { duration: Theme.movFast } }

                                // left accent bar
                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top; anchors.bottom: parent.bottom
                                    width: detRoot.sel ? 3 : 0
                                    color: Theme.acid

                                    Behavior on width { NumberAnimation { duration: Theme.movSnap; easing.type: Easing.OutCubic } }
                                }

                                // pin indicator
                                Rectangle {
                                    anchors.left: parent.left; anchors.leftMargin: 10
                                    anchors.top: parent.top; anchors.topMargin: 8
                                    width: 5; height: 5
                                    color: Theme.acid
                                    visible: !detRoot.isAction && card.pinIds.includes(detRoot.modelData.entry.id)
                                }

                                // icon
                                Item {
                                    anchors.left: parent.left; anchors.leftMargin: 18
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 32; height: 32

                                    Rectangle {
                                        anchors.fill: parent
                                        color: Theme.acid
                                        visible: detRoot.iconSrc === "" || detIcon.status === Image.Error || detIcon.status === Image.Null || detIcon.status === Image.Loading

                                        Text {
                                            anchors.centerIn: parent
                                            text: detRoot.label.charAt(0).toUpperCase()
                                            color: Theme.bg
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsBody
                                            font.weight: Font.ExtraBold
                                        }
                                    }

                                    IconImage {
                                        id: detIcon
                                        anchors.fill: parent
                                        implicitSize: 32
                                        visible: detRoot.iconUrl !== "" && detIcon.status !== Image.Error && detIcon.status !== Image.Null
                                        source: detRoot.iconUrl
                                        asynchronous: true
                                    }
                                }

                                // name
                                Text {
                                    anchors.left: parent.left; anchors.leftMargin: 58
                                    anchors.top: parent.top; anchors.topMargin: 8
                                    anchors.right: parent.right; anchors.rightMargin: Theme.sp3
                                    text: detRoot.label + (detRoot.isAction ? " ↩" : "")
                                    color: detRoot.sel ? Theme.acid : Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }

                                // subtitle
                                Text {
                                    anchors.left: parent.left; anchors.leftMargin: 58
                                    anchors.top: parent.top; anchors.topMargin: 26
                                    anchors.right: parent.right; anchors.rightMargin: Theme.sp3
                                    text: detRoot.sub
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                    elide: Text.ElideRight
                                }

                                // category tag
                                Text {
                                    anchors.left: parent.left; anchors.leftMargin: 58
                                    anchors.bottom: parent.bottom; anchors.bottomMargin: 6
                                    visible: detRoot.catStr.length > 0
                                    text: detRoot.catStr.toUpperCase()
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 7
                                    font.letterSpacing: 1
                                }
                            }

                            MouseArea {
                                id: areaD
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: mouse => {
                                    if (mouse.button === Qt.RightButton) {
                                        if (!detRoot.isAction) card.togglePin(detRoot.modelData.entry.id);
                                        return;
                                    }
                                    card.activate(detRoot.modelData);
                                }
                            }
                        }
                    }

                    YScroll {
                        target: card.commandMode ? commandList : card.mode === 0 ? gridView : card.mode === 2 ? detailList : listView
                        x: parent.width - 7
                        y: Theme.sp2
                        width: 3
                        height: parent.height - Theme.sp2 * 2
                    }
                }

                // ===== DETAIL PANEL =====
                Rectangle {
                    id: detailPanel
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: footer.top
                    height: card.selectedEntry && ShellState.launcherDetail && !card.commandMode ? 64 : 0
                    visible: height > 0
                    color: Theme.bgAlt
                    clip: true

                    Behavior on height {
                        NumberAnimation { duration: Theme.movMed; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top
                        height: 1
                        color: Theme.hairline
                    }

                    // pin dot
                    Rectangle {
                        x: Theme.sp4; y: Theme.sp3
                        width: 8; height: 8
                        color: card.selectedPinned ? Theme.acid : "transparent"
                        border.width: 1
                        border.color: card.selectedPinned ? Theme.acid : Theme.faint
                    }

                    // name
                    Text {
                        x: Theme.sp4 + (card.selectedPinned ? 14 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: -12
                        text: card.selectedEntry ? card.selectedEntry.name : ""
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBody
                        font.weight: Font.Bold
                        font.letterSpacing: 0.5
                    }

                    // id
                    Text {
                        x: Theme.sp4 + (card.selectedPinned ? 14 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 4
                        text: card.selectedEntry ? card.selectedEntry.id : ""
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        font.letterSpacing: 1
                    }

                    // category
                    Text {
                        x: Theme.sp4 + (card.selectedPinned ? 14 : 0)
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 16
                        visible: card.selectedCategories.length > 0
                        text: card.selectedCategories.toUpperCase()
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: 7
                        font.letterSpacing: 1.5
                    }

                    // action chips
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: Theme.sp4
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Theme.sp1
                        visible: card.selectedActions.length > 0

                        Repeater {
                            model: card.selectedActions.slice(0, 4)

                            delegate: YButton {
                                required property var modelData
                                label: modelData.name.toUpperCase()
                                onClicked: {
                                    modelData.execute();
                                    card.pushRecent(card.selectedEntry.id);
                                    ShellState.closeLauncher();
                                }
                            }
                        }
                    }

                    // pin/unpin button
                    YButton {
                        anchors.right: parent.right; anchors.rightMargin: Theme.sp4
                        anchors.bottom: parent.bottom; anchors.bottomMargin: Theme.sp2
                        visible: card.selectedEntry && !card.selectedActions.length
                        label: card.selectedPinned ? "UNPIN" : "PIN"
                        tone: card.selectedPinned ? "default" : "acid"
                        onClicked: {
                            if (card.selectedEntry) card.togglePin(card.selectedEntry.id);
                        }
                    }
                }

                // ===== FOOTER =====
                Rectangle {
                    id: footer
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Theme.footH
                    color: Theme.bgAlt

                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right
                        anchors.top: parent.top
                        height: 1
                        color: Theme.hairline
                    }

                    YChip {
                        id: countChip
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.sp4
                        anchors.verticalCenter: parent.verticalCenter
                        label: String(card.selCount) + (card.commandMode ? " CMD" : " APPS")
                    }

                    Text {
                        anchors.left: countChip.right
                        anchors.leftMargin: Theme.sp2
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.sp4
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight
                        text: "↵ RUN · ↑↓ NAV · TAB MODE · RCLICK PIN · ⇧DEL FORGET · ESC CLOSE"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        font.letterSpacing: 0.8
                    }
                }
            }
        }
    }
}
