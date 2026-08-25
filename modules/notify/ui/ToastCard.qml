import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs.theme
import qs.modules.common
import "../"
import "../../common/ui"

Rectangle {
    id: root

    // owned by ToastStack's ObjectModel (created imperatively per toast) —
    // entry is the stable Notify Entry this card renders
    property var entry: null
    property int staggerMs: 0

    readonly property bool critical: entry ? entry.urg === 2 : false
    readonly property color edge: critical ? Theme.alert : Theme.hairline
    readonly property real frac: entry && entry.durMs > 0 && !entry.persistent ? Math.max(0, Math.min(1, entry.remainMs / entry.durMs)) : 1

    width: 380
    height: contentCol.height + 2 * Theme.sp3
    color: Theme.bgAlt
    border.width: 1
    border.color: edge
    opacity: 0

    // entrance: drop from behind the bar line, stacked cards trail in
    y: -(root.height + 12)
    Behavior on y {
        enabled: root.entry && !root.entry.leaving
        NumberAnimation {
            duration: Theme.movSlow
            easing.type: Easing.OutCubic
        }
    }

    Behavior on opacity {
        enabled: root.entry && !root.entry.leaving
        NumberAnimation {
            duration: Theme.movMed
            easing.type: Easing.OutCubic
        }
    }

    // acid border flash on arrival, then cool to the final edge color
    SequentialAnimation {
        id: borderFlash

        running: false

        ColorAnimation {
            target: root
            property: "border.color"
            to: Theme.acid
            duration: 120
        }
        PauseAnimation {
            duration: 180
        }
        ColorAnimation {
            target: root
            property: "border.color"
            to: root.edge
            duration: Theme.movMed
        }
    }

    Timer {
        id: enterT

        interval: root.staggerMs
        onTriggered: {
            root.opacity = 1;
            root.y = 0;
            borderFlash.start();
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
        target: root.entry

        ignoreUnknownSignals: true

        function onLeavingChanged() {
            if (root.entry && root.entry.leaving)
                exitAnim.start();
        }
    }

    Component.onCompleted: {
        if (entry)
            entry.paused = Qt.binding(() => area.containsMouse);
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
                scale: 1

                onVisibleChanged: {
                    if (visible)
                        iconBounce.restart();
                }

                SequentialAnimation {
                    id: iconBounce

                    running: false

                    NumberAnimation {
                        target: appIcon.parent
                        property: "scale"
                        from: 0.3
                        to: 1.15
                        duration: Theme.movFast
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.5
                    }
                    NumberAnimation {
                        target: appIcon.parent
                        property: "scale"
                        from: 1.15
                        to: 1.0
                        duration: Theme.movSnap
                        easing.type: Easing.OutBack
                        easing.overshoot: 0.3
                    }
                }

                IconImage {
                    id: appIcon

                    anchors.fill: parent
                    implicitSize: 22
                    visible: Notify.fields.icon && status === Image.Ready
                    source: Notify.fields.icon && root.entry.icon.length > 0 ? Quickshell.iconPath(root.entry.icon) : ""
                }

                Text {
                    anchors.centerIn: parent
                    visible: !appIcon.visible
                    text: root.entry.app.charAt(0).toUpperCase()
                    color: Theme.acid
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fsBody
                    font.weight: Font.DemiBold
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: Notify.fields.app
                text: root.entry.app.toUpperCase()
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
            visible: root.entry.sum.length > 0
            text: root.entry.sum.replace(/\n/g, " ")
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
            visible: Notify.fields.body && root.entry.body.length > 0
            text: root.entry.body.replace(/\n/g, " ").replace(/<[^>]*>/g, "")
            color: Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBody
            elide: Text.ElideRight
            maximumLineCount: 4
            wrapMode: Text.Wrap
        }

        Row {
            spacing: Theme.sp1
            visible: ShellState.notifyActions && root.entry.acts.length > 0

            Repeater {
                model: ShellState.notifyActions ? root.entry.acts.slice(0, 3) : []

                delegate: YButton {
                    required property var modelData

                    // server-supplied labels can be arbitrarily long — cap so
                    // three actions can never run the row past the card edge
                    width: Math.min(implicitWidth, 120)
                    label: modelData.text.toUpperCase()
                    onClicked: Notify.invokeAction(root.entry.id, modelData.id)
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
            // retire (animated send-off) not dismiss (instant destroy)
            onClicked: Notify.retire(root.entry.id)
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }
}
