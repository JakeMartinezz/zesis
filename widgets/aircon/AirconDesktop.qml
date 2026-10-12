import QtQuick
import "../desktop"

// Desktop wrapper: holds the aircon service only while the desktop under it is visible.
Item {
    id: root

    property var hostScreen: null

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    DesktopVisibility {
        id: desktop
        screen: root.hostScreen
    }

    AirconHold {
        active: desktop.uncovered
    }

    AirconCard {
        id: card
        anchors.fill: parent
        compact: true
    }
}
