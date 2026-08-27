import Quickshell
import QtQuick
import qs.theme
import qs.modules.common
import qs.modules.common.ui
import "../system"

// SystemMonitor (PH.06) — unified YSurface panel showing battery health,
// network diagnostics, power budget, and workspace heatmap in a tabbed layout.
PanelWindow {
    id: root

    screen: FocusMonitor.screen

    readonly property bool open: ShellState.systemMonitorOpen

    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    visible: root.open || hideDelay.running
    mask: Region { item: root.open ? clickAway : null }

    WlrLayershell.layer: WlrLayer.Top

    Timer { id: hideDelay; interval: Theme.lingerMs }
    onOpenChanged: if (!root.open) hideDelay.restart()

    YClickAway { id: clickAway; onOutsideClicked: ShellState.closeSystemMonitor() }

    property int activeTab: 0
    property var tabs: ["BATTERY", "NETWORK", "POWER", "WORKSPACES"]

    Item {
        anchors.fill: parent
        focus: root.open
        Keys.onEscapePressed: ShellState.closeSystemMonitor()

        YSurface {
            id: card
            open: root.open
            anchorX: "center"
            cardW: Math.min(560, Math.round(parent.width * 0.42))
            cardH: Math.min(520, Math.round(parent.height * 0.6))

            Column {
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                // header
                Text {
                    text: "SYSTEM MONITOR"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.weight: Font.Bold
                    font.letterSpacing: 2
                }

                // tab chips
                Row {
                    spacing: 6
                    Repeater {
                        model: root.tabs
                        delegate: YButton {
                            required property string modelData
                            required property int index
                            label: modelData
                            tone: root.activeTab === index ? "acid" : "default"
                            onClicked: root.activeTab = index
                        }
                    }
                }

                // content area
                Item {
                    width: parent.width
                    height: parent.height - 80

                    // BATTERY TAB
                    Column {
                        anchors.fill: parent
                        visible: root.activeTab === 0
                        spacing: 12

                        Row {
                            spacing: 16
                            width: parent.width

                            // battery ring
                            Rectangle {
                                width: 80
                                height: 80
                                radius: 40
                                color: "transparent"
                                border.width: 6
                                border.color: BatteryService.warn ? Theme.alert
                                    : BatteryService.crit ? "#ff4444" : Theme.acid

                                Text {
                                    anchors.centerIn: parent
                                    text: BatteryService.present ? BatteryService.pct + "%" : "N/A"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsTitle
                                    font.weight: Font.Bold
                                }
                            }

                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 4

                                Text {
                                    text: BatteryService.present
                                        ? (BatteryService.charging ? "CHARGING" : "DISCHARGING")
                                        : "NO BATTERY"
                                    color: BatteryService.charging ? Theme.acid : Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.5
                                }

                                Text {
                                    visible: BatteryService.present && BatteryService.timeLeft > 0
                                    text: "Remaining: " + Math.floor(BatteryService.timeLeft) + " min"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                }

                                Text {
                                    visible: BatteryService.present && BatteryService.charging && BatteryService.timeToFull > 0
                                    text: "Full in: " + Math.floor(BatteryService.timeToFull) + " min"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                }
                            }
                        }

                        // health
                        Column {
                            visible: BatteryService.present
                            width: parent.width
                            spacing: 4

                            Text {
                                text: "HEALTH"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }

                            Row {
                                spacing: 16
                                Text {
                                    text: "Health: " + BatteryService.healthPct.toFixed(1) + "%"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                }
                                Text {
                                    text: "Wear: " + BatteryService.wearPct.toFixed(1) + "%"
                                    color: BatteryService.wearPct > 20 ? Theme.alert : Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                }
                            }

                            Text {
                                text: "Energy: " + SystemStats.fmtBytes(SystemStats.batEnergyFull * 1000)
                                    + " / " + SystemStats.fmtBytes(SystemStats.batEnergyDesign * 1000)
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                            }

                            Text {
                                visible: BatteryService.chargeThreshold >= 0
                                text: "Charge threshold: " + BatteryService.chargeThreshold + "%"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsLabel
                            }
                        }
                    }

                    // NETWORK TAB
                    Column {
                        anchors.fill: parent
                        visible: root.activeTab === 1
                        spacing: 12

                        Repeater {
                            model: [
                                { label: "LATENCY", value: NetHealth.latencyMs >= 0 ? NetHealth.latencyMs + " ms" : "timeout", color: NetHealth.latencyMs < 50 ? Theme.acid : NetHealth.latencyMs < 100 ? Theme.ink : Theme.alert },
                                { label: "GRADE", value: NetHealth.latencyGrade.toUpperCase(), color: Theme.ink },
                                { label: "IP4", value: NetHealth.ip4 || "unknown", color: Theme.ink },
                                { label: "VPN", value: NetHealth.vpnActive ? "CONNECTED" : "DOWN", color: NetHealth.vpnActive ? Theme.acid : Theme.muted },
                                { label: "DNS SERVER", value: NetHealth.dnsServer || "unknown", color: Theme.ink }
                            ]

                            delegate: Row {
                                required property var modelData
                                width: parent.width
                                height: 32

                                Text {
                                    width: 120
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.label
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.5
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.value
                                    color: modelData.color
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                    }

                    // POWER TAB
                    Column {
                        anchors.fill: parent
                        visible: root.activeTab === 2
                        spacing: 12

                        // battery discharge
                        Column {
                            visible: PowerBudget.dischargeRate > 0
                            spacing: 4
                            Text {
                                text: "DISCHARGE RATE"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }
                            Text {
                                text: (PowerBudget.dischargeRate / 1000).toFixed(2) + " W"
                                color: Theme.ink
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsTitle
                                font.weight: Font.Bold
                            }
                            Text {
                                visible: PowerBudget.estimatedMinutes > 0
                                text: "Estimated: " + Math.floor(PowerBudget.estimatedMinutes / 60) + "h " + (PowerBudget.estimatedMinutes % 60) + "m remaining"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                            }
                        }

                        // screen brightness
                        Column {
                            visible: PowerBudget.screenBrightnessMax > 0
                            spacing: 4
                            Text {
                                text: "SCREEN BRIGHTNESS"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }
                            Rectangle {
                                width: parent.width
                                height: 16
                                radius: 4
                                color: Theme.surface
                                Rectangle {
                                    width: Math.max(4, parent.width * (PowerBudget.screenBrightness / PowerBudget.screenBrightnessMax))
                                    height: parent.height
                                    radius: 4
                                    color: Theme.acid
                                }
                            }
                        }

                        // top CPU apps
                        Column {
                            width: parent.width
                            spacing: 4
                            Text {
                                text: "TOP CPU APPS"
                                color: Theme.muted
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsMicro
                                font.weight: Font.Bold
                                font.letterSpacing: 1.5
                            }

                            Repeater {
                                model: PowerBudget.topApps
                                delegate: Row {
                                    required property var modelData
                                    width: parent.width
                                    height: 24

                                    Text {
                                        width: parent.width * 0.55
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.name
                                        color: Theme.ink
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsLabel
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: parent.width * 0.3
                                        height: 12
                                        radius: 3
                                        color: Theme.surface
                                        anchors.verticalCenter: parent.verticalCenter
                                        Rectangle {
                                            width: Math.max(2, parent.width * Math.min(modelData.cpu / 100, 1))
                                            height: parent.height
                                            radius: 3
                                            color: modelData.cpu > 50 ? Theme.alert : Theme.acid
                                        }
                                    }

                                    Text {
                                        width: parent.width * 0.15
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: modelData.cpu.toFixed(1) + "%"
                                        color: Theme.muted
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fsMicro
                                        horizontalAlignment: Text.AlignRight
                                    }
                                }
                            }
                        }
                    }

                    // WORKSPACES TAB
                    Column {
                        anchors.fill: parent
                        visible: root.activeTab === 3
                        spacing: 12

                        Text {
                            text: "WORKSPACE USAGE"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                            font.weight: Font.Bold
                            font.letterSpacing: 1.5
                        }

                        Flow {
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: WsHeatmap.workspaces
                                delegate: Rectangle {
                                    required property var modelData
                                    width: 56
                                    height: 56
                                    radius: 6
                                    color: modelData.focused ? Theme.acid + "33"
                                        : modelData.windows === 0 ? Theme.surface
                                        : modelData.windows <= 2 ? Theme.acid + "15"
                                        : modelData.windows <= 4 ? Theme.acid + "25"
                                        : Theme.acid + "40"
                                    border.width: modelData.focused ? 2 : 0
                                    border.color: Theme.acid

                                    Column {
                                        anchors.centerIn: parent
                                        spacing: 2

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.name || String(modelData.id)
                                            color: modelData.focused ? Theme.acid : Theme.ink
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fsMicro
                                            font.weight: Font.Bold
                                        }

                                        Text {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            text: modelData.windows + " win"
                                            color: Theme.muted
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 10
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: WsHeatmap.switchTo(modelData.id)
                                    }
                                }
                            }

                            Text {
                                visible: WsHeatmap.workspaces.length === 0
                                text: "No workspaces"
                                color: Theme.faint
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fsBody
                            }
                        }
                    }
                }
            }
        }
    }
}
