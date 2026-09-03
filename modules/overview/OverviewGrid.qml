import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui
import "."

// OverviewGrid — fullscreen workspace map (PH.10 + PH.04.4). One tile per
// workspace: number, windows on it, click to jump. PH.04.4 adds: search
// field to filter by app name, hover-enlarge preview, click-to-move windows
// between workspaces.
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
    visible: ShellState.overviewOpen || hideDelay.running
    mask: Region {
        item: ShellState.overviewOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.overviewOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(1080, root.width - Theme.outerPad * 4)

    // PH.04.4: search filter
    property string _searchQuery: ""

    // PH.04.4: window move mode — click a workspace tile to move the selected window there
    property string _moveAddr: ""
    property string _moveTitle: ""

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    // staggered reveal counter — increments each time the grid opens,
    // delegate tiles watch it and animate in with per-index delay
    property int _revealTick: 0

    // set once the overview has been opened — the grid model gated on this so
    // the workspace cards (and their windows) don't render before first open
    property bool _everOpened: false

    Connections {
        target: ShellState

        function onOverviewOpenChanged() {
            if (ShellState.overviewOpen) {
                root._everOpened = true;
                root._revealTick++;
            } else {
                hideDelay.restart();
            }
        }
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (root._moveAddr.length > 0) {
                root._moveAddr = "";
                root._moveTitle = "";
            } else {
                Overview.closeGrid();
            }
        }

        YClickAway {
            id: clickAway

            onOutsideClicked: Overview.closeGrid()
        }

        YSurface {

            spawnId: "overview"
            id: surface

            open: ShellState.overviewOpen
            cascade: bodyCol
            anchorX: "center"
            cardW: root.cardW
            cardH: bodyCol.implicitHeight + Theme.sp4 * 2
            restGap: Theme.sp2

            Column {
                id: bodyCol

                x: Theme.sp4
                y: Theme.sp4
                width: parent.width - Theme.sp4 * 2
                spacing: Theme.sp3

                Item {
                    width: parent.width
                    height: 28

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "OVERVIEW // " + Overview.workspaces.length + " WORKSPACES"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        font.letterSpacing: 3
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "ESC"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsMicro
                        font.letterSpacing: 2
                    }
                }

                // PH.04.4: search field
                Rectangle {
                    width: parent.width
                    height: searchField.height + Theme.sp1 * 2
                    color: "transparent"
                    visible: Overview.workspaces.length > 3

                    YField {
                        id: searchField
                        anchors.fill: parent
                        anchors.margins: Theme.sp1
                        placeholder: "Filter windows..."
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

                // PH.04.4: move-window mode banner
                Rectangle {
                    width: parent.width
                    height: 28
                    color: Theme.acid
                    visible: root._moveAddr.length > 0
                    radius: Theme.radius

                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.sp2

                        Text {
                            text: "MOVE: " + root._moveTitle.toUpperCase()
                            color: Theme.bg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                            font.letterSpacing: 1
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "← CLICK WORKSPACE · ESC CANCEL"
                            color: Theme.bg
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                            font.letterSpacing: 1
                            opacity: 0.7
                        }
                    }
                }

                Flow {
                    id: grid

                    width: parent.width
                    spacing: Theme.sp2

                    Repeater {
                        model: {
                            if (!root._everOpened) return [];
                            const q = root._searchQuery.trim().toLowerCase();
                            if (q.length === 0) return Overview.workspaces;
                            // filter: keep workspaces that have matching windows
                            return Overview.workspaces.filter(ws => {
                                const wins = ws.windows || [];
                                for (let i = 0; i < wins.length; i++) {
                                    const hay = ((wins[i].name || "") + " " + (wins[i].title || "")).toLowerCase();
                                    if (hay.indexOf(q) >= 0) return true;
                                }
                                return false;
                            });
                        }

                        delegate: Rectangle {
                            id: ws

                            required property var modelData

                            readonly property bool focused: modelData.focused
                            readonly property var wins: modelData.windows || []
                            property bool entered: false
                            property bool hovered: tileArea.containsMouse

                            width: 250
                            // PH.04.4: enlarge on hover
                            height: Math.max(96, wsCol.implicitHeight + Theme.sp3 * 2) + (hovered ? 12 : 0)
                            color: tileArea.containsMouse ? Theme.surface : Theme.bgAlt
                            border.width: 1
                            border.color: focused ? Theme.acid : (tileArea.containsMouse ? Theme.lineStrong : Theme.hairline)

                            Behavior on color {
                                ColorAnimation { duration: Theme.movFast }
                            }

                            Behavior on height {
                                enabled: entered
                                NumberAnimation {
                                    duration: Theme.movSnap
                                    easing.type: Easing.OutCubic
                                }
                            }

                            opacity: entered ? 1 : 0
                            y: entered ? 0 : 16
                            scale: entered ? 1 : 0.85

                            Behavior on opacity {
                                enabled: entered
                                NumberAnimation {
                                    duration: Theme.movSlow
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on y {
                                enabled: entered
                                NumberAnimation {
                                    duration: Theme.movSlow
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on scale {
                                enabled: entered
                                NumberAnimation {
                                    duration: Theme.movSlow
                                    easing.type: Easing.OutBack
                                    easing.overshoot: 0.2
                                }
                            }

                            // staggered entrance: each tile delays by index * 40ms
                            Connections {
                                target: root

                                function on_RevealTickChanged() {
                                    entranceDelay.restart();
                                }
                            }

                            Timer {
                                id: entranceDelay

                                interval: ws.index * 40
                                onTriggered: ws.entered = true
                            }

                            Behavior on border.color {
                                ColorAnimation {
                                    duration: Theme.movFast
                                }
                            }

                            Column {
                                id: wsCol

                                anchors.fill: parent
                                anchors.margins: Theme.sp3
                                spacing: Theme.sp2

                                Item {
                                    width: parent.width
                                    height: 20

                                    Text {
                                        anchors.left: parent.left
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: String(modelData.id).padStart(2, "0")
                                        color: focused ? Theme.acid : Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsTitle
                                        font.weight: Font.DemiBold

                                        Behavior on color {
                                            ColorAnimation { duration: Theme.movFast }
                                        }
                                    }

                                    Text {
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: wins.length + (wins.length === 1 ? " WINDOW" : " WINDOWS")
                                        color: Theme.faint
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        font.letterSpacing: 1
                                    }
                                }

                                Repeater {
                                    model: ws.wins.length > 5 ? ws.wins.slice(0, 5) : ws.wins

                                    Row {
                                        width: parent.width
                                        height: 18
                                        spacing: Theme.sp2

                                        // one 16px leading slot: glyph when no icon,
                                        // icon centered inside it — title math stays constant
                                        Item {
                                            width: 16
                                            height: 16
                                            anchors.verticalCenter: parent.verticalCenter

                                            Text {
                                                anchors.centerIn: parent
                                                visible: modelData.iconSrc === ""
                                                text: "■"
                                                color: Theme.acid
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fsLabel
                                            }

                                            IconImage {
                                                anchors.centerIn: parent
                                                implicitSize: 14
                                                visible: modelData.iconSrc !== "" && status !== Image.Error && status !== Image.Null
                                                source: ShellState.safeIcon(modelData.iconSrc)
                                                asynchronous: true
                                            }
                                        }

                                        Text {
                                            width: parent.width - 16 - Theme.sp2
                                            text: modelData.title
                                            elide: Text.ElideRight
                                            color: Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsLabel
                                        }
                                    }
                                }

                                Text {
                                    visible: ws.wins.length > 5
                                    text: "+" + (ws.wins.length - 5) + " MORE"
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                    font.letterSpacing: 1
                                }
                            }

                            MouseArea {
                                id: tileArea

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    // PH.04.4: move mode — move the selected window here
                                    if (root._moveAddr.length > 0) {
                                        Overview.moveWindowToWorkspace(root._moveAddr, modelData.id);
                                        root._moveAddr = "";
                                        root._moveTitle = "";
                                        Overview.closeGrid();
                                        return;
                                    }
                                    Overview.jumpWorkspace(modelData.id);
                                }
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onReleased: mouse => {
                                    if (mouse.button === Qt.RightButton && root._moveAddr.length === 0 && ws.wins.length > 0) {
                                        // PH.04.4: right-click first window to enter move mode
                                        const w = ws.wins[0];
                                        root._moveAddr = w.address;
                                        root._moveTitle = w.name || w.title || "window";
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
