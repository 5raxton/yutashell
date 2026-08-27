import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."

// SnapshotPicker — YSurface panel showing snapshot cards. Each card: name,
// timestamp, window count, restore/overwrite/delete buttons. "Save New"
// button at top with name input. Auto-snapshots on timer (last 3 kept).
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
    visible: ShellState.snapshotsOpen || hideDelay.running
    mask: Region {
        item: ShellState.snapshotsOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.snapshotsOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(720, contentRoot.width - Theme.outerPad * 2)
    readonly property int cardH: Math.min(520, contentRoot.height - Theme.outerPad * 2)

    property string _saveName: ""

    Timer {
        id: hideDelay
        interval: Theme.lingerMs
    }

    Connections {
        target: ShellState
        function onSnapshotsOpenChanged() {
            if (ShellState.snapshotsOpen)
                hideDelay.stop();
            else
                hideDelay.restart();
        }
    }

    YClickAway {
        id: clickAway
        anchors.fill: parent
        onClicked: ShellState.closeSnapshots()
    }

    Item {
        id: contentRoot
        anchors.fill: parent

        YSurface {
            id: surface
            anchors.centerIn: parent
            open: ShellState.snapshotsOpen
            spawnId: "snapshots"
            cardW: root.cardW
            cardH: root.cardH

            Column {
                id: bodyCol
                anchors.fill: parent
                anchors.margins: Theme.sp4
                spacing: Theme.sp3

                // header
                Row {
                    width: parent.width
                    spacing: Theme.sp3

                    Text {
                        text: "SESSION SNAPSHOTS"
                        font.pixelSize: Theme.fsMicro
                        font.family: Theme.fontFamily
                        color: Theme.ink
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: 1; height: 1 }

                    YButton {
                        label: "SAVE NEW"
                        tone: "acid"
                        onClicked: {
                            const name = "snap-" + new Date().toISOString().slice(0, 16).replace(/[T:]/g, "-");
                            SnapshotService.save(name);
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 1
                    color: Theme.lineStrong
                }

                // snapshot cards (scrollable)
                Flickable {
                    width: parent.width
                    height: parent.height - Theme.sp3 * 3 - 40
                    clip: true
                    contentHeight: snapGrid.height
                    flickableDirection: Flickable.VerticalFlick
                    FastWheel {}

                    Column {
                        id: snapGrid
                        width: parent.width
                        spacing: Theme.sp2

                        // empty state
                        Text {
                            visible: SnapshotService.snapshots.length === 0
                            width: parent.width
                            text: "No snapshots yet.\n\nClick \"Save New\" to capture your current desktop state."
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBody
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: Theme.sp6
                        }

                        // snapshot cards
                        Repeater {
                            model: SnapshotService.snapshots

                            Rectangle {
                                required property var modelData
                                width: snapGrid.width
                                height: 52
                                radius: Theme.radius
                                color: Theme.bg
                                border.width: 1
                                border.color: Theme.hairline

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.sp2
                                    spacing: Theme.sp2

                                    // icon
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "ᶻ"
                                        color: Theme.acid
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsBody
                                        width: 24
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    // name + timestamp
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 24 - Theme.sp2 * 2 - restoreBtn.width - delBtn.width - Theme.sp2 * 2

                                        Text {
                                            text: modelData.name || "unnamed"
                                            color: Theme.ink
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsBody
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                            width: parent.width
                                        }

                                        Text {
                                            text: _formatTs(modelData.timestamp) + " · " + modelData.windowCount + " windows"
                                            color: Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsMicro
                                        }
                                    }

                                    // restore button
                                    YButton {
                                        id: restoreBtn
                                        label: "RESTORE"
                                        tone: "acid"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: SnapshotService.restore(modelData.name)
                                    }

                                    // delete button
                                    YButton {
                                        id: delBtn
                                        label: "DEL"
                                        tone: "danger"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: SnapshotService.deleteSnapshot(modelData.name)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function _formatTs(ts) {
        if (!ts) return "";
        const d = new Date(ts);
        const pad = function(n) { return n < 10 ? "0" + n : "" + n; };
        return (d.getMonth() + 1) + "/" + d.getDate() + " " + pad(d.getHours()) + ":" + pad(d.getMinutes());
    }

    // auto-snapshot every 30 minutes (keep last 3)
    Timer {
        id: autoSnapTimer
        interval: 30 * 60 * 1000
        repeat: true
        running: ShellState.snapshotAuto ?? true
        onTriggered: {
            SnapshotService.save("__auto__");
            // prune auto-snapshots to last 3
            const snaps = SnapshotService.snapshots;
            const autos = snaps.filter(function(s) { return s.name.startsWith("__auto__"); });
            if (autos.length > 3) {
                for (let i = 3; i < autos.length; i++)
                    SnapshotService.deleteSnapshot(autos[i].name);
            }
        }
    }
}
