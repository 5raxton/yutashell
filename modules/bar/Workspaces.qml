import Quickshell.Hyprland
import QtQuick
import qs.theme
import qs.modules.common

// Workspace segment. Five persisted render modes (ShellState.wsMode):
//   default — numbered pills with occupied borders + moving underline
//   numbers — bare digits, focus carries the accent
//   pills   — boxes without digits, state read from fill/border alone
//   active  — default look, but ONLY workspaces that actually exist
//   thumbnails — mini workspace cards showing window count + app icons
Item {
    id: root

    readonly property string mode: {
        const m = String(ShellState.wsMode ?? "");
        return m === "numbers" || m === "pills" || m === "active" || m === "thumbnails" ? m : "default";
    }
    readonly property bool bare: mode === "numbers"
    readonly property bool pillOnly: mode === "pills"
    readonly property bool thumbMode: mode === "thumbnails"

    readonly property int slotW: thumbMode ? 52 : mode === "numbers" ? 21 : pillOnly ? 18 : 30
    readonly property int slotH: thumbMode ? 34 : pillOnly ? 18 : 24
    readonly property int gap: thumbMode ? 5 : pillOnly ? 7 : 5

    readonly property var ids: {
        const live = new Set();
        for (const w of Hyprland.workspaces.values)
            if (w.id > 0 && w.id <= 24)
                live.add(w.id);
        if (mode === "active") {
            const list = Array.from(live).sort((a, b) => a - b);
            return list.length > 0 ? list : [1];
        }
        const s = new Set(live);
        let i = 1;
        while (s.size < 6) {
            const prev = s.size;
            s.add(i++);
            if (s.size === prev)
                i = s.size + 1;
        }
        return Array.from(s).sort((a, b) => a - b);
    }

    readonly property int focusedId: Hyprland.focusedWorkspace?.id ?? -1

    property var urgentIds: []
    property bool blinkOn: false

    // self-managed urgency from Hyprland's event stream (was previously wired
    // from the Bar; moved here so the segment is drop-in independent)
    Connections {
        target: Hyprland

        function onRawEvent(evt) {
            if (evt.name === "urgent") {
                const addr = String(evt.data ?? "").replace(/^0x/, "");
                const tl = Hyprland.toplevels.values.find(t => String(t.address).replace(/^0x/, "") === addr);
                if (tl?.workspace && tl.workspace.id > 0)
                    root.markUrgent(tl.workspace.id);
            } else if (evt.name === "destroyworkspace") {
                // the workspace itself is gone — nothing left to blink for
                const id = parseInt(String(evt.data ?? ""));
                if (!isNaN(id))
                    root.clearUrgent(id);
            } else if (evt.name === "closewindow") {
                // the model may still carry the closing window — sweep after
                // it settles so latches never blink at a dead workspace
                urgentSweep.restart();
            }
        }

        function onFocusedWorkspaceChanged() {
            root.clearUrgent(Hyprland.focusedWorkspace?.id ?? -1);
        }
    }

    Timer {
        id: urgentSweep

        interval: 400
        onTriggered: {
            const live = new Set();
            const vals = Hyprland.toplevels.values;
            for (let i = 0; i < vals.length; i++) {
                const ws = vals[i].workspace;
                if (ws && ws.id > 0)
                    live.add(ws.id);
            }
            root.urgentIds = root.urgentIds.filter(id => live.has(id));
        }
    }

    function switchTo(id) {
        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })');
    }

    function sendWindowTo(id) {
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + id + '" })');
    }

    function markUrgent(id) {
        if (!id || id < 1 || root.urgentIds.includes(id))
            return;
        const next = root.urgentIds.slice();
        next.push(id);
        root.urgentIds = next;
    }

    function clearUrgent(id) {
        if (!root.urgentIds.includes(id))
            return;
        root.urgentIds = root.urgentIds.filter(i => i !== id);
    }

    implicitWidth: ids.length * slotW + Math.max(0, ids.length - 1) * gap
    implicitHeight: Theme.scaledBarHeight

    Timer {
        interval: 400
        running: root.urgentIds.length > 0
        repeat: true
        onTriggered: root.blinkOn = !root.blinkOn
    }

    Item {
        anchors.centerIn: parent
        width: root.implicitWidth
        height: root.slotH + 6

        Row {
            spacing: root.gap

            Repeater {
                model: root.ids

                delegate: Rectangle {
                    id: btn
                    required property int modelData

                    readonly property bool isActive: modelData === root.focusedId
                    readonly property bool isOccupied: Hyprland.workspaces.values.some(w => w.id === modelData)
                    readonly property bool isUrgent: !isActive && root.urgentIds.includes(modelData)

                    width: root.slotW
                    height: root.slotH
                    radius: root.pillOnly ? 3 : 0
                    color: {
                        if (root.bare)
                            return "transparent";
                        if (isActive)
                            return Theme.acid;
                        return area.containsMouse ? Theme.surface : "transparent";
                    }
                    border.width: {
                        if (root.bare)
                            return 0;
                        if (isActive)
                            return 0;
                        if (isUrgent && root.blinkOn)
                            return 0;
                        return (isOccupied || area.containsMouse) ? 1 : 0;
                    }
                    border.color: isUrgent ? Theme.alert : Theme.lineStrong
                    scale: isActive ? 1.08 : (area.containsMouse ? 1.04 : 1)

                    Behavior on border.color {
                        ColorAnimation { duration: Theme.movFast }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.movFast
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.movSnap
                            easing.type: Easing.OutBack
                            easing.overshoot: 0.3
                        }
                    }

                    // digits — hidden in pills and thumbnails mode
                    Text {
                        anchors.centerIn: parent
                        visible: !root.pillOnly && !root.thumbMode
                        text: String(btn.modelData).padStart(2, "0")
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(10 * Theme.barScale)
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                        color: {
                            if (btn.isActive)
                                return root.bare ? Theme.acid : Theme.bg;
                            if (btn.isUrgent)
                                return root.blinkOn ? Theme.alert : Theme.faint;
                            if (btn.isOccupied)
                                return Theme.ink;
                            return area.containsMouse ? Theme.muted : Theme.faint;
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.movFast
                            }
                        }
                    }

                    // pills-mode state glyph: filled block when focused,
                    // hollow outline when windows live there, dim dot otherwise
                    Rectangle {
                        anchors.centerIn: parent
                        visible: root.pillOnly
                        width: btn.isActive ? 10 : 6
                        height: width
                        radius: 1
                        color: {
                            if (btn.isActive)
                                return btn.isUrgent && root.blinkOn ? Theme.alert : Theme.acid;
                            if (btn.isOccupied)
                                return "transparent";
                            return area.containsMouse ? Theme.faint : Theme.hairline;
                        }
                        border.width: btn.isOccupied && !btn.isActive ? 1 : 0
                        border.color: btn.isUrgent && root.blinkOn ? Theme.alert : Theme.muted

                        Behavior on border.color {
                            ColorAnimation { duration: Theme.movFast }
                        }

                        Behavior on color {
                            ColorAnimation { duration: Theme.movFast }
                        }

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.movSnap
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // PH.04.1: thumbnails mode — mini card with window count + app icons
                    Column {
                        anchors.centerIn: parent
                        visible: root.thumbMode
                        spacing: 1

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: String(btn.modelData).padStart(2, "0")
                            color: btn.isActive ? Theme.bg : (btn.isOccupied ? Theme.ink : Theme.faint)
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(9 * Theme.barScale)
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 2
                            visible: btn.isOccupied

                            Repeater {
                                model: {
                                    const wsWins = [];
                                    const tlVals = Hyprland.toplevels.values;
                                    for (let i = 0; i < tlVals.length; i++) {
                                        if (tlVals[i].workspace && tlVals[i].workspace.id === btn.modelData)
                                            wsWins.push(tlVals[i]);
                                    }
                                    // show up to 3 app icons
                                    const icons = [];
                                    const seen = {};
                                    for (let i = 0; i < wsWins.length && icons.length < 3; i++) {
                                        const appId = wsWins[i].wayland?.appId || wsWins[i].lastIpcObject?.class || "";
                                        if (appId && !seen[appId]) {
                                            seen[appId] = true;
                                            const e = DesktopEntries.byId(appId) || DesktopEntries.heuristicLookup(appId);
                                            icons.push(e ? (e.icon || "") : "");
                                        }
                                    }
                                    return icons;
                                }

                                Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: 8
                                    height: 8
                                    radius: 1
                                    color: "transparent"

                                    IconImage {
                                        anchors.fill: parent
                                        implicitSize: 8
                                        visible: modelData.length > 0 && status !== Image.Error
                                        source: modelData.length > 0 ? Quickshell.iconPath(modelData) : ""
                                    }

                                    // fallback dot
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 4
                                        height: 4
                                        radius: 2
                                        visible: modelData.length === 0 || parent.children[0].status === Image.Error
                                        color: Theme.acid
                                    }
                                }
                            }

                            // +N overflow indicator
                            Text {
                                visible: {
                                    let count = 0;
                                    const tlVals = Hyprland.toplevels.values;
                                    for (let i = 0; i < tlVals.length; i++) {
                                        if (tlVals[i].workspace && tlVals[i].workspace.id === btn.modelData)
                                            count++;
                                    }
                                    return count > 3;
                                }
                                text: "+"
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: 7
                            }
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: mouse => {
                            if (mouse.button === Qt.MiddleButton) {
                                root.sendWindowTo(btn.modelData);
                                return;
                            }
                            root.switchTo(btn.modelData);
                            root.clearUrgent(btn.modelData);
                        }
                    }
                }
            }
        }

        Rectangle {
            id: underline

            y: root.slotH + 4
            height: 2
            width: root.slotW
            radius: root.pillOnly ? 1 : 0
            color: Theme.acid
            visible: !root.pillOnly && !root.thumbMode && root.ids.includes(root.focusedId)
            x: Math.max(0, root.ids.indexOf(root.focusedId)) * (root.slotW + root.gap)

            Behavior on x {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }

        // acid glow aura behind the active workspace underline
        Rectangle {
            id: underlineGlow

            y: root.slotH + 2
            height: 6
            width: root.slotW + 12
            radius: 3
            color: Theme.acid
            opacity: 0.15
            visible: !root.pillOnly && !root.thumbMode && root.ids.includes(root.focusedId)
            x: underline.x - 6

            Behavior on x {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.movMed
                    easing.type: Easing.InOutSine
                }
            }
        }

        // ghost trail: stays at the OLD position while underline slides to new
        Rectangle {
            id: underlineTrail

            property real _prevX: 0

            y: root.slotH + 4
            height: 2
            width: root.slotW
            radius: root.pillOnly ? 1 : 0
            color: Theme.acid
            opacity: 0
            visible: !root.pillOnly && !root.thumbMode && root.ids.includes(root.focusedId)

            NumberAnimation on x {
                id: trailFadeX
                duration: 520
                easing.type: Easing.OutCubic
            }

            SequentialAnimation {
                id: trailAnim

                running: false

                ParallelAnimation {
                    NumberAnimation {
                        target: underlineTrail
                        property: "opacity"
                        from: 0.55
                        to: 0
                        duration: 520
                        easing.type: Easing.OutCubic
                    }
                    NumberAnimation {
                        target: underlineTrail
                        property: "width"
                        from: root.slotW + 14
                        to: root.slotW
                        duration: 520
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Connections {
                target: underline

                function onXChanged() {
                    underlineTrail._prevX = underlineTrail.x;
                    trailAnim.start();
                    trailFadeX.from = underlineTrail._prevX;
                    trailFadeX.to = underline.x;
                    trailFadeX.start();
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton

            onWheel: wheel => {
                const idx = root.ids.indexOf(root.focusedId);
                if (idx < 0)
                    return;
                const next = wheel.angleDelta.y > 0 ? Math.max(0, idx - 1) : Math.min(root.ids.length - 1, idx + 1);
                if (next !== idx)
                    root.switchTo(root.ids[next]);
            }
        }
    }
}
