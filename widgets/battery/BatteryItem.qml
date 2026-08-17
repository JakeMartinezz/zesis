import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import "../../"
import "../bar"
import "../shared"

Item {
    id: root

    readonly property bool available: BatteryService.available
    visible: root.available

    implicitWidth: contentRow.implicitWidth + Math.round(14 * UIScale.value)
    implicitHeight: Math.round(26 * UIScale.value)

    // Resting tint - persistent panel-button box (AGS flatButtons:false parity)
    Rectangle {
        anchors.fill: parent
        radius: UIScale.radiusMd
        color: Colors.withAlpha(Colors.text, (mouseArea.containsMouse || popup.visible) ? 0.14 : 0.05)
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }

    // Right-click toggles the percentage label, like AGS's on_clicked (there
    // it's the primary click since AGS has no popup; here left-click is
    // already taken by the details popup, so the reveal toggle moves to right-click).
    // Starts hidden - only shown after the user explicitly reveals it.
    property bool _showPercent: false

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: function (mouse) {
            if (mouse.button === Qt.RightButton)
                root._showPercent = !root._showPercent;
            else
                popup.visible ? popup.close() : popup.open();
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: Math.round(5 * UIScale.value)

        // Charging/full icon - the exact AGS asset (battery-flash-symbolic), tinted to match
        Item {
            anchors.verticalCenter: parent.verticalCenter
            visible: BatteryService.charging || BatteryService.full
            width: Math.round(14 * UIScale.value)
            height: Math.round(14 * UIScale.value)

            IconImage {
                id: chargeIcon
                visible: false
                anchors.fill: parent
                // IconImage's `source` alias resolves plain relative strings against its
                // OWN file's location, not the caller's - Qt.resolvedUrl() sidesteps that
                // by resolving here, at this file, before the string ever reaches the alias.
                source: Qt.resolvedUrl("../../Assets/battery-flash-symbolic.svg")
            }

            MultiEffect {
                anchors.fill: chargeIcon
                source: chargeIcon
                colorization: 1.0
                colorizationColor: "#00D787"
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: !(BatteryService.charging || BatteryService.full)
            text: BatteryService.icon
            font.pixelSize: Math.round(14 * UIScale.value)
            color: BatteryService.percent <= 30 ? "#c01c28" : Colors.text
            Behavior on color {
                ColorAnimation {
                    duration: Anim.fast
                }
            }
        }

        // Slide-collapse reveal, like AGS's Revealer(transition: "slide_right")
        Item {
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            implicitWidth: root._showPercent ? percentText.implicitWidth : 0
            implicitHeight: percentText.implicitHeight

            // Same plain, no-overshoot curve MusicChip.qml already uses for its
            // reveal - stop guessing at custom bezier curves that keep producing
            // a jump/delay in one direction or the other.
            Behavior on implicitWidth {
                NumberAnimation {
                    duration: Anim.medium
                    easing.type: Easing.InOutCubic
                }
            }

            Text {
                id: percentText
                text: BatteryService.percent + "%"
                font.pixelSize: UIScale.fontSmall
                color: Colors.text
            }
        }

        BatteryBar {
            id: batteryBar
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    AnimatedPopup {
        id: popup
        anchorItem: root
        implicitWidth: Math.round(280 * UIScale.value)
        implicitHeight: Math.round(300 * UIScale.value)
        content: Component {
            Battery {}
        }
    }
}
