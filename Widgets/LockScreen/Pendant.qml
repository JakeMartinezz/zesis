import QtQuick
import "../../"

Canvas {
    id: root

    property color ink: Colors.text
    property real alpha: 0.28
    property real diamondRelPos: 0.58  // 0-1 along the line height
    property real diamondW: 5          // UIScale units
    property real diamondH: 14         // UIScale units
    property real beadR: 5             // UIScale units, 0 to omit

    readonly property real _s: UIScale.value

    implicitWidth: Math.round((diamondW + 8) * _s) * 2 + 1

    onInkChanged: requestPaint()
    onAlphaChanged: requestPaint()
    onDiamondRelPosChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        var s = _s;
        var cx = width / 2;

        ctx.strokeStyle = Qt.rgba(ink.r, ink.g, ink.b, alpha);
        ctx.fillStyle = Qt.rgba(ink.r, ink.g, ink.b, alpha);
        ctx.lineWidth = 1;

        ctx.beginPath();
        ctx.moveTo(cx, 0);
        ctx.lineTo(cx, height);
        ctx.stroke();

        var amid = height * diamondRelPos;
        var aw = Math.round(diamondW * s);
        var ah = Math.round(diamondH * s);
        ctx.beginPath();
        ctx.moveTo(cx, amid - ah);
        ctx.lineTo(cx + aw, amid);
        ctx.lineTo(cx, amid + ah);
        ctx.lineTo(cx - aw, amid);
        ctx.closePath();
        ctx.fill();

        if (beadR > 0) {
            var br = Math.round(beadR * s);
            ctx.beginPath();
            ctx.arc(cx, height, br, 0, 2 * Math.PI);
            ctx.fill();
        }
    }
}
