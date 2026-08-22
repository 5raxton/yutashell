import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "ui"

// CONTACT.SHEET — wallpaper browser docked to the right edge, full height.
// Same header/footer language as the control core so the two panels read as
// siblings. Columns adapt to available width; typing filters, arrows walk the
// cursor, enter applies, esc clears/closes. Picking runs the full pipeline:
// awww paint -> matugen -> every enabled template -> live shell recolor.
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
    visible: ShellState.pickerOpen || hideDelay.running
    mask: Region {
        item: ShellState.pickerOpen ? contentRoot : null
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: ShellState.pickerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int pad: Theme.sp4
    readonly property int sheetW: Math.max(560, Math.min(920, contentRoot.width - 140))
    // adaptive columns — no dead space at any window size
    readonly property int cols: {
        const avail = sheetW - pad * 2 - Theme.sp2;
        return Math.max(3, Math.floor(avail / 200));
    }
    readonly property int gridGap: Theme.sp2
    readonly property string homePrefix: Quickshell.env("HOME")

    // ---- filtered index + keyboard cursor ----
    property string query: ""
    property int cursorIdx: 0

    readonly property var filtered: {
        const q = query.toLowerCase();
        const all = Wallpaper.entries;
        if (q.length === 0)
            return all;
        return all.filter(e => e.label.toLowerCase().includes(q) || e.path.toLowerCase().includes(q));
    }

    function syncCursorToCurrent() {
        const idx = filtered.findIndex(e => e.path === Wallpaper.current);
        cursorIdx = idx >= 0 ? idx : 0;
        if (filtered.length > 0 && grid.visible)
            grid.positionViewAtIndex(cursorIdx, GridView.Contain);
    }

    function moveCursor(delta) {
        if (filtered.length === 0)
            return;
        const next = Math.max(0, Math.min(filtered.length - 1, cursorIdx + delta));
        if (next !== cursorIdx) {
            cursorIdx = next;
            grid.positionViewAtIndex(next, GridView.Contain);
        }
    }

    function pick(idx) {
        if (idx < 0 || idx >= filtered.length)
            return;
        Wallpaper.apply(filtered[idx].path);
        ShellState.closePicker();
    }

    onQueryChanged: {
        cursorIdx = 0;
        if (grid.visible && filtered.length > 0)
            grid.positionViewAtBeginning();
    }

    Timer {
        id: hideDelay

        interval: 170
    }

    Timer {
        id: blinkTimer

        interval: 500
        running: true
        repeat: true
        onTriggered: root.blinkOn = !root.blinkOn
    }

    property bool blinkOn: true

    Item {
        id: contentRoot

        anchors.fill: parent

        // ---- dim scrim ----
        Rectangle {
            anchors.fill: parent
            color: "#000000"
            opacity: ShellState.pickerOpen ? 0.55 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.movFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: ShellState.pickerOpen
            onClicked: ShellState.closePicker()
        }

        // ===== SHEET =====
        Rectangle {
            id: sheet

            width: root.sheetW
            height: parent.height
            x: ShellState.pickerOpen ? parent.width - width : parent.width
            color: Theme.bgAlt
            border.width: 1
            border.color: Theme.lineStrong
            layer.enabled: true
            layer.smooth: true

            Behavior on x {
                NumberAnimation {
                    duration: Theme.movMed
                    easing.type: Easing.OutCubic
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: mouse => mouse.accepted = true
            }

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: 1
                color: Theme.lineStrong
            }

            // corner tick motif — matches control core
            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                width: 2
                height: 26
                color: Theme.acid
            }

            // ===== HEADER =====
            Item {
                id: header

                x: root.pad
                y: 0
                width: parent.width - root.pad * 2 - 1
                height: Theme.headH

                Rectangle {
                    id: logo

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 24
                    height: 24
                    color: Theme.acid

                    Text {
                        anchors.centerIn: parent
                        text: "Y"
                        color: Theme.bg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBody
                        font.weight: Font.ExtraBold
                    }
                }

                Text {
                    id: titleText

                    anchors.left: logo.right
                    anchors.leftMargin: Theme.sp2
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CONTACT.SHEET"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: titleText.right
                    anchors.leftMargin: 5
                    width: 4
                    height: 12
                    color: Theme.acid
                    visible: root.blinkOn
                }

                Text {
                    anchors.baseline: titleText.baseline
                    anchors.left: titleText.right
                    anchors.leftMargin: Theme.sp3
                    text: Theme.jpEnabled ? "// 壁紙" : "// WALLPAPERS"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 2
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp1

                    YChip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: Wallpaper.scanning ? "scanning…" : root.filtered.length + " imgs"
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                y: Theme.headH
                height: 1
                color: Theme.hairline
            }

            // ===== SEARCH ROW =====
            Item {
                id: searchRow

                x: root.pad
                y: Theme.headH + Theme.sp3
                width: parent.width - root.pad * 2 - 1
                height: Theme.ctlH

                Rectangle {
                    id: searchBox

                    anchors.fill: parent
                    color: Theme.bg
                    border.width: 1
                    border.color: queryInput.activeFocus || root.query.length > 0 ? Theme.lineStrong : Theme.hairline

                    // acid focus bar
                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: queryInput.activeFocus ? Theme.acid : "transparent"
                    }

                    // hidden capture input: owns ALL key handling while the
                    // picker is open (printable chars land as text; every
                    // navigation key is intercepted below)
                    TextInput {
                        id: queryInput

                        anchors.fill: parent
                        visible: false
                        activeFocusOnPress: false
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBody
                        clip: true
                        onTextChanged: root.query = text

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                if (root.query.length > 0) {
                                    text = "";
                                    event.accepted = true;
                                } else {
                                    ShellState.closePicker();
                                }
                            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.pick(root.cursorIdx);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Left) {
                                root.moveCursor(-1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Right) {
                                root.moveCursor(1);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Up) {
                                root.moveCursor(-root.cols);
                                event.accepted = true;
                            } else if (event.key === Qt.Key_Down) {
                                root.moveCursor(root.cols);
                                event.accepted = true;
                            }
                        }
                    }

                    // rendered query + block cursor
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.sp2 + 2
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            visible: root.query.length === 0
                            text: "type to filter · arrows navigate · enter applies"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                            font.letterSpacing: 0.5
                        }

                        Text {
                            visible: root.query.length > 0
                            text: root.query.toUpperCase()
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBody
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1
                        }

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: root.query.length > 0 && root.blinkOn
                            width: 5
                            height: 13
                            color: Theme.acid
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.IBeamCursor
                        onClicked: queryInput.forceActiveFocus()
                    }
                }

                YButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 64
                    visible: root.query.length > 0
                    label: "clear"
                    onClicked: {
                        queryInput.text = "";
                        queryInput.forceActiveFocus();
                    }
                }
            }

            // ===== GRID =====
            GridView {
                id: grid

                readonly property int cellW: Math.floor((width - (root.cols - 1) * root.gridGap) / root.cols)
                readonly property int cellH: Math.round(cellW * 0.62)

                x: root.pad
                y: searchRow.y + searchRow.height + Theme.sp3
                width: parent.width - root.pad * 2 - 1
                height: parent.height - y - Theme.footH - Theme.sp3
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 4000
                cellWidth: cellW + root.gridGap
                cellHeight: cellH + root.gridGap
                model: root.filtered
                visible: root.filtered.length > 0

                delegate: PickerTile {
                    width: grid.cellW
                    height: grid.cellH
                    active: Wallpaper.current === modelData.path
                    cursor: root.cursorIdx === index
                    onPicked: path => root.pick(index)
                    onHoveredIndex: i => root.cursorIdx = i
                }
            }

            // scroll indicator — sibling overlay, never scrolls with content
            YScroll {
                target: grid
                x: grid.x + grid.width + 3
                y: grid.y
                width: 3
                height: grid.height
            }

            Text {
                anchors.centerIn: grid
                visible: root.filtered.length === 0
                text: Wallpaper.entries.length === 0 ? "index empty — add images to ~/Pictures/Wallpapers" : "no match for \"" + root.query + "\""
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLabel
                font.letterSpacing: 1
            }

            // ===== FOOTER =====
            Rectangle {
                id: footer

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Theme.footH + 8
                color: Theme.bg

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: Theme.hairline
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: root.pad
                    anchors.right: actionsRow.left
                    anchors.rightMargin: Theme.sp2
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideMiddle
                    text: Wallpaper.current.length > 0 ? "CURRENT " + Wallpaper.current.replace(root.homePrefix, "~") : "NO WALLPAPER SET"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 0.5
                }

                Row {
                    id: actionsRow

                    anchors.right: parent.right
                    anchors.rightMargin: root.pad
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp2

                    Rectangle {
                        visible: Wallpaper.generating
                        anchors.verticalCenter: parent.verticalCenter
                        width: applyingLabel.width + 18
                        height: 24
                        color: Theme.bgAlt
                        border.width: 1
                        border.color: Theme.acid

                        Row {
                            anchors.centerIn: parent
                            spacing: 6

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 6
                                height: 6
                                color: Theme.acid
                                opacity: root.blinkOn ? 1 : 0.25
                            }

                            Text {
                                id: applyingLabel

                                anchors.verticalCenter: parent.verticalCenter
                                text: "MATUGEN.APPLYING"
                                color: Theme.acid
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }
                        }
                    }

                    YButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 78
                        label: "random"
                        onClicked: Wallpaper.applyRandom()
                    }

                    YButton {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 78
                        label: "rescan"
                        onClicked: Wallpaper.rescan()
                    }
                }
            }
        }
    }

    Connections {
        target: ShellState

        function onPickerOpenChanged() {
            if (!ShellState.pickerOpen) {
                hideDelay.restart();
                return;
            }
            queryInput.text = "";
            root.syncCursorToCurrent();
            queryInput.forceActiveFocus();
        }
    }

    Connections {
        target: Wallpaper

        function onEntriesChanged() {
            if (ShellState.pickerOpen)
                root.syncCursorToCurrent();
        }
    }
}
