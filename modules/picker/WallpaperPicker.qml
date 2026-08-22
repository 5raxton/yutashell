import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "ui"

// WALLPAPER.DECK — default view is a Hearthstone-style carousel: one large
// hero tile flanked by dimmed, scaled-down neighbors you flip through with
// wheel/arrows/drag; clicking the hero applies it (awww paint -> matugen ->
// templates -> live recolor). A contact-sheet GRID mode remains available;
// the choice persists. Both modes live on the same drop-from-the-bar card.
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
    // input lands ONLY on the card — desktop around it stays live
    mask: Region {
        item: ShellState.pickerOpen ? sheet : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.pickerOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property bool carousel: ShellState.pickerMode !== "grid"
    readonly property int pad: Theme.sp4
    readonly property int cardW: Math.max(760, Math.min(1040, contentRoot.width - Theme.outerPad * 4))
    readonly property int cardH: Math.min(680, contentRoot.height - Theme.barHeight - Theme.outerPad * 2 - 24)
    // hero geometry (carousel)
    readonly property int heroW: Math.min(600, cardW - Theme.sp5 * 3)
    readonly property int heroImgH: Math.round(heroW * 0.58)
    // sheet geometry (grid mode)
    readonly property int gridGap: Theme.sp2
    readonly property int cols: Math.max(3, Math.floor((cardW - pad * 2 - Theme.sp2) / 200))
    readonly property string homePrefix: Quickshell.env("HOME")

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
    }

    function moveCursor(delta) {
        if (filtered.length === 0)
            return;
        cursorIdx = Math.max(0, Math.min(filtered.length - 1, cursorIdx + delta));
    }

    function pick(idx) {
        if (idx < 0 || idx >= filtered.length)
            return;
        Wallpaper.apply(filtered[idx].path);
    }

    Timer {
        id: hideDelay

        interval: Theme.movMed
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

        Keys.onEscapePressed: {
            if (root.query.length > 0)
                root.query = "";
            else
                ShellState.closePicker();
        }

        YSurface {
            id: sheet

            open: ShellState.pickerOpen
            anchorX: "center"
            cardW: root.cardW
            cardH: root.cardH

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
                    text: "WALLPAPER.DECK"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
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
                    anchors.right: modeRow.left
                    anchors.rightMargin: Theme.sp3
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp1

                    YChip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: Wallpaper.scanning ? "scanning…" : (root.carousel ? (root.filtered.length > 0 ? (root.cursorIdx + 1) + " / " + root.filtered.length : "0 imgs") : root.filtered.length + " imgs")
                    }
                }

                Row {
                    id: modeRow

                    anchors.right: closeBtn.left
                    anchors.rightMargin: Theme.sp2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.sp1

                    YButton {
                        width: 84
                        label: "deck"
                        tone: root.carousel ? "acid" : "default"
                        onClicked: ShellState.set("pickerMode", "carousel")
                    }

                    YButton {
                        width: 84
                        label: "sheet"
                        tone: root.carousel ? "default" : "acid"
                        onClicked: ShellState.set("pickerMode", "grid")
                    }
                }

                YButton {
                    id: closeBtn

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 30
                    label: "×"
                    onClicked: ShellState.closePicker()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                y: Theme.headH
                height: 1
                color: Theme.hairline
            }

            // ===== DECK (carousel) =====
            ListView {
                id: deck

                readonly property int cellW: root.heroW + Theme.sp4

                anchors.top: parent.top
                anchors.topMargin: Theme.headH + Theme.sp4
                anchors.bottom: footer.top
                anchors.left: parent.left
                anchors.right: parent.right
                visible: root.carousel
                clip: false
                orientation: ListView.Horizontal
                spacing: 0
                model: root.filtered
                currentIndex: root.cursorIdx
                onCurrentIndexChanged: if (root.cursorIdx !== currentIndex)
                    root.cursorIdx = currentIndex
                preferredHighlightBegin: (width - cellW) / 2
                preferredHighlightEnd: preferredHighlightBegin + cellW
                highlightRangeMode: ListView.StrictlyEnforceRange
                snapMode: ListView.SnapToItem
                cacheBuffer: width
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 6000

                WheelHandler {
                    acceptedModifiers: Qt.NoModifier
                    activeTimeout: 0.3

                    onWheel: event => {
                        const d = Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x) ? event.angleDelta.y : -event.angleDelta.x;
                        if (d === 0)
                            return;
                        root.moveCursor(d > 0 ? -1 : 1);
                        event.accepted = true;
                    }
                }

                delegate: Item {
                    id: hero

                    required property var modelData
                    required property int index

                    readonly property bool isCur: ListView.isCurrentItem

                    width: deck.cellW
                    height: deck.height

                    scale: isCur ? 1 : 0.84
                    opacity: isCur ? 1 : 0.42

                    Behavior on scale {
                        NumberAnimation {
                            duration: Theme.movMed
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Theme.movMed
                            easing.type: Easing.OutCubic
                        }
                    }

                    Rectangle {
                        id: heroCard

                        x: (parent.width - root.heroW) / 2
                        y: (parent.height - height) / 2
                        width: root.heroW
                        height: root.heroImgH + 34
                        color: Theme.bg
                        border.width: 1
                        border.color: hero.isCur ? Theme.acid : Theme.hairline

                        Image {
                            anchors.fill: parent
                            anchors.margins: 2
                            anchors.bottomMargin: 34
                            source: hero.visible && ShellState.pickerOpen ? "file://" + hero.modelData.path : ""
                            sourceSize.width: hero.isCur ? 640 : 256
                            sourceSize.height: hero.isCur ? 400 : 160
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                        }

                        // label strip
                        Rectangle {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            height: 32
                            color: Theme.bgAlt

                            Rectangle {
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: 1
                                color: Theme.hairline
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.sp2
                                anchors.right: idxLabel.left
                                anchors.rightMargin: Theme.sp2
                                text: hero.modelData.label
                                color: hero.isCur ? Theme.ink : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                                font.letterSpacing: 0.5
                                elide: Text.ElideMiddle
                            }

                            Text {
                                id: idxLabel

                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.sp2
                                text: String(hero.index + 1).padStart(3, "0")
                                color: hero.isCur ? Theme.acid : Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.weight: Font.Bold
                            }
                        }

                        // current-tick motif
                        Rectangle {
                            visible: hero.isCur
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: 2
                            width: 9
                            height: 9
                            color: Theme.acid
                        }
                    }

                    MouseArea {
                        anchors.fill: parent

                        onClicked: {
                            if (!hero.isCur) {
                                root.cursorIdx = hero.index;
                                return;
                            }
                            root.pick(hero.index);
                        }
                    }
                }
            }

            Text {
                anchors.centerIn: deck
                visible: root.carousel && root.filtered.length === 0
                text: Wallpaper.entries.length === 0 ? "index empty — add images to ~/Pictures/Wallpapers" : "no match for \"" + root.query + "\""
                color: Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLabel
                font.letterSpacing: 1
            }

            // ===== SEARCH ROW (sheet mode) =====
            Item {
                id: searchRow

                x: root.pad
                y: Theme.headH + Theme.sp3
                width: parent.width - root.pad * 2 - 1
                height: root.carousel ? 0 : Theme.ctlH
                visible: !root.carousel

                Rectangle {
                    id: searchBox

                    anchors.fill: parent
                    color: Theme.bg
                    border.width: 1
                    border.color: queryInput.activeFocus || root.query.length > 0 ? Theme.lineStrong : Theme.hairline

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 2
                        color: queryInput.activeFocus ? Theme.acid : "transparent"
                    }

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

            // hidden capture input: owns ALL key handling while open
            TextInput {
                id: queryInput

                visible: false
                activeFocusOnPress: false
                color: Theme.ink
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
                    } else if (event.key === Qt.Key_Up && !root.carousel) {
                        root.moveCursor(-root.cols);
                        event.accepted = true;
                    } else if (event.key === Qt.Key_Down && !root.carousel) {
                        root.moveCursor(root.cols);
                        event.accepted = true;
                    }
                }
            }

            // ===== GRID (contact sheet) =====
            GridView {
                id: grid

                readonly property int cellW: Math.floor((width - (root.cols - 1) * root.gridGap) / root.cols)
                readonly property int cellH: Math.round(cellW * 0.62)

                x: root.pad
                y: searchRow.y + searchRow.height + Theme.sp3
                width: parent.width - root.pad * 2 - 1
                height: parent.height - y - Theme.footH - Theme.sp3
                clip: true
                visible: !root.carousel && root.filtered.length > 0
                boundsBehavior: Flickable.StopAtBounds
                flickDeceleration: 4000
                cellWidth: cellW + root.gridGap
                cellHeight: cellH + root.gridGap
                model: root.filtered

                FastWheel {
                }

                delegate: PickerTile {
                    width: grid.cellW
                    height: grid.cellH
                    active: Wallpaper.current === modelData.path
                    cursor: root.cursorIdx === index
                    onPicked: path => root.pick(index)
                    onHoveredIndex: i => root.cursorIdx = i
                }
            }

            YScroll {
                target: grid
                x: grid.x + grid.width + 3
                y: grid.y
                width: 3
                height: grid.height
                visible: grid.visible
            }

            Text {
                anchors.centerIn: grid
                visible: !root.carousel && root.filtered.length === 0
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

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !Wallpaper.generating
                        text: root.carousel ? "wheel/←→ flip · click hero applies" : "type to filter · enter applies"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        font.letterSpacing: 0.8
                    }

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
