import QtQuick
import qs.theme
import qs.modules.common
import "../../common/ui"

// One template registry row from Wallpaper.templatesList():
// {id,label,group,output,enabled,custom}. YRow with a switch; hover swaps the
// output path for the install hint. Custom rows get a USER chip + delete ×.
YRow {
    id: row

    required property var modelData

    readonly property bool custom: modelData?.custom ?? false

    title: String(modelData?.label ?? "")
    sub: String(modelData?.output ?? "")
    note: String(modelData?.note ?? "")
    on_: modelData?.enabled ?? false
    interactive: false
    clip: true
    trailingW: row.custom ? 112 : 40

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.sp2

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
            anchors.verticalCenter: parent.verticalCenter
            onToggled: Wallpaper.setTemplateEnabled(row.modelData.id, !row.modelData.enabled)
        }
    }
}
