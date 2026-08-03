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
            id: "bluetooth",
            label: "Bluetooth",
            src: "../Bluetooth/BluetoothItem.qml"
        },
        {
            id: "airpods",
            label: "AirPods",
            src: "../AirPods/AirPods.qml"
        },
        {
            id: "wifi",
            label: "Wi-Fi",
            src: "../Wifi/WifiItem.qml"
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
            id: "sound",
            label: "Sound",
            src: "../Sound/SoundItem.qml"
        },
        {
            id: "mic",
            label: "Microphone",
            src: "../Mic/MicItem.qml"
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
            id: "home",
            label: "Home",
            icon: ""
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
    }
}
