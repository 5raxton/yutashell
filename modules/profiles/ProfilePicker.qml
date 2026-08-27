import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."

// ProfilePicker — YSurface panel showing project profiles as cards.
// Each card: icon + name + active indicator + apply/delete buttons.
// "Save Current" creates a new profile from live state.
// IPC: `profiles toggle/open/close`.
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
    visible: ShellState.profilesOpen || hideDelay.running
    mask: Region {
        item: ShellState.profilesOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.profilesOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: Math.min(720, contentRoot.width - Theme.outerPad * 2)
    readonly property int cardH: Math.min(520, contentRoot.height - Theme.outerPad * 2)

    Timer {
        id: hideDelay
        interval: Theme.lingerMs
    }

    Connections {
        target: ShellState
        function onProfilesOpenChanged() {
            if (ShellState.profilesOpen)
                hideDelay.stop();
            else
                hideDelay.restart();
        }
    }

    YClickAway {
        id: clickAway
        anchors.fill: parent
        onClicked: ShellState.closeProfiles()
    }

    Item {
        id: contentRoot
        anchors.fill: parent

        YSurface {
            id: surface
            anchors.centerIn: parent
            open: ShellState.profilesOpen
            spawnId: "profiles"
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
                        text: "PROJECT PROFILES"
                        font.pixelSize: Theme.fsMicro
                        font.family: Theme.fontFamily
                        color: Theme.ink
                        font.weight: Font.DemiBold
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Item { width: 1; height: 1 }

                    YButton {
                        label: "SAVE CURRENT"
                        tone: "acid"
                        onClicked: {
                            const id = "p" + Date.now().toString(36);
                            ProfileService.save(id, "Profile " + (ProfileService.profiles.length + 1));
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 1
                    color: Theme.lineStrong
                }

                // profile cards (scrollable)
                Flickable {
                    width: parent.width
                    height: parent.height - Theme.sp3 * 3 - 40
                    clip: true
                    contentHeight: profileGrid.height
                    flickableDirection: Flickable.VerticalFlick
                    FastWheel {}

                    Column {
                        id: profileGrid
                        width: parent.width
                        spacing: Theme.sp2

                        // empty state
                        Text {
                            visible: ProfileService.profiles.length === 0
                            width: parent.width
                            text: "No profiles yet.\n\nClick \"Save Current\" to create a profile from your current workspace state."
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBody
                            wrapMode: Text.Wrap
                            horizontalAlignment: Text.AlignHCenter
                            topPadding: Theme.sp6
                        }

                        // profile cards
                        Repeater {
                            model: ProfileService.profiles

                            Rectangle {
                                required property var modelData
                                width: profileGrid.width
                                height: 52
                                radius: Theme.radius
                                color: modelData.id === ProfileService.activeId ? Theme.acid + "18" : Theme.bg
                                border.width: 1
                                border.color: modelData.id === ProfileService.activeId ? Theme.acid : Theme.hairline

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: Theme.sp2
                                    spacing: Theme.sp2

                                    // active indicator
                                    Rectangle {
                                        width: 4
                                        height: parent.height
                                        radius: 2
                                        color: modelData.id === ProfileService.activeId ? Theme.acid : Theme.faint
                                    }

                                    // icon
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.icon || "◆"
                                        color: Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsBody
                                        width: 24
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    // name
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name || "Unnamed"
                                        color: Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsBody
                                        font.weight: modelData.id === ProfileService.activeId ? Font.Bold : Font.Normal
                                        elide: Text.ElideRight
                                        width: parent.width - 4 - 24 - Theme.sp2 * 2 - applyBtn.width - delBtn.width - renameBtn.width - Theme.sp2 * 3
                                    }

                                    // rename button
                                    YButton {
                                        id: renameBtn
                                        label: "RENAME"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: {
                                            // simple rename: prompt via IPC or just use the id as-is for now
                                            // A proper implementation would use an inline text field; for now
                                            // we cycle through a preset name pattern.
                                            const names = ["Work", "Play", "Focus", "Chill", "Dev", "Media"];
                                            const cur = names.indexOf(modelData.name);
                                            const next = (cur + 1) % names.length;
                                            ProfileService.rename(modelData.id, names[next]);
                                        }
                                    }

                                    // apply button
                                    YButton {
                                        id: applyBtn
                                        label: modelData.id === ProfileService.activeId ? "ACTIVE" : "APPLY"
                                        tone: modelData.id === ProfileService.activeId ? "acid" : "default"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: {
                                            if (modelData.id !== ProfileService.activeId)
                                                ProfileService.apply(modelData.id);
                                        }
                                    }

                                    // delete button
                                    YButton {
                                        id: delBtn
                                        label: "DEL"
                                        tone: "danger"
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: ProfileService.deleteProfile(modelData.id)
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    z: -1
                                    onClicked: {
                                        if (modelData.id !== ProfileService.activeId)
                                            ProfileService.apply(modelData.id);
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
