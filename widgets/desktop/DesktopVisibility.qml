import QtQuick
import "../wm"

// Whether the desktop under a desktop widget is actually showing: the active workspace
// on `screen` has no windows (same per-workspace window list WorkspaceGrid uses for its
// "empty" tile state). Widgets use it to stop polling/animating while covered.
// ponytail: any window (even a small floating one) counts as covering the desktop;
// check window geometry against the widget's rect if that proves too eager.
QtObject {
    property var screen: null
    readonly property var _ws: screen ? WmService.activeWorkspaceFor(screen) : null
    readonly property bool uncovered: _ws !== null && _ws.toplevels.values.length === 0
}
