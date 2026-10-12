import QtQuick
import "../wm"

// Desktop wrapper: holds the aircon service only while the desktop under it is
// actually visible, i.e. the active workspace on this screen has no windows.
// ponytail: any window (even a small floating one) counts as covering the desktop;
// check window geometry against this widget's rect if that proves too eager.
Item {
    id: root

    property var hostScreen: null
    readonly property var _ws: hostScreen ? WmService.activeWorkspaceFor(hostScreen) : null
    // Same per-workspace window list WorkspaceGrid uses for its "empty" tile state.
    readonly property bool desktopVisible: _ws !== null && _ws.toplevels.values.length === 0

    implicitWidth: card.implicitWidth
    implicitHeight: card.implicitHeight

    AirconHold {
        active: root.desktopVisible
    }

    AirconCard {
        id: card
        anchors.fill: parent
        compact: true
    }
}
