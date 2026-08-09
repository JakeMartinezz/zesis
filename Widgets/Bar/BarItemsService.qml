pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var items: [
        {
            id: "systray",
            label: "System Tray",
            src: "SystrayItems.qml"
        },
        // The repaint of this widget causes 0.6% hits on the CPU in regular intervals
        {
            id: "sysmon",
            label: "System Monitor",
            src: "../SysMon/SysMonItem.qml"
        },
        {
            id: "theme",
            label: "Theme Switcher",
            src: "../ThemeSwitcher/ThemeSwitcherItem.qml"
        },
        {
            id: "keybinds",
            label: "Keybinds",
            src: "../Keybinds/KeybindsItem.qml"
        },
        {
            id: "system",
            label: "System (Bluetooth/Wi-Fi/Sound/Mic)",
            src: "SystemIndicators.qml"
        },
        {
            id: "airpods",
            label: "AirPods",
            src: "../AirPods/AirPods.qml"
        },
        {
            id: "weather",
            label: "Weather",
            src: "../Weather/WeatherItem.qml"
        },
        {
            id: "brightness",
            label: "Brightness",
            src: "../Brightness/BrightnessItem.qml"
        },
        {
            id: "notifications",
            label: "Notifications",
            src: "../Notifications/NotificationsItem.qml"
        },
        {
            id: "config",
            label: "Config",
            src: "../Config/ConfigItem.qml"
        },
        {
            id: "battery",
            label: "Battery",
            src: "../Battery/BatteryItem.qml"
        },
        {
            id: "record",
            label: "Record",
            src: "../Record/RecordItem.qml"
        },
        {
            id: "gitupdate",
            label: "Update Available",
            src: "../GitUpdate/GitUpdateItem.qml"
        },
        {
            id: "settings",
            label: "Settings",
            icon: "󰘮"
        },
        {
            id: "lock",
            label: "Lock",
            icon: "󰌾"
        },
        {
            id: "clock",
            label: "Clock",
            src: "../Clock/ClockItem.qml"
        },
    ]

    property var _state: {
        const s = {};
        for (const item of items)
            s[item.id] = true;
        return s;
    }

    property var order: []

    // ids the user pinned to always sit behind the overflow toggle, regardless
    // of available width - separate from the automatic width-driven collapse
    property var _collapsed: {
        const s = {};
        for (const item of items)
            s[item.id] = false;
        return s;
    }

    // items reordered per the persisted order Any id missing from order
    // (not yet merged, example before first load) falls back to catalog
    // position, so this is always safe to read.
    readonly property var orderedItems: {
        const byId = {};
        for (const item of items)
            byId[item.id] = item;
        const result = [];
        for (const id of order)
            if (byId[id])
                result.push(byId[id]);
        for (const item of items)
            if (order.indexOf(item.id) < 0)
                result.push(item);
        return result;
    }

    readonly property bool anyEnabled: {
        const s = _state;
        return items.some(item => s[item.id] !== false);
    }

    function isEnabled(id) {
        return _state[id] !== false;
    }

    function toggle(id) {
        const s = Object.assign({}, _state);
        s[id] = !isEnabled(id);
        _state = s;
        BarConfig.writeItemStates(s);
    }

    function isCollapsed(id) {
        return _collapsed[id] === true;
    }

    function toggleCollapsed(id) {
        const c = Object.assign({}, _collapsed);
        c[id] = !isCollapsed(id);
        _collapsed = c;
        BarConfig.writeItemCollapsed(c);
    }

    // Inserts id immediately before beforeId in the persisted order, or at the
    // end when beforeId is "". Works against the full order, so disabled/
    // overflowed ids keep their relative position untouched.
    function moveItemBefore(id, beforeId) {
        const cur = root.order.length ? root.order.slice() : items.map(i => i.id);
        const from = cur.indexOf(id);
        if (from < 0)
            return;
        cur.splice(from, 1);
        const toIdx = beforeId ? cur.indexOf(beforeId) : -1;
        cur.splice(toIdx < 0 ? cur.length : toIdx, 0, id);
        root.order = cur;
        BarConfig.writeItemOrder(cur);
    }

    function _merge() {
        const raw = BarConfig.itemStates;
        const s = Object.assign({}, raw);
        let dirty = false;
        for (const item of items) {
            if (!(item.id in s)) {
                s[item.id] = true;
                dirty = true;
            }
        }
        const known = new Set(items.map(x => x.id));
        for (const id of Object.keys(s)) {
            if (!known.has(id)) {
                delete s[id];
                dirty = true;
            }
        }
        _state = s;
        if (dirty)
            BarConfig.writeItemStates(s);
    }

    function _mergeCollapsed() {
        const raw = BarConfig.itemCollapsed;
        const c = Object.assign({}, raw);
        let dirty = false;
        for (const item of items) {
            if (!(item.id in c)) {
                c[item.id] = false;
                dirty = true;
            }
        }
        const known = new Set(items.map(x => x.id));
        for (const id of Object.keys(c)) {
            if (!known.has(id)) {
                delete c[id];
                dirty = true;
            }
        }
        _collapsed = c;
        if (dirty)
            BarConfig.writeItemCollapsed(c);
    }

    function _mergeOrder() {
        const known = new Set(items.map(x => x.id));
        const raw = BarConfig.itemOrder || [];
        const result = raw.filter(id => known.has(id));
        let dirty = result.length !== raw.length;
        const present = new Set(result);
        for (const item of items) {
            if (!present.has(item.id)) {
                result.push(item.id);
                dirty = true;
            }
        }
        root.order = result;
        if (dirty)
            BarConfig.writeItemOrder(result);
    }

    Connections {
        target: BarConfig
        function onItemStatesChanged() {
            root._merge();
        }
        function onItemOrderChanged() {
            root._mergeOrder();
        }
        function onItemCollapsedChanged() {
            root._mergeCollapsed();
        }
    }
}
