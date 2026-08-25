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
    // the window carries ~96px of headroom above the dock so the context menu
    // and hover cards render INSIDE it; in exclusive mode reserve only the
    // dock strip itself, not the headroom
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.exclusiveZone: ShellState.dockMode === "exclusive" ? root.dockH : -1

    color: "transparent"
    mask: Region {
        // clicks land on the dock strip; while the context menu is open the
        // whole window accepts input so its buttons work, elsewhere it closes
        item: root.menuApp !== "" ? fullZone : inputZone
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

    // dock strip + enough headroom for the context menu and hover cards
    readonly property int headroom: 96
    implicitHeight: root.dockH + root.headroom

    // normally only the bottom strip takes input
    Item {
        id: inputZone

        width: parent.width
        height: root.dockH
        anchors.bottom: parent.bottom
    }

    // whole-window catcher while the context menu is open
    Item {
        id: fullZone

        anchors.fill: parent

        MouseArea {
            anchors.fill: parent
            onClicked: root.menuApp = ""
        }
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
        y: root.autoHide && !root.hovered ? parent.height + 10 : parent.height - root.dockH
        width: Math.min(row.width + Theme.sp2 * 2, parent.width - Theme.outerPad * 2)
        height: root.dockH - 4
        // many pinned+running apps can outgrow the clamped frame — cut them
        // at the border instead of painting onto the bare backdrop
        clip: true
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

        // acid glow along dock bottom edge — breathing ambient
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 8
            color: Theme.acid
            opacity: 0.06
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
            opacity: root.menuApp !== "" ? 1 : 0
            scale: root.menuApp !== "" ? 1 : 0.92
            transformOrigin: Item.Bottom

            Behavior on opacity {
                NumberAnimation { duration: Theme.movFast; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: Theme.movFast; easing.type: Easing.OutBack; easing.overshoot: 0.25 }
            }

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
        scale: hover.containsMouse ? 1.08 : 1

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

        // running dot / active tick along the bottom
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 3
            anchors.horizontalCenter: parent.horizontalCenter
            width: item.active ? 22 : 4
            height: 2
            color: item.active ? Theme.acid : (item.running ? Theme.muted : "transparent")
            scale: item.running ? 1.1 : 1

            Behavior on width {
                NumberAnimation {
                    duration: Theme.movFast
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.movFast
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.3
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
            opacity: hover.containsMouse ? 1 : 0.88

            Behavior on opacity {
                NumberAnimation { duration: Theme.movFast; easing.type: Easing.OutCubic }
            }
        }

        // hover title card
        Rectangle {
            id: hoverCard

            anchors.bottom: parent.top
            anchors.bottomMargin: Theme.sp2
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(titleText.implicitWidth + Theme.sp2 * 2, 180)
            height: 24
            visible: hover.containsMouse && root.menuApp === ""
            color: Theme.bgAlt
            border.width: 1
            border.color: Theme.lineStrong
            opacity: hover.containsMouse ? 1 : 0
            scale: hover.containsMouse ? 1 : 0.92

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.movFast
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Theme.movSnap
                    easing.type: Easing.OutBack
                    easing.overshoot: 0.3
                }
            }

            Text {
                id: titleText

                anchors.centerIn: parent
                width: Math.min(implicitWidth, parent.width - Theme.sp2)
                elide: Text.ElideRight
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
                if (mouse.button === Qt.LeftButton) {
                    launchBounce.start();
                    Dock.click(item.appId);
                } else if (mouse.button === Qt.MiddleButton)
                    Dock.newInstance(item.appId);
                else if (mouse.button === Qt.RightButton) {
                    root.menuApp = item.appId;
                    root.menu.menuAnchorX = item.x + row.x + item.width / 2;
                }
            }

            onWheel: wheel => Dock.cycle(item.appId, wheel.angleDelta.y)
        }

        SequentialAnimation {
            id: launchBounce
            running: false

            NumberAnimation {
                target: item
                property: "scale"
                to: 1.25
                duration: Theme.movSnap
                easing.type: Easing.OutBack
                easing.overshoot: 0.5
            }
            NumberAnimation {
                target: item
                property: "scale"
                to: 1.0
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }
    }
}
