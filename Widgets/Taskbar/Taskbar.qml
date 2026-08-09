pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../Bar"
import "../../"

// Taskbar pill. Groups open windows by appId,
// shows one icon per app with macOS-style dots and a hover popup.
Item {
    id: root

    readonly property int _itemSz: Math.round(30 * UIScale.value)
    readonly property int _gap: Math.round(2 * UIScale.value)
    readonly property int _padH: Math.round(8 * UIScale.value)

    // Deduplicated, ordered list of appIds from open toplevels
    readonly property var _appIds: {
        var seen = {};
        var result = [];
        var arr = ToplevelManager.toplevels.values;
        for (var i = 0; i < arr.length; i++) {
            var t = arr[i];
            if (!t.appId)
                continue;
            var key = t.appId.toLowerCase();
            if (!seen[key]) {
                seen[key] = true;
                result.push(t.appId);
            }
        }
        return result;
    }

    readonly property int _pillLength: _appIds.length > 0 ? _appIds.length * (_itemSz + _gap) - _gap + _padH * 2 : 0
    readonly property int _pillThickness: Math.round(34 * UIScale.value)

    visible: _appIds.length > 0
    // No Behavior, PanelWindow gets the final size immediately (no per-frame Wayland surface resize)
    implicitWidth: _pillLength
    implicitHeight: _pillThickness

    // No background/radius of its own - sits flush on the bar's continuous
    // surface, like AGS's taskbar (each icon carries its own panel-button tint).
    Item {
        id: pillRect
        anchors.centerIn: parent
        clip: true

        width: root._pillLength
        height: root._pillThickness

        Behavior on width {
            NumberAnimation {
                duration: Anim.medium
                easing.type: Easing.OutCubic
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Anim.medium
                easing.type: Easing.OutCubic
            }
        }

        Grid {
            anchors.centerIn: parent
            columns: root._appIds.length
            rows: 1
            spacing: root._gap

            Repeater {
                model: root._appIds
                delegate: TaskbarItem {
                    required property string modelData
                    appId: modelData
                    itemSize: root._itemSz
                }
            }
        }
    }
}
