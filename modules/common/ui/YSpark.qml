import QtQuick
import qs.theme

// YSpark — a rolling bar sparkline (PH.15 SYSTEM tab). Push samples with
// push(0..1); it keeps the last `maxSamples` and repaints only on push (or
// color change), so there's no per-frame cost. Bars turn alert past
// `hotThreshold`.
Canvas {
    id: root

    property var data: []
    property int maxSamples: 48
    property real hotThreshold: 0.85
    property color barColor: Theme.acid
    property color hotColor: Theme.alert

    function push(v) {
        const c = Math.max(0, Math.min(1, v));
        root.data = root.data.concat([c]);
        if (root.data.length > root.maxSamples)
            root.data = root.data.slice(root.data.length - root.maxSamples);
        root.requestPaint();
    }

    onBarColorChanged: root.requestPaint()
    onHotColorChanged: root.requestPaint()
    onWidthChanged: root.requestPaint()
    onHeightChanged: root.requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, root.width, root.height);
        const n = root.data.length;
        if (n === 0 || root.width < 2 || root.height < 2)
            return;
        const bw = root.width / root.maxSamples;
        for (let i = 0; i < n; i++) {
            const v = root.data[i];
            const h = Math.max(1, v * root.height);
            ctx.fillStyle = v >= root.hotThreshold ? root.hotColor.toString() : root.barColor.toString();
            ctx.fillRect(Math.floor(i * bw), root.height - h, Math.max(1, bw - 1), h);
        }
    }
}
