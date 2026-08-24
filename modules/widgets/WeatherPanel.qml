import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"
import "."

// Weather panel (PH.11) — conditions hero + 5-day forecast strip. Configure
// location via `qs ipc call weather set <lat> <lon> <label>` or the PH.16
// SHELL tab. Unconfigured/offline states degrade to a flat message.
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
    visible: ShellState.weatherOpen || hideDelay.running
    mask: Region {
        item: ShellState.weatherOpen ? clickAway : null
    }

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: ShellState.weatherOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    readonly property int cardW: 420
    readonly property int padX: Theme.sp4

    readonly property var info: Weather.current ? Weather.codeInfo(Weather.current.code) : ["·", "—"]

    Timer {
        id: hideDelay

        interval: Theme.lingerMs
    }

    // linger mapped after close so YSurface's exit ceremony renders
    Connections {
        target: ShellState

        function onWeatherOpenChanged() {
            if (!ShellState.weatherOpen)
                hideDelay.restart();
        }
    }

    Connections {
        target: ShellState

        function onWeatherOpenChanged() {
            if (ShellState.weatherOpen)
                Weather.refresh();
        }
    }

    Item {
        id: contentRoot

        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: ShellState.closeWeather()

        YClickAway {
            id: clickAway

            onOutsideClicked: ShellState.closeWeather()
        }

        YSurface {
            id: surface

            open: ShellState.weatherOpen
            anchorX: "center"
            cardW: root.cardW
            cardH: 320

            // ---- header ----
            Item {
                x: root.padX
                y: 0
                width: surface.width - root.padX * 2 - 1
                height: Theme.headH

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "WEATHER"
                    color: Theme.ink
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.ExtraBold
                    font.letterSpacing: 1.5
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 96
                    visible: Theme.jpEnabled
                    text: "天気"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                }

                YButton {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    width: 30
                    label: "×"
                    onClicked: ShellState.closeWeather()
                }
            }

            Rectangle {
                x: root.padX
                y: Theme.headH
                width: surface.width - root.padX * 2 - 1
                height: 1
                color: Theme.hairline
            }

            Column {
                x: root.padX
                y: Theme.headH + Theme.sp4
                width: surface.width - root.padX * 2 - 1
                spacing: Theme.sp3

                // ---- unconfigured state ----
                Text {
                    width: parent.width
                    visible: !Weather.configured
                    text: "NO LOCATION SET"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    font.letterSpacing: 2
                }

                Text {
                    width: parent.width
                    visible: !Weather.configured
                    text: "qs ipc call weather set <lat> <lon> <label>"
                    color: Theme.muted
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    wrapMode: Text.WordWrap
                }

                // ---- hero ----
                Item {
                    width: parent.width
                    height: 88
                    visible: Weather.configured && Weather.current !== null

                    Text {
                        id: heroGlyph

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.info[0]
                        color: Theme.acid
                        opacity: Weather.fetching ? 0.45 : 1
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(Theme.fsDisplay * 2.7)
                        Behavior on opacity {
                            NumberAnimation {
                                duration: Theme.movMed
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    Text {
                        anchors.left: heroGlyph.right
                        anchors.leftMargin: Theme.sp3
                        anchors.verticalCenter: parent.verticalCenter
                        text: Weather.current ? Weather.current.temp + "°" : ""
                        color: Theme.ink
                        font.family: Theme.fontFamily
                        font.pixelSize: Math.round(Theme.fsDisplay * 2.2)
                        font.weight: Font.ExtraBold
                        font.letterSpacing: 1
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 150
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        Text {
                            text: root.info[1]
                            color: Theme.ink
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsBody
                            font.weight: Font.DemiBold
                        }

                        Text {
                            // width-capped micro-line — long location labels overflowed the card
                            width: parent.width
                            elide: Text.ElideRight
                            text: (ShellState.weatherLabel.length > 0 ? ShellState.weatherLabel.toUpperCase() : ShellState.weatherLat + "," + ShellState.weatherLon) + " · WIND " + (Weather.current ? Weather.current.wind : 0) + "KM/H"
                            color: Theme.muted
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fsMicro
                            font.letterSpacing: 1
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: Weather.configured && Weather.current === null
                    text: !Weather.available ? "UNAVAILABLE — curl is not installed" : Weather.error.length > 0 ? "FETCH ERROR — " + Weather.error : "LOADING…"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsLabel
                    wrapMode: Text.WordWrap
                }

                // ---- forecast strip ----
                Row {
                    width: parent.width
                    spacing: Theme.sp1
                    visible: Weather.forecast.length > 0

                    Repeater {
                        model: Weather.forecast

                        delegate: Rectangle {
                            required property int index
                            required property var modelData

                            readonly property var fi: Weather.codeInfo(modelData.code)

                            width: (parent.width - Theme.sp1 * 4) / 5
                            height: 84
                            color: Theme.bg
                            border.width: 1
                            border.color: Theme.hairline

                            Column {
                                anchors.fill: parent
                                anchors.margins: Theme.sp2
                                spacing: 3

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: {
                                        const d = new Date(modelData.date);
                                        return ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"][d.getDay()];
                                    }
                                    color: Theme.faint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsMicro
                                    font.letterSpacing: 1
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: fi[0]
                                    color: Theme.acid
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Math.round(Theme.fsBody * 1.4)
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.max + "°"
                                    color: Theme.ink
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsBody
                                    font.weight: Font.Bold
                                }

                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: modelData.min + "°"
                                    color: Theme.muted
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fsLabel
                                }
                            }
                        }
                    }
                }

                // ---- footer stamp ----
                Text {
                    width: parent.width
                    visible: Weather.lastFetch.getTime() > 0
                    text: "UPDATED " + Weather.lastFetch.toTimeString().slice(0, 5) + " · OPEN-METEO"
                    color: Theme.faint
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsMicro
                    font.letterSpacing: 1
                }
            }
        }
    }
}
