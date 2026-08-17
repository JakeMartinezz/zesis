pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../bar"
import "../wm"
import "../../"

// Taskbar pill. Groups open windows by appId,
// shows one icon per app with macOS-style dots and a hover popup.
Item {
    id: root

    readonly property int _itemSz: Math.round(30 * UIScale.value)
    readonly property int _gap: Math.round(2 * UIScale.value)
    readonly property int _padH: Math.round(8 * UIScale.value)

    // Deduplicated list of appIds from open toplevels, ordered by monitor
    // position (left-to-right) then workspace id - previously this was
    // straight open order, which didn't track a multi-monitor layout at
    // all. Mirrors the AGS reference taskbar's own sort (by
    // client.workspace.id), keyed off monitor.x first since that's the
    // actual "monitor position order" being matched here.
    //
    // ToplevelManager.toplevels (Quickshell.Wayland, protocol-level) stays
    // the source of which appIds actually exist right now, since it's
    // always live. The per-monitor/workspace sort key comes from
    // WmService.toplevels (Hyprland-specific) instead, matched by appId -
    // that list needs an explicit refresh to stay current, so an appId
    // missing from it just falls back to open order rather than vanishing.
    readonly property var _appIds: {
        var seen = {};
        var order = [];
        var arr = ToplevelManager.toplevels.values;
        for (var i = 0; i < arr.length; i++) {
            var t = arr[i];
            if (!t.appId)
                continue;
            var key = t.appId.toLowerCase();
            if (!seen[key]) {
                seen[key] = true;
                order.push(t.appId);
            }
        }

        var sortKey = {};
        var hypr = WmService.toplevels;
        for (var j = 0; j < hypr.length; j++) {
            var h = hypr[j];
            var appId = h.wayland ? h.wayland.appId : "";
            if (!appId)
                continue;
            var hkey = appId.toLowerCase();
            var mx = h.monitor ? h.monitor.x : 0;
            var wsId = h.workspace ? h.workspace.id : 0;
            if (!(hkey in sortKey) || mx < sortKey[hkey][0] || (mx === sortKey[hkey][0] && wsId < sortKey[hkey][1]))
                sortKey[hkey] = [mx, wsId];
        }

        order.sort((a, b) => {
            var ka = sortKey[a.toLowerCase()];
            var kb = sortKey[b.toLowerCase()];
            if (!ka && !kb)
                return 0;
            if (!ka)
                return 1;
            if (!kb)
                return -1;
            if (ka[0] !== kb[0])
                return ka[0] - kb[0];
            return ka[1] - kb[1];
        });
        return order;
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
