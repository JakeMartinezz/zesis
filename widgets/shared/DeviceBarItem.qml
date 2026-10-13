import QtQuick
import "../../"

// Bar item for a smart-home device (aircon, Tapo light...): the panel-button box, a
// click-to-toggle popup holding `card`, and a ServiceHold that keeps `service` polling
// only while that popup is open. Children go into the centered row.
Item {
    id: root

    property QtObject service: null
    property Component card: null
    property real popupHeight: Math.round(700 * UIScale.value)
    // Same meaning as BarButton.bare: drop our own box when bundled in SystemIndicators.
    property bool bare: false
    property bool available: true
    property alias rowOpacity: barRow.opacity
    readonly property bool hot: mouseArea.containsMouse || popup.visible
    default property alias content: barRow.data

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
    }

    ServiceHold {
        service: root.service
        active: popup.visible
    }

    AnimatedPopup {
        id: popup
        anchorItem: root
        implicitWidth: Math.round(340 * UIScale.value)
        implicitHeight: root.popupHeight // room for the card at its tallest
        fitContent: true
        content: root.card
    }
}
