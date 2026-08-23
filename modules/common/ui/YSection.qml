import QtQuick
import qs.theme

// Section header: index glyph + title + flex rule + optional trailing chip.
// `reveal()` lets a cascade pass draw the rule left→right after the section
// fades in — structure assembling itself.
Item {
    id: root

    property string index: ""
    property string label: ""
    property string chip: ""

    implicitWidth: 300
    implicitHeight: 22

    function reveal() {
        ruleScale.xScale = 0;
        revealAnim.restart();
    }

    SequentialAnimation {
        id: revealAnim

        PauseAnimation {
            duration: 60
        }
        NumberAnimation {
            target: ruleScale
            property: "xScale"
            to: 1
            duration: Theme.movSlow
            easing.type: Easing.OutCubic
        }
    }

    Text {
        id: idx

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        visible: root.index.length > 0
        text: root.index
        color: Theme.acid
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsMicro
        font.weight: Font.Bold
    }

    Text {
        id: title

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.index.length > 0 ? 18 : 0
        text: root.label.toUpperCase()
        color: Theme.muted
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsLabel
        font.weight: Font.Bold
        font.letterSpacing: 2.5
    }

    Rectangle {
        id: rule

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: title.right
        anchors.leftMargin: Theme.sp2
        anchors.right: chipText.visible ? chipText.left : parent.right
        anchors.rightMargin: chipText.visible ? Theme.sp2 : 0
        height: 1
        color: Theme.hairline
        transform: Scale {
            id: ruleScale

            origin.x: 0
            origin.y: 0
            xScale: 1
        }
    }

    Text {
        id: chipText

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        visible: root.chip.length > 0
        text: root.chip.toUpperCase()
        color: Theme.faint
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fsMicro
        font.letterSpacing: 1
    }
}
