import QtQuick
import qs.theme
import qs.modules.common
import "../../common/ui"

// One template registry row from Wallpaper.templatesList():
// {id,label,group,output,enabled,custom,installed,snippet}.
// YRow with a switch; hover swaps the output path for the install hint (or
// the auto-snippet target when the shell can wire the app itself). Absent
// apps show an ABSENT chip and a dead switch. Custom rows get USER + delete.
YRow {
    id: row

    required property var modelData

    readonly property bool custom: modelData?.custom ?? false
    readonly property bool installed: modelData?.installed ?? true
    readonly property var snippet: modelData?.snippet ?? null

    title: String(modelData?.label ?? "")
    sub: String(modelData?.output ?? "")
    note: snippet ? "auto-snippet → " + snippet.file.split("/").pop() : String(modelData?.note ?? "")
    on_: modelData?.enabled ?? false
    interactive: false
    clip: true
    trailingW: row.custom ? 150 : 96

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.sp2

        YChip {
            visible: !row.installed
            label: "ABSENT"
            tone: "alert"
            anchors.verticalCenter: parent.verticalCenter
        }

        YChip {
            visible: row.custom
            label: "USER"
            tone: "acid"
            anchors.verticalCenter: parent.verticalCenter
        }

        Item {
            visible: row.custom
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 16

            Text {
                anchors.centerIn: parent
                text: "×"
                color: delArea.containsMouse ? Theme.alert : Theme.faint
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsTitle
            }

            MouseArea {
                id: delArea

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Wallpaper.removeTemplate(row.modelData.id)
            }
        }

        YSwitch {
            checked: row.on_
            enabled: row.installed
            opacity: row.installed ? 1 : 0.35
            anchors.verticalCenter: parent.verticalCenter
            onToggled: Wallpaper.setTemplateEnabled(row.modelData.id, !row.modelData.enabled)
        }
    }
}
