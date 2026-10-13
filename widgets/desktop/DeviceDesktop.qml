import QtQuick
import "../shared"

// Desktop wrapper for a device card (aircon, Tapo light): holds `service` only while
// the desktop under it is visible. The card goes in as the only child.
Item {
    id: root

    property var hostScreen: null
    property QtObject service: null
    default property alias card: holder.data

    implicitWidth: holder.children.length > 0 ? holder.children[0].implicitWidth : 0
    implicitHeight: holder.children.length > 0 ? holder.children[0].implicitHeight : 0

    DesktopVisibility {
        id: desktop
        screen: root.hostScreen
    }

    ServiceHold {
        service: root.service
        active: desktop.uncovered
    }

    Item {
        id: holder
        anchors.fill: parent
    }
}
