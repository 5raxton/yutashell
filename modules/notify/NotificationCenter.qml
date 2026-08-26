import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"

// Notification center — browsable history ring. Same house surface as the
// control core: YSurface card dropping from behind the bar, input masked to
// the card, ESC closes, exclusive with every other popup.
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
    visible: ShellState.notifyCenterOpen || hideDelay.running
    mask: Region {
        item: ShellState.notifyCenterOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.notifyCenterOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: 700
    readonly property int cardH: Math.min(540, contentRoot.height - Theme.barHeight - Theme.outerPad * 2)
    readonly property int padX: Theme.sp4

    // PH.03.4: filtered history by search query
    property string _searchQuery: ""
    readonly property var _filteredHistory: {
        const q = _searchQuery.trim().toLowerCase();
        if (q.length === 0) return Notify.history.map((e, i) => Object.assign({}, e, { _idx: i }));
        return Notify.history.map((e, i) => Object.assign({}, e, { _idx: i })).filter(e => {
            const hay = ((e.app || "") + " " + (e.sum || "") + " " + (e.body || "")).toLowerCase();
            return hay.indexOf(q) >= 0;
        });
    }

    // PH.03.1: grouped by appName
    readonly property var _groupedHistory: {
        const groups = {};
        const src = _filteredHistory;
        for (let i = 0; i < src.length; i++) {
            const e = src[i];
            const k = e.app || "unknown";
            if (!groups[k]) groups[k] = [];
            groups[k].push(Object.assign({}, e, { _idx: i }));
        }
        // sort groups by most recent entry descending
        const keys = Object.keys(groups).sort((a, b) => {
            return (groups[b][0].t || 0) - (groups[a][0].t || 0);
        });
        return keys.map(k => ({ app: k, entries: groups[k] }));
    }

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    // linger mapped after close so YSurface's exit ceremony renders
    // rows only exist from the first open — 50 history delegates otherwise
    // instantiate invisibly at every boot
    property bool _everOpened: false

    Connections {
        target: ShellState

        function onNotifyCenterOpenChanged() {
            if (ShellState.notifyCenterOpen)
                root._everOpened = true;
            else
                hideDelay.restart();
        }
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeNotifyCenter()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeNotifyCenter()
        }

        YSurface {

            spawnId: "notify"
            id: surface

            open: ShellState.notifyCenterOpen
            cascade: listCol
            anchorX: "right"
            cardW: root.cardW
            cardH: Math.max(320, root.cardH)

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
                        text: "⏾"
                        color: Theme.acid
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBody
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: mark.right
                    anchors.leftMargin: Theme.sp2
                    text: "NOTIFICATION.CENTER"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 236
                    visible: Theme.jpEnabled
                    text: "通知"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 2
                }

                YChip {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    label: Notify.history.length + " KEPT"
                    tone: "outline"
                }
            }

            Rectangle {
                x: root.padX
                y: Theme.headH
                width: surface.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            // ---- DND row ----
            YRow {
                id: dndRow

                x: root.padX
                y: Theme.headH + 1
                width: surface.width - root.padX * 2 - 1
                title: "Do not disturb"
                sub: Notify.dnd ? Notify.suppressedCount + " suppressed since on" : "toasts land normally; critical always breaks through"
                note: "DND"
                on_: Notify.dnd
                onToggled: Notify.toggleDnd()

                YChip {
                    visible: Notify.dnd && Notify.suppressedCount > 0
                    label: String(Notify.suppressedCount)
                    tone: "acid"
                }

                // PH.03.3: snooze chip
                Item {
                    visible: Notify.snoozed
                    width: snoozeChip.implicitWidth
                    height: snoozeChip.height

                    YChip {
                        id: snoozeChip
                        label: "Zzz " + Notify.snoozeRemaining + "m"
                        tone: "outline"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Notify.clearSnooze()
                    }
                }
            }

            // PH.03.4: search field
            Rectangle {
                id: searchRow

                x: root.padX
                y: dndRow.y + dndRow.height + Theme.sp2
                width: surface.width - root.padX * 2 - 1
                height: searchField.height + Theme.sp2 * 2
                color: "transparent"

                YField {
                    id: searchField
                    anchors.fill: parent
                    anchors.margins: Theme.sp1
                    placeholder: "Search notifications..."
                    onTextChanged: root._searchQuery = text
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.sp2
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchField.text.length > 0
                    text: "×"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        cursorShape: Qt.PointingHandCursor
                        onClicked: searchField.text = ""
                    }
                }
            }

            // PH.03.1: grouping toggle
            Row {
                x: root.padX
                y: searchRow.y + searchRow.height + Theme.sp1
                spacing: Theme.sp2

                Item {
                    width: groupChip.implicitWidth
                    height: groupChip.height

                    YChip {
                        id: groupChip
                        label: ShellState.notifyGrouped ? "GROUPED" : "FLAT"
                        tone: ShellState.notifyGrouped ? "acid" : "outline"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ShellState.set("notifyGrouped", !ShellState.notifyGrouped)
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: searchField.text.length > 0
                    text: root._filteredHistory.length + " FOUND"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 1
                }
            }

            // ---- history list ----
            Flickable {
                id: listFlick

                x: root.padX
                y: dndRow.y + dndRow.height + Theme.sp2 + searchRow.height + Theme.sp2 + 36
                width: surface.width - root.padX * 2 - 1
                height: surface.height - (dndRow.y + dndRow.height) - searchRow.height - 60 - Theme.footH - Theme.sp3
                clip: true
                contentWidth: width
                contentHeight: listCol.height

                FastWheel {}


                Column {
                    id: listCol

                    width: parent.width
                    spacing: 0

                    // PH.03.1: grouped view
                    Repeater {
                        model: (root._everOpened && ShellState.notifyGrouped) ? root._groupedHistory : []

                        delegate: Item {
                            id: groupRoot

                            required property var modelData
                            required property int index

                            width: listFlick.width
                            height: groupCol.height

                            property bool expanded: Notify.isGroupExpanded(modelData.app)

                            Column {
                                id: groupCol

                                width: parent.width
                                spacing: 0

                                // group header
                                Rectangle {
                                    width: listFlick.width
                                    height: 36
                                    color: groupHeaderArea.containsMouse ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.04) : "transparent"

                                    Rectangle {
                                        anchors.top: parent.top
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        height: 1
                                        color: Theme.hairline
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: Theme.sp1
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: groupRoot.modelData.app.toUpperCase()
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        font.letterSpacing: 1
                                    }

                                    Text {
                                        anchors.left: parent.left
                                        anchors.leftMargin: 80
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "×" + groupRoot.modelData.entries.length
                                        color: Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.rightMargin: Theme.sp2
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: groupRoot.expanded ? "▼" : "▶"
                                        color: Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                    }

                                    MouseArea {
                                        id: groupHeaderArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        acceptedButtons: Qt.NoButton
                                        onEntered: {} // just for hover color
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Notify.toggleGroup(groupRoot.modelData.app)
                                    }
                                }

                                // expanded entries
                                Repeater {
                                    model: groupRoot.expanded ? groupRoot.modelData.entries : []

                                    delegate: Item {
                                        id: groupEntry

                                        required property var modelData
                                        required property int index

                                        width: listFlick.width
                                        height: 40

                                        Rectangle {
                                            anchors.fill: parent
                                            color: groupEntryHover.containsMouse ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.04) : "transparent"
                                        }

                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 3
                                            height: 12
                                            color: groupEntry.modelData.urg === 2 ? Theme.alert : groupEntry.modelData.sup ? Theme.muted : Theme.acid
                                        }

                                        Column {
                                            anchors.left: parent.left
                                            anchors.leftMargin: Theme.sp3
                                            anchors.right: groupEntryActions.left
                                            anchors.rightMargin: Theme.sp2
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 1

                                            Text {
                                                width: parent.width
                                                text: (groupEntry.modelData.sum.length > 0 ? groupEntry.modelData.sum : groupEntry.modelData.body || "").replace(/\n/g, " ").replace(/<[^>]*>/g, "")
                                                color: Theme.ink
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsLabel
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                visible: groupEntry.modelData.body.length > 0
                                                width: parent.width
                                                text: groupEntry.modelData.body.replace(/\n/g, " ").replace(/<[^>]*>/g, "")
                                                color: Theme.muted
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsMicro
                                                elide: Text.ElideRight
                                            }
                                        }

                                        Row {
                                            id: groupEntryActions

                                            anchors.right: parent.right
                                            anchors.rightMargin: Theme.sp1
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: Theme.sp1
                                            visible: groupEntryHover.containsMouse

                                            YButton {
                                                label: "REPLAY"
                                                onClicked: Notify.replay(groupEntry.modelData)
                                            }

                                            YButton {
                                                label: "×"
                                                tone: "danger"
                                                onClicked: Notify.removeHistory(groupEntry.modelData._idx)
                                            }
                                        }

                                        MouseArea {
                                            id: groupEntryHover
                                            anchors.fill: parent
                                            anchors.rightMargin: groupEntryActions.visible ? groupEntryActions.width + Theme.sp1 : 0
                                            hoverEnabled: true
                                            acceptedButtons: Qt.NoButton
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // flat view (original)
                    Repeater {
                        model: (root._everOpened && !ShellState.notifyGrouped) ? root._filteredHistory : 0

                        delegate: Item {
                            id: rowRoot

                            required property int index
                            required property var modelData

                            width: listFlick.width
                            height: 44

                            readonly property bool hovered: harea.containsMouse

                            Rectangle {
                                anchors.fill: parent
                                color: rowRoot.hovered ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.04) : "transparent"
                            }

                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Theme.hairline
                            }

                            Text {
                                id: timeText

                                visible: Notify.fields.time
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.sp1
                                anchors.verticalCenter: parent.verticalCenter
                                text: {
                                    const d = new Date(rowRoot.modelData.t);
                                    const hm = String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0");
                                    // entries from other days need the date, or "14:03" lies across sessions
                                    const now = new Date();
                                    if (d.toDateString() === now.toDateString())
                                        return hm;
                                    const mon = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"][d.getMonth()];
                                    return mon + " " + d.getDate() + " · " + hm;
                                }
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                            }

                            Rectangle {
                                id: urgTick

                                anchors.left: timeText.visible ? timeText.right : parent.left
                                anchors.leftMargin: Theme.sp1
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3
                                height: 14
                                color: rowRoot.modelData.urg === 2 ? Theme.alert : rowRoot.modelData.sup ? Theme.muted : Theme.acid
                            }

                            Column {
                                id: entryCol

                                anchors.left: urgTick.right
                                anchors.leftMargin: Theme.sp2
                                anchors.right: actionsRow.visible ? actionsRow.left : parent.right
                                anchors.rightMargin: Theme.sp2
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Row {
                                    spacing: Theme.sp2

                                    Text {
                                        // cap so long app ids can't run under the hover actions
                                        width: Math.min(implicitWidth, entryCol.width * 0.6)
                                        elide: Text.ElideRight
                                        text: rowRoot.modelData.app.toUpperCase()
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        font.letterSpacing: 1
                                    }

                                    Text {
                                        visible: rowRoot.modelData.sup
                                        text: "⏾ QUIET"
                                        color: Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        font.letterSpacing: 1
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: (rowRoot.modelData.sum.length > 0 ? rowRoot.modelData.sum + " — " : "") + rowRoot.modelData.body.replace(/\n/g, " ").replace(/<[^>]*>/g, "")
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                    elide: Text.ElideRight
                                }
                            }

                            Row {
                                id: actionsRow

                                anchors.right: parent.right
                                anchors.rightMargin: Theme.sp1
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.sp1
                                visible: rowRoot.hovered

                                YButton {
                                    label: "REPLAY"
                                    onClicked: Notify.replay(rowRoot.modelData)
                                }

                                YButton {
                                    label: "×"
                                    tone: "danger"
                                    onClicked: Notify.removeHistory(rowRoot.modelData._idx)
                                }
                            }

                            MouseArea {
                                id: harea

                                anchors.fill: parent
                                anchors.rightMargin: actionsRow.visible ? actionsRow.width + Theme.sp1 : 0
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }

                    Item {
                        width: 1
                        height: Theme.sp2
                    }
                }
            }

            YScroll {
                target: listFlick
                x: listFlick.x + listFlick.width - 4
                y: listFlick.y
                width: 3
                height: listFlick.height
            }

            // empty state
            Column {
                anchors.centerIn: parent
                visible: Notify.history.length === 0 || (searchField.text.length > 0 && root._filteredHistory.length === 0)
                spacing: Theme.sp2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: searchField.text.length > 0 ? "NO MATCHES" : "NO HISTORY"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 3
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Theme.jpEnabled
                    text: searchField.text.length > 0 ? "該当なし" : "履歴なし"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 2
                }
            }

            // ---- footer ----
            Rectangle {
                x: 0
                y: surface.height - Theme.footH
                width: surface.width
                height: Theme.footH
                color: "transparent"

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 1
                    color: Theme.hairline
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: root.padX
                    anchors.verticalCenter: parent.verticalCenter
                    text: searchField.text.length > 0 ? root._filteredHistory.length + " FOUND · RING 50" : "RING 50 · PERSISTED 30"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 1
                }

                // two-step destructive action: first click arms, second wipes
                YButton {
                    id: clearBtn

                    anchors.right: parent.right
                    anchors.rightMargin: root.padX
                    anchors.verticalCenter: parent.verticalCenter
                    label: armed ? "SURE?" : "CLEAR ALL"
                    tone: "danger"
                    onClicked: {
                        if (!armed) {
                            armed = true;
                            disarm.restart();
                        } else {
                            Notify.clearHistory();
                            armed = false;
                            disarm.stop();
                        }
                    }

                    property bool armed: false

                    Timer {
                        id: disarm

                        interval: 3000
                        onTriggered: clearBtn.armed = false
                    }
                }
            }
        }
    }
}
