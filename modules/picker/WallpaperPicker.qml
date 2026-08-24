import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"

// Wallpaper picker v3 — the ARCHIVE.
//
// One strong idea: a numbered index spine on the left (pure mono type, no
// thumbnails to decode — the archive IS the aesthetic) and a huge framed
// stage on the right showing exactly one wallpaper at full quality. The
// search field is always focused and drives everything: type to filter,
// arrows to walk the index, enter to apply. Drops from behind the bar via
// YSurface, flush socket + flare shoulders.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    readonly property bool open: ShellState.pickerOpen
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
    // full window accepts input while open; the click-catcher closes on any
    // press outside the card (the card's own swallow area eats in-card clicks)
    mask: Region {
        item: root.open ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // card geometry — a step larger than the launcher, still just a rectangle
    readonly property int cardW: Math.min(1000, Math.round(contentRoot.width * 0.55))
    readonly property int cardH: Math.min(600, contentRoot.height - Theme.barHeight - 40)

    readonly property int spineW: 300
    readonly property int padX: Theme.sp4

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    onOpenChanged: if (!root.open)
        hideDelay.restart()

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: root.open

        Keys.onEscapePressed: ShellState.closePicker()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closePicker()
        }

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
            uiLoader.item.surface.resetForOpen();
    }


    Component {
        id: cardComponent

        // filler absorbs the Loader's stretch so YSurface keeps card geometry
        Item {
            id: filler

            anchors.fill: parent

            readonly property alias surface: card

            YSurface {

            spawnId: "picker"
                id: card


            open: root.open
            anchorX: "center"
            cardW: root.cardW
            cardH: root.cardH

            function resetForOpen() {
                filterField.text = "";
                syncToCurrent();
                filterField.forceFocus();
            }

            // ---- selection over the filtered archive ----
            property int selIdx: 0

            readonly property string query: filterField.text.trim().toLowerCase()
            readonly property var rows: {
                const all = Wallpaper.entries;
                if (query.length === 0)
                    return all;
                return all.filter(e => e.label.toLowerCase().includes(query) || e.path.toLowerCase().includes(query));
            }
            readonly property var selRow: rows[Math.max(0, Math.min(selIdx, rows.length - 1))] ?? null

            function clampSel() {
                selIdx = Math.max(0, Math.min(selIdx, rows.length - 1));
            }

            function moveSel(d) {
                const n = rows.length;
                if (n === 0)
                    return;
                selIdx = ((selIdx + d) % n + n) % n;
            }

            function selectCurrent() {
                const i = rows.findIndex(e => e.path === Wallpaper.current);
                selIdx = i >= 0 ? i : 0;
            }

            function syncToCurrent() {
                clampSel();
                selectCurrent();
            }

            function applySel() {
                if (!selRow || Wallpaper.generating)
                    return;
                Wallpaper.apply(selRow.path);
            }

            Connections {
                target: Wallpaper

                function onEntriesChanged() {
                    card.syncToCurrent();
                }
            }

            Component.onCompleted: if (root.open)
                resetForOpen()

            // ===== HEADER =====
            Item {
                id: header

                x: 0
                y: 0
                width: parent.width
                height: Theme.headH

                Rectangle {
                    id: logo

                    x: root.padX
                    anchors.verticalCenter: parent.verticalCenter
                    width: 26
                    height: 26
                    color: Theme.acid

                    Text {
                        anchors.centerIn: parent
                        text: "W"
                        color: Theme.bg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsTitle
                        font.weight: Font.ExtraBold
                    }
                }

                Text {
                    id: wordmark

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: logo.right
                    anchors.leftMargin: Theme.sp2
                    text: "WALLPAPER.ARCHIVE"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: wordmark.right
                    anchors.leftMargin: Theme.sp2
                    width: 1
                    height: 14
                    color: Theme.lineStrong
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: wordmark.right
                    anchors.leftMargin: Theme.sp3
                    text: Theme.jpEnabled ? "壁紙 // アーカイブ" : "INDEX"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 2
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: closeBtn.left
                    anchors.rightMargin: Theme.sp2
                    text: String(card.rows.length).padStart(3, "0") + " / " + String(Wallpaper.entries.length).padStart(3, "0")
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.weight: Font.Bold
                }

                YButton {
                    id: closeBtn

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.padX - 6
                    width: 30
                    label: "×"
                    onClicked: ShellState.closePicker()
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                y: header.height
                height: 1
                color: Theme.hairline
            }

            // ===== BODY =====
            Item {
                id: body

                y: header.height + 1
                x: 0
                width: parent.width
                height: parent.height - header.height - 1 - Theme.footH

                // ---------- SPINE ----------
                Item {
                    id: spine

                    x: 0
                    y: 0
                    width: root.spineW
                    height: parent.height

                    YField {
                        id: filterField

                        x: Theme.sp3
                        y: Theme.sp3
                        width: parent.width - Theme.sp3 * 2
                        placeholder: Theme.jpEnabled ? "検索 // FILTER" : "FILTER THE ARCHIVE…"
                        navKeys: true

                        onAccepted: card.applySel()
                        onNavUp: card.moveSel(-1)
                        onNavDown: card.moveSel(1)
                        onNavLeft: card.moveSel(-1)
                        onNavRight: card.moveSel(1)
                        onNavEscape: ShellState.closePicker()
                    }

                    ListView {
                        id: spineList

                        x: 0
                        y: filterField.y + filterField.height + Theme.sp2
                        width: parent.width
                        height: parent.height - y - 46 - Theme.sp2
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickDeceleration: 4000
                        maximumFlickVelocity: 4200
                        spacing: 0
                        model: card.rows
                        currentIndex: card.selIdx
                        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                        FastWheel {
                        }

                        delegate: Item {
                            id: spineRow

                            required property var modelData
                            required property int index

                            readonly property bool sel: index === card.selIdx
                            readonly property bool current: modelData.path === Wallpaper.current

                            width: spineList.width
                            height: 34

                            Rectangle {
                                anchors.fill: parent
                                color: spineRow.sel ? Theme.surface : spineArea.containsMouse ? Theme.bg : "transparent"

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 2
                                    color: spineRow.sel ? Theme.acid : "transparent"
                                }
                            }

                            Text {
                                x: Theme.sp3
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(spineRow.index + 1).padStart(3, "0")
                                color: spineRow.sel ? Theme.acid : Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                                font.weight: Font.Bold
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 52
                                anchors.right: parent.right
                                anchors.rightMargin: currentDot.visible ? 16 : Theme.sp3
                                text: spineRow.modelData.label
                                color: spineRow.sel ? Theme.ink : spineArea.containsMouse ? Theme.ink : Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                                elide: Text.ElideMiddle
                            }

                            Rectangle {
                                id: currentDot

                                visible: spineRow.current
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.sp3
                                anchors.verticalCenter: parent.verticalCenter
                                width: 5
                                height: 5
                                color: Theme.acid
                            }

                            MouseArea {
                                id: spineArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor

                                onClicked: {
                                    card.selIdx = spineRow.index;
                                    filterField.forceFocus();
                                }
                                onDoubleClicked: card.applySel()
                            }
                        }
                    }

                    YScroll {
                        target: spineList
                        anchors.top: spineList.top
                        anchors.bottom: spineList.bottom
                        anchors.right: spine.right
                        width: 3
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 1
                        color: Theme.hairline
                    }

                    Row {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.sp2
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Theme.sp2

                        YButton {
                            width: 96
                            label: "random"
                            onClicked: {
                                Wallpaper.applyRandom();
                                card.selectCurrent();
                            }
                        }

                        YButton {
                            width: 88
                            label: "rescan"
                            onClicked: Wallpaper.rescan()
                        }
                    }
                }

                // divider
                Rectangle {
                    x: root.spineW
                    y: 0
                    width: 1
                    height: parent.height
                    color: Theme.hairline
                }

                // ---------- STAGE ----------
                Item {
                    id: stage

                    x: root.spineW + 1
                    y: 0
                    width: parent.width - root.spineW - 1
                    height: parent.height

                    readonly property int pad: Theme.sp4
                    readonly property real frameW: width - pad * 2
                    readonly property real frameH: height - pad * 2 - 34 - 44 - Theme.sp2 * 2

                    Rectangle {
                        id: frame

                        x: stage.pad
                        y: stage.pad
                        width: stage.frameW
                        height: stage.frameH
                        color: Theme.bg
                        border.width: 1
                        border.color: Theme.lineStrong

                        Image {
                            id: previewImg

                            anchors.fill: parent
                            anchors.margins: 6
                            source: card.selRow && root.open && frame.width > 50 ? "file://" + card.selRow.path : ""
                            sourceSize.width: Math.min(1024, Math.round(frame.width))
                            sourceSize.height: Math.min(640, Math.round(frame.height))
                            fillMode: Image.PreserveAspectFit
                            asynchronous: true
                            cache: false
                        }

                        // registration cross behind an empty preview
                        Column {
                            anchors.centerIn: parent
                            spacing: Theme.sp2
                            visible: previewImg.status !== Image.Ready

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "+"
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsDisplay
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                visible: card.rows.length === 0
                                // a filter with zero hits is not the same as an empty archive
                                text: Wallpaper.scanning ? "SCANNING…" : card.rows.length === 0 && card.query.length > 0 ? "NO MATCH" : "ARCHIVE EMPTY"
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                                font.letterSpacing: 2
                            }
                        }

                        // corner ticks — family mark, four of them
                        Rectangle {
                            x: -1
                            y: -1
                            width: 10
                            height: 2
                            color: Theme.acid
                        }

                        Rectangle {
                            x: -1
                            y: -1
                            width: 2
                            height: 10
                            color: Theme.acid
                        }

                        Rectangle {
                            anchors.right: parent.right
                            y: -1
                            width: 10
                            height: 2
                            color: Theme.acid
                        }

                        Rectangle {
                            anchors.right: parent.right
                            y: -1
                            width: 2
                            height: 10
                            color: Theme.acid
                        }
                    }

                    // caption strip
                    Item {
                        id: caption

                        x: stage.pad
                        y: frame.y + frame.height + Theme.sp2
                        width: stage.frameW
                        height: 34

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - applyChip.width - Theme.sp2 * 2
                            text: card.selRow ? card.selRow.label : "—"
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBody
                            font.weight: Font.Bold
                            elide: Text.ElideMiddle
                        }

                        Row {
                            id: applyChip

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.sp2

                            YChip {
                                visible: Wallpaper.generating
                                label: Theme.jpEnabled ? "生成中…" : "MATUGEN.APPLYING"
                                tone: "acid"
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: card.rows.length > 0 ? String(card.selIdx + 1).padStart(3, "0") + "/" + String(card.rows.length).padStart(3, "0") : "000/000"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                                font.weight: Font.Bold
                            }
                        }
                    }

                    // action row
                    Row {
                        x: stage.pad
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.sp3
                        spacing: Theme.sp2

                        YButton {
                            width: 150
                            tone: "acid"
                            label: Wallpaper.generating ? "applying…" : "apply"
                            onClicked: card.applySel()
                        }

                        YButton {
                            width: 40
                            label: "←"
                            onClicked: card.moveSel(-1)
                        }

                        YButton {
                            width: 40
                            label: "→"
                            onClicked: card.moveSel(1)
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: Theme.sp2
                            text: "↵ APPLY · DOUBLE-CLICK INDEX ROW · TYPE TO FILTER"
                            color: Theme.faint
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                            font.letterSpacing: 1
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
                height: Theme.footH
                color: Theme.bg

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
                    anchors.leftMargin: root.padX
                    width: parent.width * 0.55
                    text: Wallpaper.current.length > 0 ? Wallpaper.current : "no wallpaper set"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    elide: Text.ElideMiddle
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: root.padX
                    text: "ESC CLOSE"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 1.5
                }
            }
        }
        }
    }
}
