import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import qs.theme
import qs.modules.common

Item {
    id: root

    implicitWidth: trayRow.width
    implicitHeight: Theme.scaledBarHeight

    property var tip

    readonly property var items: SystemTray.items.values

    Row {
        id: trayRow
        anchors.centerIn: parent
        spacing: 3

        Repeater {
            model: root.items

            delegate: Item {
                id: cell
                required property var modelData

                width: 24
                height: 26

                Rectangle {
                    anchors.fill: parent
                    color: area.containsMouse ? Theme.surface : "transparent"
                    border.width: area.containsMouse ? 1 : 0
                    border.color: Theme.lineStrong

                    Behavior on color {
                        ColorAnimation { duration: Theme.movFast }
                    }

                    Behavior on border.width {
                        NumberAnimation { duration: Theme.movSnap }
                    }
                }

                // icon fallback: acid square + initial, same language as the taskbar
                Rectangle {
                    anchors.centerIn: parent
                    width: 16
                    height: 16
                    color: Theme.acid
                    visible: iconImg.status === Image.Error || iconImg.status === Image.Null

                    Text {
                        anchors.centerIn: parent
                        text: ((cell.modelData.title || cell.modelData.id) + " ").charAt(0).toUpperCase()
                        color: Theme.bg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.barFsMicro
                        font.weight: Font.ExtraBold
                    }
                }

                IconImage {
                    id: iconImg
                    anchors.centerIn: parent
                    implicitSize: 15
                    source: (cell.modelData.icon && cell.modelData.icon.length > 0) ? ShellState.safeIcon(cell.modelData.icon) : ""
                    opacity: area.containsMouse ? 1 : 0.85
                    scale: area.containsMouse ? 1.12 : 1.0
                    visible: source.length > 0 && status !== Image.Error && status !== Image.Null

                    Behavior on opacity {
                        NumberAnimation { duration: Theme.movFast }
                    }

                    Behavior on scale {
                        NumberAnimation { duration: 150; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                    }
                }

                HoverHandler {
                    id: hover
                    onHoveredChanged: {
                        if (!root.tip)
                            return;
                        if (hover.hovered)
                            root.tip.showFor(cell, cell.modelData.title || cell.modelData.id);
                        else
                            root.tip.hide();
                    }
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                    onClicked: mouse => {
                        const sni = cell.modelData;
                        const pos = iconImg.mapToItem(null, iconImg.width / 2, iconImg.height / 2);
                        // right-click always shows the context menu
                        if (mouse.button === Qt.RightButton) {
                            if (sni.hasMenu)
                                sni.display(cell.QsWindow.window, pos.x - 12, pos.y + 16);
                            else
                                sni.activate();
                            return;
                        }
                        if (mouse.button === Qt.MiddleButton) {
                            sni.secondaryActivate();
                            return;
                        }
                        if (!sni.hasMenu) {
                            sni.activate();
                            return;
                        }
                        sni.display(cell.QsWindow.window, pos.x - 12, pos.y + 16);
                    }

                    onWheel: wheel => {
                        cell.modelData.scroll(wheel.angleDelta.y > 0 ? 1 : -1, false);
                    }
                }
            }
        }
    }
}
