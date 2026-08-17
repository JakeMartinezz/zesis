import QtQuick
import "../../"

// Pill-shaped level bar, styled after AGS's "regular" battery bar: one static,
// vibrant green (AGS's $charging-bg) fill, proportional to charge. A single
// continuous fill rectangle rather than discrete blocks - blocks of equal
// color with fractional pixel widths (from UIScale) left a visible seam at
// their boundary, so there was nothing gained from segmenting them.
Item {
    id: root

    implicitWidth: Math.round(50 * UIScale.value)
    implicitHeight: Math.round(12 * UIScale.value)

    readonly property bool _low: BatteryService.percent <= 30 && !BatteryService.charging && !BatteryService.full
    readonly property color _fillColor: root._low ? "#c01c28" : "#00D787"
    readonly property real _fillFraction: Math.max(0, Math.min(100, BatteryService.percent)) / 100

    Rectangle {
        id: trough
        anchors.fill: parent
        radius: height / 2
        color: Colors.withAlpha(Colors.text, 0.05)
        clip: true

        Rectangle {
            width: trough.width * root._fillFraction
            height: trough.height
            radius: trough.radius
            color: root._fillColor

            Behavior on width {
                NumberAnimation {
                    duration: Anim.medium
                    easing.type: Easing.InOutCubic
                }
            }
            Behavior on color {
                ColorAnimation {
                    duration: Anim.fast
                }
            }
        }
    }
}
