import QtQuick

// Drop-in child of any Flickable/GridView/ListView: snappy mouse-wheel
// scrolling. The default Flickable wheel handling crawls; this steps ~3 rows
// per notch with hard clamping and stays out of touchpad pixel gestures.
WheelHandler {
    id: handler

    readonly property var flick: parent
    property real notchStep: 132

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    acceptedModifiers: Qt.NoModifier
    activeTimeout: 0.4

    onWheel: event => {
        const f = handler.flick;
        if (!f || f.contentHeight <= f.height + 4) {
            event.accepted = false;
            return;
        }
        const max = Math.max(0, f.contentHeight - f.height);
        f.contentY = Math.max(-f.originY, Math.min(max - f.bottomMargin, f.contentY - event.angleDelta.y / 120 * handler.notchStep));
        event.accepted = true;
    }
}
