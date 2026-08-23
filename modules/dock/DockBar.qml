import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui
import "."

// DockBar — per-screen bottom dock (PH.09). Spawned by shell.qml through
// Variants so each monitor gets its own; each instance only shows windows
// living on ITS screen. Master switch, hide mode, layer mode and pins all
// come from ShellState/Dock.
//
// The window spans the full screen width and centers the dock body inside it;
// input is confined to the dock strip via `mask`, so clicks pass through
// everywhere else in overlay mode. In exclusive mode the bottom strip is
// reserved like a bar.
PanelWindow {
    id: root

    screen: modelData

    WlrLayershell.layer: WlrLayer.Top
    anchors.left: true
    anchors.right: true
    anchors.bottom: true
    exclusionMode: ShellState.dockMode === "exclusive" ? ExclusionMode.Normal : ExclusionMode.Ignore

    color: "transparent"
    mask: Region {
        item: inputZone
    }

    visible: ShellState.dockEnabled && root.scopeVisible && !root.dodgeHidden

    // monitor scope: "all" spawns everywhere, "primary" only on the first screen
    readonly property bool scopeVisible: ShellState.dockMonitors === "all" || (Quickshell.screens.length > 0 && root.screen.name === Quickshell.screens[0].name)

    // ---- hide logic ------------------------------------------------------
    // dodge: hide while a fullscreen window owns a workspace on this monitor
    readonly property bool dodgeHidden: ShellState.dockHide === "dodge" && root.fullscreenHere
    readonly property bool fullscreenHere: {
        const ws = Hyprland.workspaces.values;
        for (let i = 0; i < ws.length; i++) {
            if (ws[i].monitor && ws[i].monitor.name === root.screen.name && ws[i].hasFullscreen)
                return true;
        }
        return false;
    }

    // auto-hide ("always"): the body slides off-screen; a thin strip stays
    // behind at the bottom edge to catch the reveal hover
    readonly property bool autoHide: ShellState.dockHide === "always"
    property bool hovered: false

    readonly property int dockH: 56

    implicitHeight: root.dockH

    // full-width input region at the bottom edge (dock strip)
    Item {
        id: inputZone

        width: parent.width
        height: parent.height
        anchors.bottom: parent.bottom
    }

    // reveal strip for auto-hide — always live so hover can bring it back
    Item {
        width: parent.width
        height: 6
        y: parent.height - height
        visible: root.autoHide

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.hovered = true
            onExited: root.hovered = false
        }
    }

    // ---- the dock body ---------------------------------------------------
    Rectangle {
        id: frame

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.autoHide && !root.hovered ? root.dockH + 10 : 0
        width: Math.min(row.width + Theme.sp2 * 2, parent.width - Theme.outerPad * 2)
        height: root.dockH - 4
        color: Theme.bg
        border.width: 1
        border.color: Theme.lineStrong

        Behavior on y {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.hairline
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 2
            color: Theme.acid
            opacity: 0.85
        }

        Row {
            id: row

            x: Theme.sp2
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.sp1

            Repeater {
                model: Dock.apps

                DockItem {}
            }
        }

        // context menu — floats above the dock
        Rectangle {
            id: menu

            width: menuRow.width + Theme.sp2 * 2
            height: menuRow.height + Theme.sp2 * 2
            x: Math.max(0, Math.min(menuAnchorX, frame.width - width))
            y: -height - Theme.sp2
            visible: root.menuApp !== ""
            color: Theme.bgAlt
            border.width: 1
            border.color: Theme.lineStrong

            property real menuAnchorX: 0

            Row {
                id: menuRow

                x: Theme.sp2
                y: Theme.sp2
                spacing: Theme.sp1

                YButton {
                    label: Dock.isPinned(root.menuApp) ? "UNPIN" : "PIN"
                    onClicked: {
                        if (Dock.isPinned(root.menuApp))
                            Dock.unpin(root.menuApp);
                        else
                            Dock.pin(root.menuApp);
                        root.menuApp = "";
                    }
                }

                YButton {
                    label: "LAUNCH"
                    visible: Dock.isRunning(root.menuApp)
                    onClicked: {
                        Dock.launch(root.menuApp);
                        root.menuApp = "";
                    }
                }

                YButton {
                    label: "CLOSE"
                    tone: "danger"
                    visible: Dock.isRunning(root.menuApp)
                    onClicked: {
                        Dock.closeAll(root.menuApp);
                        root.menuApp = "";
                    }
                }
            }
        }
    }

    property string menuApp: ""

    // ---- one dock item ---------------------------------------------------
    component DockItem: Rectangle {
        id: item

        required property var modelData

        readonly property string appId: modelData.id
        readonly property string iconUrl: modelData.iconSrc === "" ? "" : Quickshell.iconPath(modelData.iconSrc)
        readonly property bool active: Dock.isActive(appId)
        readonly property bool running: modelData.running
        readonly property bool pinned: modelData.pinned

        width: 52
        height: 46
        color: hover.containsMouse ? Theme.surface : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Theme.movFast
            }
        }

        // running dot / active tick along the bottom
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            anchors.horizontalCenter: parent.horizontalCenter
            width: item.active ? 22 : 4
            height: 2
            color: item.active ? Theme.acid : (item.running ? Theme.muted : "transparent")

            Behavior on width {
                NumberAnimation {
                    duration: Theme.movFast
                    easing.type: Easing.OutCubic
                }
            }
        }

        // icon fallback (acid square + initial)
        Rectangle {
            anchors.centerIn: parent
            width: 36
            height: 36
            color: Theme.acid
            visible: item.iconUrl === "" || icon.status === Image.Error || icon.status === Image.Null

            Text {
                anchors.centerIn: parent
                text: item.modelData.name.charAt(0).toUpperCase()
                color: Theme.bg
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsTitle
                font.weight: Font.ExtraBold
            }
        }

        IconImage {
            id: icon

            anchors.centerIn: parent
            implicitSize: 36
            source: item.iconUrl
            asynchronous: true
            visible: item.iconUrl !== "" && icon.status !== Image.Error && icon.status !== Image.Null
        }

        // hover title card
        Rectangle {
            anchors.bottom: parent.top
            anchors.bottomMargin: Theme.sp2
            anchors.horizontalCenter: parent.horizontalCenter
            width: titleText.width + Theme.sp2 * 2
            height: 24
            visible: hover.containsMouse && root.menuApp === ""
            color: Theme.bgAlt
            border.width: 1
            border.color: Theme.lineStrong

            Text {
                id: titleText

                anchors.centerIn: parent
                text: item.modelData.name
                color: Theme.ink
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsLabel
                font.letterSpacing: 1
            }
        }

        MouseArea {
            id: hover

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: mouse => {
                if (mouse.button === Qt.LeftButton)
                    Dock.click(item.appId);
                else if (mouse.button === Qt.MiddleButton)
                    Dock.newInstance(item.appId);
                else if (mouse.button === Qt.RightButton) {
                    root.menuApp = item.appId;
                    root.menu.menuAnchorX = item.x + item.width / 2;
                }
            }

            onWheel: wheel => Dock.cycle(item.appId, wheel.angleDelta.y)
        }
    }
}
