import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.theme
import qs.modules.common
import "../"
import "../../common/ui"

Rectangle {
    id: root

    required property var modelData // Notify Entry
    required property int index

    readonly property bool critical: modelData.urg === 2
    readonly property color edge: critical ? Theme.alert : Theme.hairline
    readonly property real frac: (modelData.durMs > 0 && !modelData.persistent) ? Math.max(0, Math.min(1, modelData.remainMs / modelData.durMs)) : 1

    width: 380
    height: contentCol.height + 2 * Theme.sp3
    color: Theme.bgAlt
    border.width: 1
    border.color: edge
    opacity: 0

    // entrance: drop from behind the bar line, stacked cards trail in
    y: -(root.height + 12)
    Behavior on y {
        enabled: !root.modelData.leaving
        NumberAnimation {
            duration: Theme.movSlow
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        enabled: !root.modelData.leaving
        NumberAnimation {
            duration: Theme.movMed
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: enterT

        interval: Math.min(root.index, 6) * 70
        onTriggered: {
            root.opacity = 1;
            root.y = 0;
        }
    }

    ParallelAnimation {
        id: exitAnim

        NumberAnimation {
            target: root
            property: "y"
            to: -(root.height + 16)
            duration: 240
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: 200
            easing.type: Easing.InCubic
        }
    }

    Connections {
        target: root.modelData

        function onLeavingChanged() {
            if (root.modelData.leaving)
                exitAnim.start();
        }
    }

    Component.onCompleted: {
        modelData.paused = Qt.binding(() => area.containsMouse);
        enterT.start();
    }

    Column {
        id: contentCol

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.sp3
        spacing: Theme.sp2

        Row {
            spacing: Theme.sp2

            // icon or acid-initials block
            Rectangle {
                width: 22
                height: 22
                color: "transparent"
                visible: Notify.fields.icon

                IconImage {
                    id: appIcon

                    anchors.fill: parent
                    implicitSize: 22
                    visible: Notify.fields.icon && status === Image.Ready
                    source: Notify.fields.icon && root.modelData.icon.length > 0 ? Quickshell.iconPath(root.modelData.icon) : ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    text: root.modelData.app.charAt(0).toUpperCase()
                    color: Theme.acid
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.DemiBold
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Notify.fields.app
                text: root.modelData.app.toUpperCase()
                // cap so a long app name can't push the CRITICAL tag off-card
                width: Math.min(implicitWidth, root.width * 0.6)
                elide: Text.ElideRight
                color: Theme.muted
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.letterSpacing: 1
            }

            Item {
                width: 6
                height: 1
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.critical
                text: "CRITICAL"
                color: Theme.alert
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fsMicro
                font.letterSpacing: 1
            }
        }

        Text {
            width: parent.width
            visible: root.modelData.sum.length > 0
            text: root.modelData.sum.replace(/\n/g, " ")
            color: Theme.ink
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBody
            font.weight: Font.DemiBold
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            visible: Notify.fields.body && root.modelData.body.length > 0
            text: root.modelData.body.replace(/\n/g, " ").replace(/<[^>]*>/g, "")
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBody
            elide: Text.ElideRight
            maximumLineCount: 4
            wrapMode: Text.Wrap
        }

        Row {
            spacing: Theme.sp1
            visible: ShellState.notifyActions && root.modelData.acts.length > 0

            Repeater {
                model: ShellState.notifyActions ? root.modelData.acts : []

                delegate: YButton {
                    required property var modelData

                    label: modelData.text.toUpperCase()
                    onClicked: Notify.invokeAction(root.modelData.id, modelData.id)
                }
            }
        }
    }

    // timeout progress: shrinking acid underline
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        height: 2
        width: parent.width * root.frac
        color: root.critical ? Theme.alert : Theme.acid
    }

    // registration tick
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        width: 1
        height: 14
        color: root.critical ? Theme.alert : Theme.acid
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.sp2
        visible: area.containsMouse
        text: "×"
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsTitle

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: Notify.dismiss(root.modelData.id)
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
