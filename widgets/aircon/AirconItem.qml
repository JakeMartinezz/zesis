import QtQuick
import "../shared"
import "../../"

// Bar item: mode icon + target temperature. Holds the service only while the popup
// is open; otherwise it shows the last known state, dimmed when it may be stale.
Item {
    id: root

    readonly property var svc: AirconService
    readonly property color tint: svc.modeColor(svc.mode, svc.power && svc.online)
    readonly property bool _hot: mouseArea.containsMouse || popup.visible

    // Same meaning as BarButton.bare: drop our own box when bundled in SystemIndicators.
    property bool bare: false
    readonly property bool available: root.svc.errorCode !== "no_openssl"
    visible: root.available

    implicitWidth: barRow.implicitWidth + Math.round((bare ? 10 : 14) * UIScale.value)
    implicitHeight: Math.round(26 * UIScale.value)

    // Resting tint - persistent panel-button box (AGS flatButtons:false parity)
    Rectangle {
        anchors.fill: parent
        radius: UIScale.radiusMd
        color: root.bare ? "transparent" : Colors.withAlpha(Colors.text, mouseArea.containsMouse ? 0.14 : 0.05)
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: popup.visible ? popup.close() : popup.open()
    }

    Row {
        id: barRow
        anchors.centerIn: parent
        spacing: Math.round(5 * UIScale.value)
        opacity: root.svc.live || !root.svc.hasState ? 1 : 0.6

        Text {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            text: root.svc.power ? (root.svc.modeInfo(root.svc.mode)?.icon ?? root.svc.acIcon) : root.svc.acIcon
            font.pixelSize: Math.round(15 * UIScale.value)
            color: root._hot ? Colors.accent : root.tint
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
            color: root._hot ? Colors.accent : Colors.text
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.svc.hasState && !root.svc.online
            text: String.fromCodePoint(0xF05AA) // md-wifi_off
            font.pixelSize: UIScale.fontSmall
            color: Colors.muted
        }
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

    AirconHold {
        active: popup.visible
    }

    AnimatedPopup {
        id: popup
        anchorItem: root
        implicitWidth: Math.round(340 * UIScale.value)
        implicitHeight: Math.round(780 * UIScale.value) // room for the card with "more options" open
        fitContent: true
        content: Component {
            AirconCard {}
        }
    }
}
