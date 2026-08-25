import QtQuick
import qs.theme

// YSpark — a rolling bar sparkline (PH.15 SYSTEM tab). Push samples with
// push(0..1); it keeps the last `maxSamples` and repaints only on push (or
// color change), so there's no per-frame cost. Bars turn alert past
// `hotThreshold`.
Canvas {
    id: root

    property var samples: []
    property int maxSamples: 48
    property real hotThreshold: 0.85
    property color barColor: Theme.acid
    property color hotColor: Theme.alert

    function push(v) {
        const c = Math.max(0, Math.min(1, v));
        root.samples = root.samples.concat([c]);
        if (root.samples.length > root.maxSamples)
            root.samples = root.samples.slice(root.samples.length - root.maxSamples);
        root.requestPaint();
    }

    onBarColorChanged: root.requestPaint()
    onHotColorChanged: root.requestPaint()
    onWidthChanged: root.requestPaint()
    onHeightChanged: root.requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, root.width, root.height);
        const n = root.samples.length;
        if (n === 0 || root.width < 2 || root.height < 2)
            return;
        const bw = root.width / root.maxSamples;
        for (let i = 0; i < n; i++) {
            const v = root.samples[i];
            const h = Math.max(1, v * root.height);
            const x = Math.floor(i * bw);
            const barW = Math.max(1, bw - 1);
            const baseColor = v >= root.hotThreshold ? root.hotColor : root.barColor;
            // gradient: full opacity at the tip, fading to transparent at the base
            const grad = ctx.createLinearGradient(x, root.height, x, root.height - h);
            grad.addColorStop(0, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.15));
            grad.addColorStop(1, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.95));
            ctx.fillStyle = grad;
            ctx.fillRect(x, root.height - h, barW, h);
            // peak glow: brighter cap at the very top of each bar
            if (v > 0.1) {
                const capGrad = ctx.createLinearGradient(x, root.height - h, x, root.height - h - 3);
                capGrad.addColorStop(0, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.7));
                capGrad.addColorStop(1, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0));
                ctx.fillStyle = capGrad;
                ctx.fillRect(x - 1, root.height - h - 3, barW + 2, 4);
            }
        }
    }
}
