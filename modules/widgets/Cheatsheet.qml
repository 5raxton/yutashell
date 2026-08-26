import Quickshell
import Quickshell.Io
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui

// Cheatsheet — YSurface panel displaying Hyprland keybinds parsed from
// `hyprctl -j binds`. Searchable by key combo or description. Falls back
// to a static list if parsing fails.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    readonly property bool open: ShellState.cheatsheetOpen

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.open || hideDelay.running
    mask: Region { item: root.open ? clickAway : null }

    WlrLayershell.layer: WlrLayer.Top

    Timer { id: hideDelay; interval: Theme.lingerMs }
    onOpenChanged: if (!root.open) hideDelay.restart()

    YClickAway { id: clickAway; onOutsideClicked: ShellState.closeCheatsheet() }

    property string searchQuery: ""
    property var binds: []
    property bool loaded: false

    Component.onCompleted: {
        if (root.open) fetchBinds();
    }
    onOpenChanged: {
        if (root.open && !root.loaded) fetchBinds();
    }

    function fetchBinds() {
        bindProc.running = true;
    }

    Process {
        id: bindProc
        command: ["hyprctl", "-j", "binds"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(this.text);
                    if (Array.isArray(arr)) {
                        root.binds = arr.map(b => ({
                            mod: (b.modifiers ?? []).join("+"),
                            key: b.key ?? "",
                            desc: b.desc ?? "",
                            dispatcher: b.dispatcher ?? "",
                            arg: b.arg ?? "",
                            cat: root._categorize(b.dispatcher ?? "", b.desc ?? "")
                        }));
                        root.loaded = true;
                        return;
                    }
                } catch (e) {}
                root.binds = root._fallbackBinds();
                root.loaded = true;
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (root.binds.length === 0) {
                    root.binds = root._fallbackBinds();
                    root.loaded = true;
                }
            }
        }
    }

    function _categorize(dispatcher, desc) {
        const d = dispatcher.toLowerCase();
        const ds = desc.toLowerCase();
        if (d.indexOf("workspace") >= 0) return "WORKSPACES";
        if (d.indexOf("window") >= 0 || d.indexOf("focus") >= 0 || d.indexOf("move") >= 0 || d.indexOf("resize") >= 0) return "WINDOWS";
        if (d.indexOf("exec") >= 0 || d.indexOf("spawn") >= 0) return "APPS";
        if (ds.indexOf("media") >= 0 || ds.indexOf("volume") >= 0 || ds.indexOf("brightness") >= 0) return "MEDIA";
        if (ds.indexOf("session") >= 0 || ds.indexOf("lock") >= 0 || ds.indexOf("logout") >= 0 || ds.indexOf("suspend") >= 0) return "SESSION";
        return "GENERAL";
    }

    function _fallbackBinds() {
        return [
            { mod: "SUPER", key: "Return", desc: "Terminal", dispatcher: "exec", arg: "", cat: "APPS" },
            { mod: "SUPER", key: "Q", desc: "Kill window", dispatcher: "killactive", arg: "", cat: "WINDOWS" },
            { mod: "SUPER", key: "M", desc: "Exit Hyprland", dispatcher: "exit", arg: "", cat: "SESSION" },
            { mod: "SUPER", key: "V", desc: "Toggle floating", dispatcher: "togglefloating", arg: "", cat: "WINDOWS" },
            { mod: "SUPER", key: "P", desc: "Pseudo", dispatcher: "pseudo", arg: "", cat: "WINDOWS" },
            { mod: "SUPER", key: "J", desc: "Toggle split", dispatcher: "togglesplit", arg: "", cat: "WINDOWS" },
            { mod: "SUPER", key: "F", desc: "Fullscreen", dispatcher: "fullscreen", arg: "0", cat: "WINDOWS" },
            { mod: "SUPER", key: "1-9", desc: "Switch workspace 1-9", dispatcher: "workspace", arg: "1-9", cat: "WORKSPACES" },
            { mod: "SUPER SHIFT", key: "1-9", desc: "Move to workspace 1-9", dispatcher: "movetoworkspace", arg: "1-9", cat: "WORKSPACES" },
            { mod: "SUPER", key: "S", desc: "Scratchpad", dispatcher: "togglespecialworkspace", arg: "magic", cat: "WINDOWS" }
        ];
    }

    readonly property var categories: {
        const map = {};
        const list = root.binds;
        for (let i = 0; i < list.length; i++) {
            const c = list[i].cat;
            if (!map[c]) map[c] = [];
            map[c].push(list[i]);
        }
        // sort categories: GENERAL, WINDOWS, WORKSPACES, APPS, MEDIA, SESSION
        const order = ["GENERAL", "WINDOWS", "WORKSPACES", "APPS", "MEDIA", "SESSION"];
        const out = [];
        for (let i = 0; i < order.length; i++) {
            if (map[order[i]]) out.push({ name: order[i], binds: map[order[i]] });
        }
        for (const k in map) {
            if (order.indexOf(k) < 0) out.push({ name: k, binds: map[k] });
        }
        return out;
    }

    readonly property var filteredCategories: {
        const q = root.searchQuery.trim().toLowerCase();
        if (q.length === 0) return root.categories;
        const out = [];
        for (let i = 0; i < root.categories.length; i++) {
            const cat = root.categories[i];
            const matched = [];
            for (let j = 0; j < cat.binds.length; j++) {
                const b = cat.binds[j];
                const hay = (b.mod + " " + b.key + " " + b.desc + " " + b.dispatcher + " " + b.arg).toLowerCase();
                if (hay.indexOf(q) >= 0) matched.push(b);
            }
            if (matched.length > 0) out.push({ name: cat.name, binds: matched });
        }
        return out;
    }

    Item {
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: ShellState.closeCheatsheet()

        YSurface {
            id: card
            open: root.open
            anchorX: "center"
            cardW: Math.min(640, Math.round(parent.width * 0.48))
            cardH: Math.min(600, Math.round(parent.height * 0.6))

            Column {
                anchors.fill: parent
                spacing: 0

                // header
                Rectangle {
                    width: parent.width
                    height: Theme.headH
                    color: "transparent"

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        x: Theme.sp4
                        text: "KEYBINDS"
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsTitle
                        font.weight: Font.Bold
                        font.letterSpacing: 2
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.sp4
                        text: root.binds.length + " BINDS"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.hairline }

                // search
                Item {
                    width: parent.width
                    height: Theme.ctlH + Theme.sp2 * 2

                    YField {
                        anchors.fill: parent
                        anchors.margins: Theme.sp2
                        placeholder: "SEARCH KEYBINDS..."
                        onTextChanged: root.searchQuery = text
                    }
                }

                Rectangle { width: parent.width; height: 1; color: Theme.hairline }

                // bind list
                Flickable {
                    width: parent.width
                    height: parent.height - Theme.headH - Theme.ctlH - Theme.sp2 * 2 - 2
                    clip: true
                    contentHeight: bindCol.height
                    boundsBehavior: Flickable.StopAtBounds
                    FastWheel {}

                    Column {
                        id: bindCol
                        width: parent.width

                        Repeater {
                            model: root.filteredCategories

                            delegate: Column {
                                required property var modelData

                                // category header
                                Rectangle {
                                    width: bindCol.width
                                    height: 24
                                    color: Theme.surface

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: Theme.sp3
                                        text: modelData.name
                                        color: Theme.acid
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        font.weight: Font.Bold
                                        font.letterSpacing: 1.5
                                    }
                                }

                                Repeater {
                                    model: modelData.binds

                                    delegate: Rectangle {
                                        required property var modelData

                                        width: bindCol.width
                                        height: 28
                                        color: "transparent"

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: Theme.sp3
                                            width: keyText.implicitWidth + 12
                                            height: 20
                                            radius: 3
                                            color: Theme.bg

                                            Text {
                                                id: keyText
                                                anchors.centerIn: parent
                                                text: {
                                                    let s = modelData.mod;
                                                    if (s.length > 0 && modelData.key.length > 0) s += " + ";
                                                    s += modelData.key;
                                                    return s;
                                                }
                                                color: Theme.acid
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsLabel
                                                font.weight: Font.Bold
                                            }
                                        }

                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: keyText.parent.right
                                            anchors.leftMargin: Theme.sp3
                                            width: parent.width - keyText.parent.width - Theme.sp4 * 2
                                            text: modelData.desc.length > 0 ? modelData.desc : modelData.dispatcher + " " + modelData.arg
                                            color: Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsLabel
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
