import QtQuick
import "../shared"
import "../../"

// Bar item: mode icon + target temperature. Holds the service only while the popup
// is open; otherwise it shows the last known state, dimmed when it may be stale.
DeviceBarItem {
    id: root

    readonly property var svc: AirconService
    readonly property color tint: svc.modeColor(svc.mode, svc.power && svc.online)

    service: AirconService
    available: root.svc.errorCode !== "no_openssl"
    popupHeight: Math.round(780 * UIScale.value) // room for the card with "more options" open
    rowOpacity: root.svc.live || !root.svc.hasState ? 1 : 0.6
    card: Component {
        AirconCard {}
    }

    Text {
        id: icon
        anchors.verticalCenter: parent.verticalCenter
        text: root.svc.power ? (root.svc.modeInfo(root.svc.mode)?.icon ?? root.svc.acIcon) : root.svc.acIcon
        font.pixelSize: Math.round(15 * UIScale.value)
        color: root.hot ? Colors.accent : root.tint
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
        // One turn on a power/mode transition, then static.
        RotationAnimation on rotation {
            id: spin
            running: false
            from: 0
            to: 360
            duration: Anim.morph
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Anim.emphasizedDecel
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.svc.power && root.svc.hasState
        text: root.svc.targetTemp + "°"
        font.pixelSize: UIScale.fontSmall
        color: root.hot ? Colors.accent : Colors.text
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.svc.hasState && !root.svc.online
        text: String.fromCodePoint(0xF05AA) // md-wifi_off
        font.pixelSize: UIScale.fontSmall
        color: Colors.muted
    }

    Connections {
        target: root.svc
        function onPowerChanged() {
            if (!root.svc.hasState)
                return;
            spin.restart();
        }
        function onModeChanged() {
            if (!root.svc.hasState)
                return;
            if (root.svc.power)
                spin.restart();
        }
    }
}
