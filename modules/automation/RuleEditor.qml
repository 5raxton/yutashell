import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"

// RuleEditor — YSurface panel for managing automation rules (PH.03).
// Left: scrollable rule list. Right: detail editor with trigger config,
// action builder, enable toggle, test button, and delete.
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
    visible: ShellState.automationOpen || hideDelay.running
    mask: Region {
        item: ShellState.automationOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.automationOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(840, contentRoot.width - Theme.outerPad * 2)
    readonly property int cardH: Math.min(560, contentRoot.height - Theme.outerPad * 2)

    property var _selectedRule: null

    readonly property var _triggerTypes: [
        { id: "time", label: "Time", desc: "Schedule (hour/minute/days)" },
        { id: "battery", label: "Battery", desc: "Charge threshold" },
        { id: "network", label: "Network", desc: "Connected/disconnected" },
        { id: "recording", label: "Recording", desc: "Recording started/stopped" },
        { id: "temperature", label: "Temperature", desc: "CPU/GPU temp threshold" },
        { id: "focusedApp", label: "Focused App", desc: "App gained/lost focus" },
        { id: "mpris", label: "Media", desc: "Playback started/stopped" },
        { id: "idle", label: "Idle", desc: "User idle for N seconds" }
    ]

    readonly property var _actionTypes: [
        { id: "setProfile", label: "Apply Profile", desc: "Switch project profile" },
        { id: "setPowerProfile", label: "Power Profile", desc: "Switch power plan" },
        { id: "toggleDnd", label: "DND", desc: "Do Not Disturb" },
        { id: "runCommand", label: "Run Command", desc: "Execute shell command" },
        { id: "notify", label: "Notification", desc: "Send a notification" },
        { id: "setWallpaper", label: "Wallpaper", desc: "Change wallpaper" },
        { id: "setNightLight", label: "Night Light", desc: "Toggle night light" },
        { id: "setBarPreset", label: "Bar Preset", desc: "Switch bar layout" }
    ]

    function _triggerLabel(trigger) {
        if (!trigger) return "?";
        for (let i = 0; i < _triggerTypes.length; i++)
            if (_triggerTypes[i].id === trigger.type) return _triggerTypes[i].label;
        return trigger.type || "?";
    }

    function _triggerDesc(trigger) {
        if (!trigger) return "";
        const cfg = trigger.config || {};
        switch (trigger.type) {
        case "time": {
            const h = String(cfg.hour ?? 0).padStart(2, "0");
            const m = String(cfg.minute ?? 0).padStart(2, "0");
            const days = cfg.days ?? [];
            const dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
            if (days.length === 0) return h + ":" + m + " daily";
            const labels = days.map(d => dayNames[d] ?? d);
            return h + ":" + m + " " + labels.join(", ");
        }
        case "battery": return (cfg.op ?? "below") + " " + (cfg.threshold ?? 20) + "%";
        case "network": return cfg.event ?? "connected";
        case "recording": return cfg.event ?? "started";
        case "temperature": return (cfg.op ?? "above") + " " + (cfg.threshold ?? 85) + "°C";
        case "focusedApp": return (cfg.appId ?? "?") + " " + (cfg.event ?? "gained");
        case "mpris": return cfg.event ?? "started";
        case "idle": return "after " + (cfg.seconds ?? 300) + "s";
        default: return "";
        }
    }

    function _actionLabel(action) {
        if (!action) return "?";
        for (let i = 0; i < _actionTypes.length; i++)
            if (_actionTypes[i].id === action.type) return _actionTypes[i].label;
        return action.type || "?";
    }

    function _actionDesc(action) {
        if (!action) return "";
        const cfg = action.config || {};
        switch (action.type) {
        case "setProfile": return "profile: " + (cfg.id ?? "?");
        case "setPowerProfile": return cfg.name ?? "balanced";
        case "toggleDnd": return cfg.enabled ? "ON" : "OFF";
        case "runCommand": return cfg.cmd || "";
        case "notify": return (cfg.title ?? "") + " — " + (cfg.body ?? "");
        case "setWallpaper": return cfg.path || "";
        case "setNightLight": return cfg.active ? "ON" : "OFF";
        case "setBarPreset": return cfg.id ?? "?";
        default: return "";
        }
    }

    Timer {
        id: hideDelay
        interval: Theme.lingerMs
    }

    Connections {
        target: ShellState
        function onAutomationOpenChanged() {
            if (ShellState.automationOpen) {
                hideDelay.stop();
                _syncSelected();
            } else {
                hideDelay.restart();
            }
        }
    }

    function _syncSelected() {
        if (_selectedRule) {
            const rules = RuleService.rules;
            const found = rules.find(r => r.id === _selectedRule.id);
            if (found) { _selectedRule = found; return; }
        }
        const rules = RuleService.rules;
        _selectedRule = rules.length > 0 ? rules[0] : null;
    }

    YClickAway {
        id: clickAway
        anchors.fill: parent
        onClicked: ShellState.closeAutomation()
    }

    Item {
        id: contentRoot
        anchors.fill: parent

        YSurface {
            id: surface
            anchors.centerIn: parent
            open: ShellState.automationOpen
            spawnId: "automation"
            cardW: root.cardW
            cardH: root.cardH

            Row {
                id: mainRow
                anchors.fill: parent
                anchors.margins: Theme.sp3
                spacing: Theme.sp3

                // ---- LEFT: rule list ----
                Column {
                    id: listCol
                    width: 260
                    height: parent.height
                    spacing: Theme.sp2

                    // header
                    Row {
                        width: parent.width
                        spacing: Theme.sp2

                        Text {
                            text: "AUTOMATION RULES"
                            font.pixelSize: Theme.fsMicro
                            font.family: Theme.fontFamily
                            color: Theme.ink
                            font.weight: Font.DemiBold
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Item { width: 1; height: 1 }

                        YButton {
                            label: "+"
                            tone: "acid"
                            onClicked: {
                                const r = RuleService.create("New Rule", null, []);
                                _selectedRule = r;
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width; height: 1
                        color: Theme.lineStrong
                    }

                    Flickable {
                        width: parent.width
                        height: parent.height - 40 - Theme.sp2 * 2
                        clip: true
                        contentHeight: ruleList.height
                        flickableDirection: Flickable.VerticalFlick
                        FastWheel {}

                        Column {
                            id: ruleList
                            width: parent.width
                            spacing: 4

                            // empty state
                            Text {
                                visible: RuleService.rules.length === 0
                                width: parent.width
                                text: "No rules yet.\nClick + to create one."
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                                wrapMode: Text.Wrap
                                horizontalAlignment: Text.AlignHCenter
                                topPadding: Theme.sp6
                            }

                            Repeater {
                                model: RuleService.rules

                                Rectangle {
                                    required property var modelData
                                    width: ruleList.width
                                    height: 48
                                    radius: Theme.radius
                                    color: _selectedRule && modelData.id === _selectedRule.id
                                        ? Theme.acid + "18"
                                        : rowArea.containsMouse ? Theme.bg : "transparent"
                                    border.width: 1
                                    border.color: _selectedRule && modelData.id === _selectedRule.id
                                        ? Theme.acid : Theme.hairline

                                    Column {
                                        anchors.fill: parent
                                        anchors.margins: Theme.sp2
                                        spacing: 2

                                        Row {
                                            width: parent.width
                                            spacing: Theme.sp2

                                            // enabled dot
                                            Rectangle {
                                                width: 6; height: 6; radius: 3
                                                anchors.verticalCenter: parent.verticalCenter
                                                color: modelData.enabled ? Theme.acid : Theme.faint
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: modelData.name || "Unnamed"
                                                color: Theme.ink
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsLabel
                                                font.weight: (_selectedRule && modelData.id === _selectedRule.id) ? Font.Bold : Font.Normal
                                                elide: Text.ElideRight
                                                width: parent.width - 6 - Theme.sp2
                                            }
                                        }

                                        Text {
                                            text: _triggerLabel(modelData.trigger) + " · " + _triggerDesc(modelData.trigger)
                                            color: Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsMicro
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }
                                    }

                                    MouseArea {
                                        id: rowArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: _selectedRule = modelData
                                    }
                                }
                            }
                        }
                    }
                }

                // divider
                Rectangle {
                    width: 1; height: parent.height
                    color: Theme.lineStrong
                }

                // ---- RIGHT: detail editor ----
                Flickable {
                    width: parent.width - 260 - Theme.sp3 * 2 - 1
                    height: parent.height
                    clip: true
                    contentHeight: detailCol.height
                    flickableDirection: Flickable.VerticalFlick
                    FastWheel {}

                    Column {
                        id: detailCol
                        width: parent.width
                        spacing: Theme.sp3

                        // no selection state
                        Text {
                            visible: !_selectedRule
                            width: parent.width
                            text: "Select a rule from the list."
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBody
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: Theme.sp8
                        }

                        // ---- rule name + toggle ----
                        Row {
                            visible: !!_selectedRule
                            width: parent.width
                            spacing: Theme.sp2

                            Text {
                                text: _selectedRule ? (_selectedRule.name || "Unnamed") : ""
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsTitle
                                font.weight: Font.Bold
                                elide: Text.ElideRight
                                width: parent.width - 30 - enableToggle.width - Theme.sp2 * 2
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            YSwitch {
                                id: enableToggle
                                checked: _selectedRule ? _selectedRule.enabled : false
                                anchors.verticalCenter: parent.verticalCenter
                                onToggled: {
                                    if (_selectedRule)
                                        RuleService.toggleEnabled(_selectedRule.id);
                                }
                            }

                            YButton {
                                label: "TEST"
                                tone: "acid"
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    if (_selectedRule)
                                        RuleService.testRule(_selectedRule.id);
                                }
                            }

                            YButton {
                                label: "DEL"
                                tone: "danger"
                                anchors.verticalCenter: parent.verticalCenter
                                onClicked: {
                                    if (_selectedRule) {
                                        const id = _selectedRule.id;
                                        _selectedRule = null;
                                        RuleService.remove(id);
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: !!_selectedRule
                            width: parent.width; height: 1
                            color: Theme.lineStrong
                        }

                        // ---- TRIGGER section ----
                        Column {
                            visible: !!_selectedRule
                            width: parent.width
                            spacing: Theme.sp2

                            YSection {
                                index: "01"
                                label: "TRIGGER"
                                chip: _selectedRule ? _triggerLabel(_selectedRule.trigger) : ""
                                width: parent.width
                            }

                            // trigger type selector
                            Flow {
                                width: parent.width
                                spacing: 6

                                Repeater {
                                    model: _triggerTypes

                                    Rectangle {
                                        required property var modelData
                                        property bool isActive: _selectedRule && _selectedRule.trigger && _selectedRule.trigger.type === modelData.id
                                        width: triggerLabel.implicitWidth + 16
                                        height: 26
                                        radius: Theme.radius
                                        color: isActive ? Theme.acid + "22" : Theme.bg
                                        border.width: 1
                                        border.color: isActive ? Theme.acid : Theme.hairline

                                        Text {
                                            id: triggerLabel
                                            anchors.centerIn: parent
                                            text: modelData.label
                                            color: isActive ? Theme.acid : Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsMicro
                                            font.weight: Font.DemiBold
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (_selectedRule) {
                                                    const cfg = _selectedRule.trigger?.config ?? {};
                                                    RuleService.update(_selectedRule.id, {
                                                        trigger: { type: modelData.id, config: cfg }
                                                    });
                                                    _syncSelected();
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // time config
                            Column {
                                visible: _selectedRule && _selectedRule.trigger?.type === "time"
                                width: parent.width
                                spacing: 6

                                Row {
                                    spacing: Theme.sp2
                                    Text { text: "Hour:"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsLabel; anchors.verticalCenter: parent.verticalCenter }
                                    Repeater {
                                        model: 24
                                        Rectangle {
                                            required property int index
                                            property bool isActive: _selectedRule && _selectedRule.trigger?.config?.hour === index
                                            width: 24; height: 22; radius: 4
                                            color: isActive ? Theme.acid : Theme.bg
                                            border.width: 1; border.color: isActive ? Theme.acid : Theme.hairline
                                            Text {
                                                anchors.centerIn: parent
                                                text: String(index).padStart(2, "0")
                                                color: isActive ? Theme.ink : Theme.muted
                                                font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (_selectedRule) {
                                                        const cfg = Object.assign({}, _selectedRule.trigger?.config ?? {}, { hour: index });
                                                        RuleService.update(_selectedRule.id, { trigger: { type: "time", config: cfg } });
                                                        _syncSelected();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Row {
                                    spacing: Theme.sp2
                                    Text { text: "Min:"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsLabel; anchors.verticalCenter: parent.verticalCenter }
                                    Repeater {
                                        model: [0, 15, 30, 45]
                                        Rectangle {
                                            required property int index
                                            required property var modelData
                                            property bool isActive: _selectedRule && _selectedRule.trigger?.config?.minute === modelData
                                            width: 30; height: 22; radius: 4
                                            color: isActive ? Theme.acid : Theme.bg
                                            border.width: 1; border.color: isActive ? Theme.acid : Theme.hairline
                                            Text {
                                                anchors.centerIn: parent
                                                text: String(modelData).padStart(2, "0")
                                                color: isActive ? Theme.ink : Theme.muted
                                                font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (_selectedRule) {
                                                        const cfg = Object.assign({}, _selectedRule.trigger?.config ?? {}, { minute: modelData });
                                                        RuleService.update(_selectedRule.id, { trigger: { type: "time", config: cfg } });
                                                        _syncSelected();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                Row {
                                    spacing: 6
                                    Text { text: "Days:"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsLabel; anchors.verticalCenter: parent.verticalCenter }
                                    Repeater {
                                        model: ["S", "M", "T", "W", "T", "F", "S"]
                                        Rectangle {
                                            required property int index
                                            required property string modelData
                                            property bool isActive: _selectedRule && (_selectedRule.trigger?.config?.days ?? []).indexOf(index) >= 0
                                            width: 24; height: 22; radius: 4
                                            color: isActive ? Theme.acid : Theme.bg
                                            border.width: 1; border.color: isActive ? Theme.acid : Theme.hairline
                                            Text {
                                                anchors.centerIn: parent
                                                text: modelData
                                                color: isActive ? Theme.ink : Theme.muted
                                                font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold
                                            }
                                            MouseArea {
                                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (_selectedRule) {
                                                        const cfg = Object.assign({}, _selectedRule.trigger?.config ?? {});
                                                        let days = (cfg.days ?? []).slice();
                                                        const pos = days.indexOf(index);
                                                        if (pos >= 0) days.splice(pos, 1);
                                                        else days.push(index);
                                                        cfg.days = days;
                                                        RuleService.update(_selectedRule.id, { trigger: { type: "time", config: cfg } });
                                                        _syncSelected();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Text { text: "(empty = daily)"; color: Theme.faint; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }

                            // battery config
                            Column {
                                visible: _selectedRule && _selectedRule.trigger?.type === "battery"
                                width: parent.width; spacing: 6
                                Row {
                                    spacing: Theme.sp2
                                    Text { text: "Condition:"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsLabel; anchors.verticalCenter: parent.verticalCenter }
                                    Repeater {
                                        model: ["below", "above"]
                                        Rectangle {
                                            required property string modelData
                                            property bool isActive: _selectedRule && (_selectedRule.trigger?.config?.op ?? "below") === modelData
                                            width: 60; height: 24; radius: 4
                                            color: isActive ? Theme.acid : Theme.bg
                                            border.width: 1; border.color: isActive ? Theme.acid : Theme.hairline
                                            Text { anchors.centerIn: parent; text: modelData; color: isActive ? Theme.ink : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                                                if (_selectedRule) { const cfg = Object.assign({}, _selectedRule.trigger?.config ?? {}, { op: modelData }); RuleService.update(_selectedRule.id, { trigger: { type: "battery", config: cfg } }); _syncSelected(); }
                                            }}
                                        }
                                    }
                                    Text { text: "Threshold:"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsLabel; anchors.verticalCenter: parent.verticalCenter }
                                    Repeater {
                                        model: [10, 15, 20, 30, 50]
                                        Rectangle {
                                            required property int modelData
                                            property bool isActive: _selectedRule && (_selectedRule.trigger?.config?.threshold ?? 20) === modelData
                                            width: 36; height: 24; radius: 4
                                            color: isActive ? Theme.acid : Theme.bg
                                            border.width: 1; border.color: isActive ? Theme.acid : Theme.hairline
                                            Text { anchors.centerIn: parent; text: modelData + "%"; color: isActive ? Theme.ink : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                                                if (_selectedRule) { const cfg = Object.assign({}, _selectedRule.trigger?.config ?? {}, { threshold: modelData }); RuleService.update(_selectedRule.id, { trigger: { type: "battery", config: cfg } }); _syncSelected(); }
                                            }}
                                        }
                                    }
                                }
                            }

                            // network config
                            Column {
                                visible: _selectedRule && _selectedRule.trigger?.type === "network"
                                width: parent.width; spacing: 6
                                Row {
                                    spacing: Theme.sp2
                                    Text { text: "Event:"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsLabel; anchors.verticalCenter: parent.verticalCenter }
                                    Repeater {
                                        model: ["connected", "disconnected"]
                                        Rectangle {
                                            required property string modelData
                                            property bool isActive: _selectedRule && (_selectedRule.trigger?.config?.event ?? "connected") === modelData
                                            width: 100; height: 24; radius: 4
                                            color: isActive ? Theme.acid : Theme.bg
                                            border.width: 1; border.color: isActive ? Theme.acid : Theme.hairline
                                            Text { anchors.centerIn: parent; text: modelData; color: isActive ? Theme.ink : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                                                if (_selectedRule) { const cfg = { event: modelData }; RuleService.update(_selectedRule.id, { trigger: { type: "network", config: cfg } }); _syncSelected(); }
                                            }}
                                        }
                                    }
                                }
                            }

                            // recording config
                            Column {
                                visible: _selectedRule && _selectedRule.trigger?.type === "recording"
                                width: parent.width; spacing: 6
                                Row {
                                    spacing: Theme.sp2
                                    Text { text: "Event:"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsLabel; anchors.verticalCenter: parent.verticalCenter }
                                    Repeater {
                                        model: ["started", "stopped"]
                                        Rectangle {
                                            required property string modelData
                                            property bool isActive: _selectedRule && (_selectedRule.trigger?.config?.event ?? "started") === modelData
                                            width: 80; height: 24; radius: 4
                                            color: isActive ? Theme.acid : Theme.bg
                                            border.width: 1; border.color: isActive ? Theme.acid : Theme.hairline
                                            Text { anchors.centerIn: parent; text: modelData; color: isActive ? Theme.ink : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                                                if (_selectedRule) { const cfg = { event: modelData }; RuleService.update(_selectedRule.id, { trigger: { type: "recording", config: cfg } }); _syncSelected(); }
                                            }}
                                        }
                                    }
                                }
                            }

                            // temperature config
                            Column {
                                visible: _selectedRule && _selectedRule.trigger?.type === "temperature"
                                width: parent.width; spacing: 6
                                Row {
                                    spacing: Theme.sp2
                                    Text { text: "Condition:"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsLabel; anchors.verticalCenter: parent.verticalCenter }
                                    Repeater {
                                        model: ["above", "below"]
                                        Rectangle {
                                            required property string modelData
                                            property bool isActive: _selectedRule && (_selectedRule.trigger?.config?.op ?? "above") === modelData
                                            width: 60; height: 24; radius: 4
                                            color: isActive ? Theme.acid : Theme.bg
                                            border.width: 1; border.color: isActive ? Theme.acid : Theme.hairline
                                            Text { anchors.centerIn: parent; text: modelData; color: isActive ? Theme.ink : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                                                if (_selectedRule) { const cfg = Object.assign({}, _selectedRule.trigger?.config ?? {}, { op: modelData }); RuleService.update(_selectedRule.id, { trigger: { type: "temperature", config: cfg } }); _syncSelected(); }
                                            }}
                                        }
                                    }
                                    Text { text: "Threshold:"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsLabel; anchors.verticalCenter: parent.verticalCenter }
                                    Repeater {
                                        model: [70, 75, 80, 85, 90, 95]
                                        Rectangle {
                                            required property int modelData
                                            property bool isActive: _selectedRule && (_selectedRule.trigger?.config?.threshold ?? 85) === modelData
                                            width: 40; height: 24; radius: 4
                                            color: isActive ? Theme.acid : Theme.bg
                                            border.width: 1; border.color: isActive ? Theme.acid : Theme.hairline
                                            Text { anchors.centerIn: parent; text: modelData + "°"; color: isActive ? Theme.ink : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                                                if (_selectedRule) { const cfg = Object.assign({}, _selectedRule.trigger?.config ?? {}, { threshold: modelData }); RuleService.update(_selectedRule.id, { trigger: { type: "temperature", config: cfg } }); _syncSelected(); }
                                            }}
                                        }
                                    }
                                }
                            }

                            // focused app config
                            Column {
                                visible: _selectedRule && _selectedRule.trigger?.type === "focusedApp"
                                width: parent.width; spacing: 6
                                Row {
                                    spacing: Theme.sp2
                                    Text { text: "App ID:"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsLabel; anchors.verticalCenter: parent.verticalCenter }
                                    Rectangle {
                                        width: 120; height: 24; radius: 4
                                        color: Theme.bg; border.width: 1; border.color: Theme.hairline
                                        TextInput {
                                            anchors.fill: parent; anchors.margins: 4
                                            color: Theme.ink; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro
                                            clip: true
                                            text: _selectedRule?.trigger?.config?.appId ?? ""
                                            onTextEdited: {
                                                if (_selectedRule) {
                                                    const cfg = Object.assign({}, _selectedRule.trigger?.config ?? {}, { appId: text });
                                                    RuleService.update(_selectedRule.id, { trigger: { type: "focusedApp", config: cfg } });
                                                }
                                            }
                                        }
                                    }
                                    Repeater {
                                        model: ["gained", "lost"]
                                        Rectangle {
                                            required property string modelData
                                            property bool isActive: _selectedRule && (_selectedRule.trigger?.config?.event ?? "gained") === modelData
                                            width: 60; height: 24; radius: 4
                                            color: isActive ? Theme.acid : Theme.bg
                                            border.width: 1; border.color: isActive ? Theme.acid : Theme.hairline
                                            Text { anchors.centerIn: parent; text: modelData; color: isActive ? Theme.ink : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                                                if (_selectedRule) { const cfg = Object.assign({}, _selectedRule.trigger?.config ?? {}, { event: modelData }); RuleService.update(_selectedRule.id, { trigger: { type: "focusedApp", config: cfg } }); _syncSelected(); }
                                            }}
                                        }
                                    }
                                }
                            }

                            // mpris config
                            Column {
                                visible: _selectedRule && _selectedRule.trigger?.type === "mpris"
                                width: parent.width; spacing: 6
                                Row {
                                    spacing: Theme.sp2
                                    Text { text: "Event:"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsLabel; anchors.verticalCenter: parent.verticalCenter }
                                    Repeater {
                                        model: ["started", "stopped"]
                                        Rectangle {
                                            required property string modelData
                                            property bool isActive: _selectedRule && (_selectedRule.trigger?.config?.event ?? "started") === modelData
                                            width: 80; height: 24; radius: 4
                                            color: isActive ? Theme.acid : Theme.bg
                                            border.width: 1; border.color: isActive ? Theme.acid : Theme.hairline
                                            Text { anchors.centerIn: parent; text: modelData; color: isActive ? Theme.ink : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                                                if (_selectedRule) { const cfg = { event: modelData }; RuleService.update(_selectedRule.id, { trigger: { type: "mpris", config: cfg } }); _syncSelected(); }
                                            }}
                                        }
                                    }
                                }
                            }

                            // idle config
                            Column {
                                visible: _selectedRule && _selectedRule.trigger?.type === "idle"
                                width: parent.width; spacing: 6
                                Row {
                                    spacing: Theme.sp2
                                    Text { text: "Seconds:"; color: Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsLabel; anchors.verticalCenter: parent.verticalCenter }
                                    Repeater {
                                        model: [60, 120, 300, 600, 900, 1800]
                                        Rectangle {
                                            required property int modelData
                                            property bool isActive: _selectedRule && (_selectedRule.trigger?.config?.seconds ?? 300) === modelData
                                            width: 44; height: 24; radius: 4
                                            color: isActive ? Theme.acid : Theme.bg
                                            border.width: 1; border.color: isActive ? Theme.acid : Theme.hairline
                                            Text { anchors.centerIn: parent; text: modelData >= 60 ? (modelData / 60) + "m" : modelData + "s"; color: isActive ? Theme.ink : Theme.muted; font.family: Theme.fontFamily; font.pixelSize: Theme.fsMicro; font.weight: Font.Bold }
                                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                                                if (_selectedRule) { const cfg = { seconds: modelData }; RuleService.update(_selectedRule.id, { trigger: { type: "idle", config: cfg } }); _syncSelected(); }
                                            }}
                                        }
                                    }
                                }
                            }
                        }

                        // ---- ACTIONS section ----
                        Column {
                            visible: !!_selectedRule
                            width: parent.width
                            spacing: Theme.sp2

                            Rectangle {
                                width: parent.width; height: 1
                                color: Theme.lineStrong
                            }

                            YSection {
                                index: "02"
                                label: "ACTIONS"
                                chip: (_selectedRule?.actions?.length ?? 0) + " actions"
                                width: parent.width
                            }

                            // action chips (existing actions)
                            Column {
                                width: parent.width
                                spacing: 4

                                Repeater {
                                    model: _selectedRule ? (_selectedRule.actions ?? []) : []

                                    Rectangle {
                                        required property var modelData
                                        required property int index
                                        width: parent.width
                                        height: 36
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
                                                text: (index + 1) + "."
                                                color: Theme.acid
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsMicro
                                                font.weight: Font.Bold
                                                width: 20
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: _actionLabel(modelData)
                                                color: Theme.ink
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsLabel
                                                font.weight: Font.Bold
                                                width: 90
                                            }

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: _actionDesc(modelData)
                                                color: Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsMicro
                                                elide: Text.ElideRight
                                                width: parent.width - 20 - 90 - removeBtn.width - Theme.sp2 * 3
                                            }

                                            YButton {
                                                id: removeBtn
                                                label: "X"
                                                tone: "danger"
                                                anchors.verticalCenter: parent.verticalCenter
                                                onClicked: {
                                                    if (_selectedRule) {
                                                        const actions = (_selectedRule.actions ?? []).slice();
                                                        actions.splice(index, 1);
                                                        RuleService.update(_selectedRule.id, { actions: actions });
                                                        _syncSelected();
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // add action chips
                                Flow {
                                    width: parent.width
                                    spacing: 6

                                    Repeater {
                                        model: _actionTypes

                                        Rectangle {
                                            required property var modelData
                                            width: addLabel.implicitWidth + 16
                                            height: 26
                                            radius: Theme.radius
                                            color: Theme.bg
                                            border.width: 1
                                            border.color: Theme.hairline

                                            Text {
                                                id: addLabel
                                                anchors.centerIn: parent
                                                text: "+ " + modelData.label
                                                color: Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsMicro
                                                font.weight: Font.DemiBold
                                            }

                                            MouseArea {
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (_selectedRule) {
                                                        const actions = (_selectedRule.actions ?? []).slice();
                                                        actions.push(_defaultAction(modelData.id));
                                                        RuleService.update(_selectedRule.id, { actions: actions });
                                                        _syncSelected();
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
        }
    }

    function _defaultAction(type) {
        switch (type) {
        case "setProfile": return { type: type, config: { id: "" } };
        case "setPowerProfile": return { type: type, config: { name: "balanced" } };
        case "toggleDnd": return { type: type, config: { enabled: true } };
        case "runCommand": return { type: type, config: { cmd: "" } };
        case "notify": return { type: type, config: { title: "Alert", body: "" } };
        case "setWallpaper": return { type: type, config: { path: "" } };
        case "setNightLight": return { type: type, config: { active: true } };
        case "setBarPreset": return { type: type, config: { id: "" } };
        default: return { type: type, config: {} };
        }
    }
}
