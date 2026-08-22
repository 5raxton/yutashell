pragma Singleton
import QtQuick

QtObject {
    id: root

    readonly property color bg: "#0a0a0c"
    readonly property color bgAlt: "#101014"
    readonly property color surface: "#17171c"
    readonly property color ink: "#eae8e0"
    readonly property color muted: "#6b6a63"
    readonly property color faint: "#3f3e3a"
    readonly property color hairline: "#1d1d22"
    readonly property color lineStrong: "#2c2c34"
    readonly property color acid: "#c8ff3d"
    readonly property color acidDeep: "#8fbe1f"
    readonly property color alert: "#ff3b52"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"
    readonly property bool jpEnabled: Qt.fontFamilies().some(f => /cjk|jp|japan/i.test(f))

    readonly property int barHeight: 44
    readonly property int outerPad: 14
    readonly property int sectionGap: 16
}
