import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.theme
import qs.modules.common
import "../common/ui"

// Bluetooth surface — adapter power/scan/discoverable, device list with
// battery + pair/trust/connect/forget. Trust doubles as the autoconnect
// flag (BlueZ semantics: trusted devices reconnect on their own).
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
    visible: ShellState.btOpen || hideDelay.running
    mask: Region {
        item: ShellState.btOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.btOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: 540
    readonly property int cardH: Math.min(600, contentRoot.height - Theme.barHeight - Theme.outerPad * 2)
    readonly property int padX: Theme.sp4
    readonly property int contentW: cardW - padX * 2 - 1
    readonly property var adapter: Bluetooth.defaultAdapter

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    // linger mapped after close so YSurface's exit ceremony renders
    Connections {
        target: ShellState

        function onBtOpenChanged() {
            if (!ShellState.btOpen)
                hideDelay.restart();
        }
    }

    // scan while open, rest when closed
    Connections {
        target: ShellState

        function onBtOpenChanged() {
            if (root.adapter)
                root.adapter.discovering = ShellState.btOpen;
        }
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeBt()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeBt()
        }

        YSurface {

            spawnId: "bt"
            id: surface

            open: ShellState.btOpen
            cascade: bodyCol
            anchorX: "right"
            cardW: root.cardW
            cardH: Math.max(320, root.cardH)

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
                    border.color: root.adapter && root.adapter.enabled ? Theme.acid : Theme.lineStrong

                    Text {
                        anchors.centerIn: parent
                        text: "◆"
                        color: root.adapter && root.adapter.enabled ? Theme.acid : Theme.muted
                        font.family: Theme.fontFamily
                        font.pixelSize: 11
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: mark.right
                    anchors.leftMargin: Theme.sp2
                    text: "BT.BLUE"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                YChip {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    label: !root.adapter ? "NO ADAPTER" : root.adapter.discovering ? "SCANNING" : root.adapter.devices.values.length + " DEV"
                    tone: !root.adapter || !root.adapter.enabled ? "outline" : "acid"
                }
            }

            Rectangle {
                x: root.padX
                y: Theme.headH
                width: parent.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            Flickable {
                id: scroll

                x: root.padX
                y: Theme.headH + 1
                width: parent.width - root.padX * 2 - 1
                height: parent.height - Theme.headH - Theme.sp3
                clip: true
                contentWidth: width
                contentHeight: bodyCol.height

                FastWheel {}

                Column {
                    id: bodyCol

                    width: parent.width
                    spacing: Theme.sp2

                    YSection {
                        width: parent.width
                        index: "01"
                        label: "Adapter"
                        chip: root.adapter ? String(root.adapter.name).slice(0, 12) : ""
                    }

                    Text {
                        width: parent.width
                        visible: root.adapter === null
                        text: "no bluetooth controller present"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                    }

                    YRow {
                        visible: root.adapter !== null
                        width: root.contentW
                        title: "Bluetooth power"
                        sub: root.adapter && root.adapter.enabled ? "radio up" : "radio down"
                        note: "PWR"
                        interactive: root.adapter !== null
                        on_: root.adapter ? root.adapter.enabled : false

                        YSwitch {
                            checked: root.adapter ? root.adapter.enabled : false
                            enabled: root.adapter !== null
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: if (root.adapter)
                                root.adapter.enabled = !root.adapter.enabled
                        }
                    }

                    YRow {
                        visible: root.adapter !== null && root.adapter.enabled
                        width: root.contentW
                        title: "Scanning"
                        sub: root.adapter && root.adapter.discovering ? "discovering nearby devices" : "idle"
                        note: "SCN"
                        interactive: root.adapter !== null
                        on_: root.adapter ? root.adapter.discovering : false

                        YSwitch {
                            checked: root.adapter ? root.adapter.discovering : false
                            enabled: root.adapter !== null
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: if (root.adapter)
                                root.adapter.discovering = !root.adapter.discovering
                        }
                    }

                    YRow {
                        visible: root.adapter !== null && root.adapter.enabled
                        width: root.contentW
                        title: "Discoverable"
                        sub: "visible to other devices while on"
                        note: "DSC"
                        interactive: root.adapter !== null
                        on_: root.adapter ? root.adapter.discoverable : false

                        YSwitch {
                            checked: root.adapter ? root.adapter.discoverable : false
                            enabled: root.adapter !== null
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: if (root.adapter)
                                root.adapter.discoverable = !root.adapter.discoverable
                        }
                    }

                    YSection {
                        visible: root.adapter !== null && root.adapter.enabled
                        width: parent.width
                        index: "02"
                        label: "Devices"
                        chip: root.adapter ? root.adapter.devices.values.length + "" : ""
                    }

                    Repeater {
                        model: root.adapter ? root.adapter.devices.values : []

                        delegate: Rectangle {
                            id: devRow

                            required property int index
                            required property var modelData

                            readonly property bool hovered: harea.containsMouse

                            width: root.contentW
                            height: 48
                            color: hovered ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.04) : "transparent"

                            IconImage {
                                id: devIcon

                                x: Theme.sp1
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 20
                                source: root.modelData !== undefined && root.modelData.icon !== undefined && root.modelData.icon.length > 0 ? Quickshell.iconPath(root.modelData.icon) : ""
                                visible: status === Image.Ready
                            }

                            Text {
                                x: Theme.sp1
                                anchors.verticalCenter: parent.verticalCenter
                                visible: !devIcon.visible
                                width: 20
                                horizontalAlignment: Text.AlignHCenter
                                text: "?"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                            }

                            Column {
                                anchors.left: parent.left
                                anchors.leftMargin: 34
                                anchors.right: actions.left
                                anchors.rightMargin: Theme.sp2
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1

                                Row {
                                    spacing: Theme.sp2

                                    Text {
                                        text: devRow.modelData !== undefined && devRow.modelData.deviceName !== undefined && devRow.modelData.deviceName.length > 0 ? devRow.modelData.deviceName : (devRow.modelData?.name ?? "")
                                        color: (devRow.modelData?.connected ?? false) ? Theme.acid : Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsBody
                                        font.weight: (devRow.modelData?.connected ?? false) ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                        width: Math.min(220, root.contentW - 120)
                                    }

                                    YChip {
                                        visible: devRow.modelData?.batteryAvailable ?? false
                                        label: Math.round((devRow.modelData?.battery ?? 0) * 100) + "%"
                                        tone: (devRow.modelData?.battery ?? 0) > 0.5 ? "outline" : "alert"
                                    }
                                }

                                Text {
                                    text: devRow.modelData?.state === BluetoothDeviceState.Connected ? "connected" : devRow.modelData?.state === BluetoothDeviceState.Connecting ? "connecting…" : devRow.modelData?.state === BluetoothDeviceState.Disconnecting ? "disconnecting…" : (devRow.modelData?.paired ?? false) ? "paired · idle" : (devRow.modelData?.pairing ?? false) ? "pairing…" : "unpaired"
                                    color: devRow.modelData?.state === BluetoothDeviceState.Connecting || (devRow.modelData?.pairing ?? false) ? Theme.muted : Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                }
                            }

                            Row {
                                id: actions

                                anchors.right: parent.right
                                anchors.rightMargin: Theme.sp1
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.sp1
                                visible: devRow.hovered

                                YButton {
                                    visible: !(devRow.modelData?.paired ?? false) && !(devRow.modelData?.pairing ?? false)
                                    label: "PAIR"
                                    onClicked: devRow.modelData.pair()
                                }

                                YSwitch {
                                    visible: devRow.modelData?.paired ?? false
                                    checked: devRow.modelData?.trusted ?? false
                                    anchors.verticalCenter: parent.verticalCenter
                                    onToggled: devRow.modelData.trusted = !devRow.modelData.trusted
                                }

                                YButton {
                                    visible: devRow.modelData?.paired ?? false
                                    label: (devRow.modelData?.connected ?? false) ? "DISC" : "CONN"
                                    tone: (devRow.modelData?.connected ?? false) ? "danger" : "acid"
                                    onClicked: devRow.modelData.connected ? devRow.modelData.disconnect() : devRow.modelData.connect()
                                }

                                YButton {
                                    visible: devRow.modelData?.paired ?? false
                                    label: "×"
                                    tone: "danger"
                                    onClicked: devRow.modelData.forget()
                                }
                            }

                            MouseArea {
                                id: harea

                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: root.adapter !== null && root.adapter.enabled && root.adapter.devices.values.length === 0
                        text: "no devices — flip scanning to find some"
                        color: Theme.faint
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fsLabel
                    }

                    Item {
                        width: 1
                        height: Theme.sp3
                    }
                }
            }

            YScroll {
                target: scroll
                anchors.top: scroll.top
                anchors.bottom: scroll.bottom
                anchors.right: scroll.right
                width: 3
            }
        }
    }
}
