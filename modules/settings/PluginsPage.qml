import QtQuick
import qs.theme
import qs.modules.common
import "../common/ui"

// PLUGINS page (PH.05) — scan results, enable/disable, per-plugin state.
// Widget-type plugins surface in the bar's "Plugin widgets" segment; daemon
// plugins instantiate invisibly once enabled.
Column {
    id: root

    property real contentW: 300

    width: contentW
    spacing: Theme.sp3

    Text {
        text: "PLUGINS"
        color: Theme.ink
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsDisplay
        font.weight: Font.ExtraBold
        font.letterSpacing: 3
    }

    Text {
        width: parent.width
        text: "external qml extensions from " + PluginService.pluginsRoot + " — drop a folder with plugin.json and rescan"
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
        wrapMode: Text.WordWrap
    }

    YSection {
        width: parent.width
        index: "01"
        label: "Installed"
        chip: PluginService.scanning ? "SCANNING" : PluginService.manifests.length + " FOUND"
    }

    YButton {
        label: PluginService.scanning ? "scanning…" : "scan for plugins"
        tone: "acid"
        onClicked: PluginService.scan()
    }

    Text {
        visible: PluginService.lastScanError.length > 0
        width: parent.width
        text: PluginService.lastScanError
        color: Theme.alert
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
        wrapMode: Text.WordWrap
    }

    // empty state
    Text {
        visible: !PluginService.scanning && PluginService.manifests.length === 0
        width: parent.width
        text: "no plugins found"
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
        font.letterSpacing: 2
    }

    Column {
        width: parent.width
        spacing: 4

        Repeater {
            model: PluginService.manifests

            YRow {
                id: prow

                required property var modelData

                readonly property bool plOn: PluginService.isEnabled(modelData.id)

                width: parent.width
                title: modelData.name
                sub: modelData.id + " · v" + modelData.version + (modelData.author.length > 0 ? " · " + modelData.author : "")
                note: modelData.description + (modelData.permissions.length > 0 ? "  [" + modelData.permissions.join(",") + "]" : "")
                on_: prow.plOn
                trailingW: 68
                onToggled: PluginService.setEnabled(modelData.id, !prow.plOn)

                YSwitch {
                    id: psw

                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    checked: prow.plOn
                    onToggled: PluginService.setEnabled(prow.modelData.id, !prow.plOn)
                }

                YChip {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: psw.left
                    anchors.rightMargin: Theme.sp2
                    visible: prow.modelData.type === "daemon" && prow.plOn && (prow.modelData.id in PluginService.daemons)
                    label: "LIVE"
                    tone: "acid"
                }
            }
        }
    }

    YSection {
        width: parent.width
        index: "02"
        label: "Notes"
    }

    Text {
        width: parent.width
        text: "widget plugins render in the bar's PLUGIN WIDGETS segment (BAR tab). daemon plugins run at boot. loading a plugin executes its code — only install ones you trust."
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
        wrapMode: Text.WordWrap
    }
}
