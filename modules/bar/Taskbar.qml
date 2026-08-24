import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import QtQuick
import qs.theme
import qs.modules.common
import "../dock"

// Taskbar — the bar's app dock (PH.14). Running windows merged with pinned
// apps (same model as the bottom dock: Dock.apps). Left-click launch/focus/
// minimize-cycle, middle-click new instance, scroll cycles windows, right-click
// pins/unpins. Reuses Dock's window->app logic so both surfaces stay in sync.
Item {
    id: root

    property var tip

    implicitWidth: Math.max(0, row.width)
    implicitHeight: Theme.barHeight

    readonly property int maxVisible: 10

    readonly property var apps: Dock.apps.slice(0, root.maxVisible)

    function showCol(item, text) {
        if (tip)
            tip.showFor(item, text);
    }

    function hideCol() {
        if (tip)
            tip.hide();
    }

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        // keep fallback boxes / hover chrome inside the segment's own width
        clip: true

        Repeater {
            model: root.apps

            delegate: Rectangle {
                id: item

                required property var modelData

                readonly property string appId: modelData.id
                readonly property bool active: Dock.isActive(appId)
                readonly property bool running: modelData.running
                readonly property string iconUrl: modelData.iconSrc === "" ? "" : Quickshell.iconPath(modelData.iconSrc)

                width: 30
                height: 30
                color: hover.containsMouse ? Theme.surface : "transparent"

                // active / running tick along the bottom
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: item.active ? 18 : item.running ? 4 : 0
                    height: 2
                    color: item.active ? Theme.acid : Theme.muted

                    Behavior on width {
                        NumberAnimation {
                            duration: Theme.movFast
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // acid square + initial fallback
                Rectangle {
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    color: Theme.acid
                    visible: item.iconUrl === "" || icon.status === Image.Error || icon.status === Image.Null

                    Text {
                        anchors.centerIn: parent
                        text: item.modelData.name.charAt(0).toUpperCase()
                        color: Theme.bg
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                        font.weight: Font.ExtraBold
                    }
                }

                IconImage {
                    id: icon

                    anchors.centerIn: parent
                    implicitSize: 22
                    source: item.iconUrl
                    asynchronous: true
                    visible: item.iconUrl !== "" && icon.status !== Image.Error && icon.status !== Image.Null
                }

                MouseArea {
                    id: hover

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

                    onClicked: mouse => {
                        if (mouse.button === Qt.LeftButton)
                            Dock.click(item.appId);
                        else if (mouse.button === Qt.MiddleButton)
                            Dock.newInstance(item.appId);
                        else if (mouse.button === Qt.RightButton) {
                            if (Dock.isPinned(item.appId))
                                Dock.unpin(item.appId);
                            else
                                Dock.pin(item.appId);
                        }
                    }
                    onWheel: wheel => Dock.cycle(item.appId, wheel.angleDelta.y)
                    onContainsMouseChanged: {
                        if (containsMouse)
                            root.showCol(item, item.modelData.name + (item.running ? " · " + item.modelData.windows + " window" + (item.modelData.windows > 1 ? "s" : "") : ""));
                        else
                            root.hideCol();
                    }
                }
            }
        }
    }
}
