import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"

// Arch Updater panel — categorized update list with refresh + update-all.
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
    visible: PluginService.isPluginPanelOpen("arch-updater") || hideDelay.running
    mask: Region {
        item: PluginService.isPluginPanelOpen("arch-updater") ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: PluginService.isPluginPanelOpen("arch-updater") ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(640, contentRoot.width - Theme.outerPad * 2)
    readonly property int cardH: Math.min(580, contentRoot.height - Theme.barHeight - Theme.outerPad * 2)
    readonly property int padX: Theme.sp4

    readonly property var daemon: {
        const d = PluginService.daemons["arch-updater"];
        return d || null;
    }

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    Connections {
        target: PluginService

        function onPluginOpenIdChanged() {
            if (PluginService.isPluginPanelOpen("arch-updater")) {
                hideDelay.stop();
                if (root.daemon && root.daemon.updateCount === 0)
                    root.daemon.refresh();
            } else {
                hideDelay.restart();
            }
        }
    }

    Item {
        id: contentRoot

        anchors.fill: parent

        Keys.onEscapePressed: PluginService.closePluginPanel()

        YClickAway {
            id: clickAway

            onOutsideClicked: PluginService.closePluginPanel()
        }

        YSurface {
            id: surface

            open: PluginService.isPluginPanelOpen("arch-updater")
            spawnId: "arch-updater"
            cascade: bodyCol
            anchorX: "right"
            cardW: root.cardW
            cardH: Math.max(340, root.cardH)

            // ---- header ----
            Item {
                x: root.padX
                y: 0
                width: parent.width - root.padX * 2 - 1
                height: Theme.headH

                Rectangle {
                    id: mark

                    x: 0
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.acid

                    Text {
                        anchors.centerIn: parent
                        text: "更"
                        visible: Theme.jpEnabled
                        color: Theme.acid
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !Theme.jpEnabled
                        text: "↻"
                        color: Theme.acid
                        font.family: Theme.fontFamily
                        font.pixelSize: 14
                        font.weight: Font.ExtraBold
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: mark.right
                    anchors.leftMargin: Theme.sp2
                    text: "ARCH.UPDATER"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                YChip {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    label: root.daemon && root.daemon.checking ? "CHECKING…" : root.daemon ? root.daemon.updateCount + " UPDATE" + (root.daemon.updateCount !== 1 ? "S" : "") : "—"
                    tone: root.daemon && root.daemon.updateCount > 0 ? "accent" : "neutral"
                }
            }

            // ---- body ----
            Column {
                id: bodyCol

                x: root.padX
                y: Theme.headH + Theme.sp2
                width: parent.width - root.padX * 2 - 1
                spacing: Theme.sp3

                // no updates
                Item {
                    width: parent.width
                    height: root.daemon && root.daemon.updateCount === 0 && !root.daemon.checking ? 60 : 0
                    visible: height > 0

                    Text {
                        anchors.centerIn: parent
                        text: "system is up to date"
                        color: Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsBody
                    }
                }

                // official section
                Column {
                    width: parent.width
                    spacing: Theme.sp2
                    visible: root.daemon && root.daemon.officialCount > 0

                    YSection {
                        label: "OFFICIAL"
                        count: root.daemon ? root.daemon.officialCount : 0
                    }

                    Repeater {
                        model: root.daemon ? root.daemon.officialPkgs : []

                        Text {
                            required property var modelData

                            width: parent.width
                            text: modelData.from.length > 0 ? modelData.name + "  " + modelData.from + " → " + modelData.to : modelData.name
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                            elide: Text.ElideRight
                        }
                    }
                }

                // AUR section
                Column {
                    width: parent.width
                    spacing: Theme.sp2
                    visible: root.daemon && root.daemon.aurCount > 0

                    YSection {
                        label: "AUR"
                        count: root.daemon ? root.daemon.aurCount : 0
                    }

                    Repeater {
                        model: root.daemon ? root.daemon.aurPkgs : []

                        Text {
                            required property var modelData

                            width: parent.width
                            text: modelData.from.length > 0 ? modelData.name + "  " + modelData.from + " → " + modelData.to : modelData.name
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                            elide: Text.ElideRight
                        }
                    }
                }

                // Flatpak section
                Column {
                    width: parent.width
                    spacing: Theme.sp2
                    visible: root.daemon && root.daemon.flatpakCount > 0

                    YSection {
                        label: "FLATPAK"
                        count: root.daemon ? root.daemon.flatpakCount : 0
                    }

                    Repeater {
                        model: root.daemon ? root.daemon.flatpakPkgs : []

                        Text {
                            required property var modelData

                            width: parent.width
                            text: modelData.from.length > 0 ? modelData.name + "  " + modelData.from + " → " + modelData.to : modelData.name
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsLabel
                            elide: Text.ElideRight
                        }
                    }
                }

                // ---- footer ----
                Item {
                    width: parent.width
                    height: Theme.sp3
                }

                Text {
                    width: parent.width
                    text: {
                        if (!root.daemon) return "";
                        const d = root.daemon.lastCheck;
                        if (!d || d.getTime() === 0) return "never checked";
                        const mins = Math.round((Date.now() - d.getTime()) / 60000);
                        if (mins < 1) return "checked just now";
                        if (mins === 1) return "checked 1 min ago";
                        if (mins < 60) return "checked " + mins + " min ago";
                        const hrs = Math.floor(mins / 60);
                        return "checked " + hrs + "h " + (mins % 60) + "m ago";
                    }
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 1
                }

                Row {
                    width: parent.width
                    spacing: Theme.sp2

                    YButton {
                        label: "CHECK"
                        compact: true
                        onClicked: root.daemon && root.daemon.refresh()
                    }

                    YButton {
                        label: "UPDATE ALL"
                        compact: true
                        accent: true
                        onClicked: root.daemon && root.daemon.updateAll()
                    }
                }

                Item {
                    width: parent.width
                    height: Theme.sp2
                }
            }
        }
    }
}
