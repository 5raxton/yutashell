import Quickshell.Hyprland
import QtQuick
import qs.theme

Item {
    id: root

    readonly property int slotW: 30
    readonly property int slotH: 24
    readonly property int gap: 5

    readonly property var ids: {
        const s = new Set();
        for (const w of Hyprland.workspaces.values)
            if (w.id > 0 && w.id <= 12)
                s.add(w.id);
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
            if (evt.name !== "urgent")
                return;
            const addr = String(evt.data ?? "").replace(/^0x/, "");
            const tl = Hyprland.toplevels.values.find(t => String(t.address).replace(/^0x/, "") === addr);
            if (tl?.workspace && tl.workspace.id > 0)
                root.markUrgent(tl.workspace.id);
        }

        function onFocusedWorkspaceChanged() {
            root.clearUrgent(Hyprland.focusedWorkspace?.id ?? -1);
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
                    color: isActive ? Theme.acid : area.containsMouse ? Theme.surface : "transparent"
                    border.width: !isActive && (isOccupied || area.containsMouse) && !isUrgent ? 1 : 0
                    border.color: Theme.lineStrong

                    Text {
                        anchors.centerIn: parent
                        text: String(btn.modelData).padStart(2, "0")
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                        color: {
                            if (btn.isActive)
                                return Theme.bg;
                            if (btn.isUrgent)
                                return root.blinkOn ? Theme.alert : Theme.faint;
                            if (btn.isOccupied)
                                return Theme.ink;
                            return Theme.faint;
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
            color: Theme.acid
            visible: root.ids.includes(root.focusedId)
            x: Math.max(0, root.ids.indexOf(root.focusedId)) * (root.slotW + root.gap)

            Behavior on x {
                NumberAnimation {
                    duration: 140
                    easing.type: Easing.OutCubic
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
