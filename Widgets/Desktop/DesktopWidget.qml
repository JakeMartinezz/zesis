pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "./"
import "../../"

// Small WlrLayer.Bottom surface positioned anywhere on screen, fully click-through.
// In config mode this surface hides, DesktopConfigOverlay renders a draggable proxy
// instead, then writes the new position back to DesktopWidgetStore on drag end.
PanelWindow {
    id: root

    property string storeKey: ""
    property Component content: null

    property real _nx: 0.5
    property real _ny: 0.5

    // Reactive bg config, re-evaluates whenever _positions changes.
    property var _bgConfig: {
        var _ = DesktopWidgetStore._positions;
        return DesktopWidgetStore.getBgConfig(root.storeKey);
    }
    property bool _hasBg: _bgConfig.enabled
    readonly property real _bgPad: _hasBg ? Math.round(10 * UIScale.value) : 0

    // User-set fixed size, independent per axis. 0 = auto (content's own implicit size).
    // Forcing a size here is what lets a container-aware component (e.g. WeatherDisplay)
    // actually reflow instead of just being centered at its natural size in a bigger window.
    property var _size: {
        var _ = DesktopWidgetStore._positions;
        return DesktopWidgetStore.getSize(root.storeKey);
    }
    readonly property bool _overrideW: _size.w > 0
    readonly property bool _overrideH: _size.h > 0

    property real _marginLeft: _nx * Math.max(0, screen.width - implicitWidth)
    property real _marginTop: _ny * Math.max(0, screen.height - implicitHeight)

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.namespace: "zesis:desktop:" + storeKey

    anchors {
        top: true
        left: true
    }
    margins {
        top: Math.round(root._marginTop)
        left: Math.round(root._marginLeft)
    }

    implicitWidth: (root._overrideW ? root._size.w : contentLoader.implicitWidth) + root._bgPad * 2
    implicitHeight: (root._overrideH ? root._size.h : contentLoader.implicitHeight) + root._bgPad * 2

    exclusiveZone: -1
    color: "transparent"

    Region {
        id: clickThrough
    }
    mask: clickThrough

    visible: !DesktopWidgetStore.configMode

    DesktopWidgetBg {
        anchors.fill: parent
        bgConfig: root._bgConfig
    }

    // width/height stay bound always, see docs/qml-patterns.md #2 for why
    Loader {
        id: contentLoader
        anchors.centerIn: parent
        sourceComponent: root.content
        width: root._overrideW ? root._size.w : (item?.implicitWidth ?? 0)
        height: root._overrideH ? root._size.h : (item?.implicitHeight ?? 0)
    }

    // Re-read position from store when config mode exits (overlay may have moved us).
    Connections {
        target: DesktopWidgetStore // qmllint disable incompatible-type
        function onConfigModeChanged() {
            if (!DesktopWidgetStore.configMode) {
                var pos = DesktopWidgetStore.getPos(root.storeKey);
                root._nx = pos.nx;
                root._ny = pos.ny;
            }
        }
    }

    Component.onCompleted: {
        var pos = DesktopWidgetStore.getPos(root.storeKey);
        root._nx = pos.nx;
        root._ny = pos.ny;
        DesktopWidgetStore.register(root.storeKey, root.content);
    }

    Component.onDestruction: {
        DesktopWidgetStore.unregister(root.storeKey);
    }
}
