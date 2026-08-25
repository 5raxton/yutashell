import QtQuick
import qs.theme
import "."

// The workhorse setting row: left status tick, title + sub, trailing slot.
// Trailing is whatever you declare inside (YSwitch, YChip, custom) — anchor
// it right yourself. Whole row clicks through `toggled()` when interactive.
Item {
    id: root

    property string title: ""
    property string sub: ""
    // swap the sub line for `note` while hovered — install hints without clutter
    property string note: ""
    property bool on_: false
    property bool interactive: true

    // Trailing slot for switches/chips/custom controls. Width comes from
    // `trailingW` (set by the consumer) — NEVER from childrenRect, which goes
    // binding-loop when children anchor to the host.
    property real trailingW: 34

    signal toggled()

    readonly property bool hovered: area.containsMouse

    implicitWidth: 300
    implicitHeight: Theme.rowH

    // hover fill wipes in from the left — the machine acknowledging you
    Rectangle {
        id: hoverFill

        anchors.fill: parent
        color: Theme.surface
        opacity: root.interactive && hovered ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }
    }

    // left accent bar slides in on hover — acid edge acknowledging presence
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: root.on_ ? Theme.acid : "transparent"
        scale: root.interactive && hovered ? 1 : 0.35
        transformOrigin: Item.TopLeft

        Behavior on scale {
            NumberAnimation {
                duration: Theme.movFast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.movFast
            }
        }

        // interrogation tick: grows to full height under the cursor
        Rectangle {
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            width: parent.width
            height: root.interactive && hovered ? parent.height : parent.height * 0.35
            color: root.on_ ? Qt.lighter(Theme.acid, 1.25) : Theme.lineStrong
            visible: root.interactive || root.on_

            Behavior on height {
                NumberAnimation {
                    duration: Theme.movFast
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Theme.movFast
                }
            }
        }
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Theme.sp3
        anchors.right: trailingHost.left
        anchors.rightMargin: Theme.sp2
        spacing: 2

        Text {
            width: parent.width
            text: root.title
            elide: Text.ElideRight
            color: !root.interactive || root.on_ || hovered ? Theme.ink : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsBody
            font.weight: Font.DemiBold

            Behavior on color {
                ColorAnimation {
                    duration: Theme.movFast
                }
            }
        }

        Text {
            readonly property bool showNote: root.note.length > 0 && hovered

            visible: (showNote ? root.note : root.sub).length > 0
            width: parent.width
            text: showNote ? root.note : root.sub
            elide: showNote ? Text.ElideRight : Text.ElideMiddle
            color: showNote ? Theme.acid : Theme.muted
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fsLabel
            font.letterSpacing: 0.5
            opacity: hovered ? 1 : 0.85

            Behavior on color {
                ColorAnimation {
                    duration: Theme.movFast
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.movFast
                }
            }
        }
    }

    Item {
        id: trailingHost

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Theme.sp3
        width: root.trailingW
        height: Theme.rowH
    }

    default property alias trailing: trailingHost.data

    // Row-wide click/hover surface. STOPS at the trailing slot — switches and
    // buttons living there must receive their own clicks (this used to cover
    // them and silently ate every toggle).
    MouseArea {
        id: area

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: trailingHost.left
        hoverEnabled: true
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: {
            if (root.interactive)
                root.toggled();
        }
    }
}
