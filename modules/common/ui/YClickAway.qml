import QtQuick

// YClickAway — fullscreen transparent click-catcher for floating surfaces.
// Declare it as the FIRST child of a panel's content root, with the card
// (YSurface) after it: the card's own swallow MouseArea keeps clicks inside
// the card from reaching here, while any click on the surrounding desktop
// region fires `outsideClicked`. Pair it with a full-window `mask` so the
// whole panel window (not just the card) accepts input while open.
MouseArea {
    id: root

    signal outsideClicked()

    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: mouse => {
        mouse.accepted = true;
        root.outsideClicked();
    }
}
