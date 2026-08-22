import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import QtQuick
import qs.theme

Item {
    id: root

    implicitWidth: trayRow.width
    implicitHeight: Theme.barHeight

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
                }

                IconImage {
                    id: iconImg
                    anchors.centerIn: parent
                    implicitSize: 15
                    source: cell.modelData.icon
                    opacity: area.containsMouse ? 1 : 0.85
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
                        if (mouse.button === Qt.MiddleButton) {
                            sni.secondaryActivate();
                            return;
                        }
                        if (!sni.hasMenu) {
                            sni.activate();
                            return;
                        }
                        const pos = iconImg.mapToItem(null, iconImg.width / 2, iconImg.height / 2);
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
