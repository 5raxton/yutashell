import Quickshell.Hyprland
import QtQuick
import qs.theme
import qs.modules.common

// Workspace segment. Four persisted render modes (ShellState.wsMode):
//   default — numbered pills with occupied borders + moving underline
//   numbers — bare digits, focus carries the accent
//   pills   — boxes without digits, state read from fill/border alone
//   active  — default look, but ONLY workspaces that actually exist
Item {
    id: root

    readonly property string mode: {
        const m = String(ShellState.wsMode ?? "");
        return m === "numbers" || m === "pills" || m === "active" ? m : "default";
    }
    readonly property bool bare: mode === "numbers"
    readonly property bool pillOnly: mode === "pills"

    readonly property int slotW: mode === "numbers" ? 21 : pillOnly ? 18 : 30
    readonly property int slotH: pillOnly ? 18 : 24
    readonly property int gap: pillOnly ? 7 : 5

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
        while (s.size < 6)
            s.add(i++);
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
    implicitHeight: Theme.barHeight

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

                    Behavior on color {
                        ColorAnimation {
                            duration: Theme.movFast
                        }
                    }

                    // digits — hidden in pills mode entirely
                    Text {
                        anchors.centerIn: parent
                        visible: !root.pillOnly
                        text: String(btn.modelData).padStart(2, "0")
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
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

                        Behavior on width {
                            NumberAnimation {
                                duration: Theme.movSnap
                                easing.type: Easing.OutCubic
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
            visible: !root.pillOnly && root.ids.includes(root.focusedId)
            x: Math.max(0, root.ids.indexOf(root.focusedId)) * (root.slotW + root.gap)

            Behavior on x {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }

        // ghost trail that follows the underline on workspace switches
        Rectangle {
            id: underlineTrail

            y: root.slotH + 4
            height: 2
            width: root.slotW
            radius: root.pillOnly ? 1 : 0
            color: Theme.acid
            opacity: 0
            visible: !root.pillOnly && root.ids.includes(root.focusedId)
            x: underline.x

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
                    if (!trailAnim.running)
                        trailAnim.start();
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
