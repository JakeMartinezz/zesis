pragma Singleton
import QtQuick
import Quickshell
import "../../"

Singleton {
    id: root

    readonly property var items: [
        {
            id: "systray",
            label: I18n.t("bar.itemSystray"),
            src: "SystrayItems.qml"
        },
        // The repaint of this widget causes 0.6% hits on the CPU in regular intervals
        {
            id: "sysmon",
            label: I18n.t("bar.itemSysmon"),
            src: "../sysmon/SysMonItem.qml"
        },
        {
            id: "theme",
            label: I18n.t("bar.itemTheme"),
            src: "../themeswitcher/ThemeSwitcherItem.qml"
        },
        {
            id: "keybinds",
            label: I18n.t("bar.itemKeybinds"),
            src: "../keybinds/KeybindsItem.qml"
        },
        {
            id: "bluetooth",
            label: I18n.t("bar.itemBluetooth"),
            src: "../bluetooth/BluetoothItem.qml"
        },
        {
            id: "airpods",
            label: I18n.t("bar.itemAirpods"),
            src: "../airpods/AirPods.qml"
        },
        {
            id: "wifi",
            label: I18n.t("bar.itemWifi"),
            src: "../wifi/WifiItem.qml"
        },
        {
            id: "weather",
            label: I18n.t("bar.itemWeather"),
            src: "../weather/WeatherItem.qml"
        },
        {
            id: "brightness",
            label: I18n.t("bar.itemBrightness"),
            src: "../brightness/BrightnessItem.qml"
        },
        {
            id: "sound",
            label: I18n.t("bar.itemSound"),
            src: "../sound/SoundItem.qml"
        },
        {
            id: "mic",
            label: I18n.t("bar.itemMic"),
            src: "../mic/MicItem.qml"
        },
        {
            id: "notifications",
            label: I18n.t("bar.itemNotifications"),
            src: "../notifications/NotificationsItem.qml"
        },
        {
            id: "config",
            label: I18n.t("bar.itemConfig"),
            src: "../config/ConfigItem.qml"
        },
        {
            id: "battery",
            label: I18n.t("bar.itemBattery"),
            src: "../battery/BatteryItem.qml"
        },
        {
            id: "record",
            label: I18n.t("bar.itemRecord"),
            src: "../record/RecordItem.qml"
        },
        {
            id: "gitupdate",
            label: I18n.t("bar.itemGitupdate"),
            src: "../gitupdate/GitUpdateItem.qml"
        },
        {
            id: "home",
            label: I18n.t("bar.itemHome"),
            icon: ""
        },
        {
            id: "settings",
            label: I18n.t("bar.itemSettings"),
            icon: "󰘮"
        },
        {
            id: "lock",
            label: I18n.t("bar.itemLock"),
            icon: "󰌾"
        },
        {
            id: "clock",
            label: I18n.t("bar.itemClock"),
            src: "../clock/ClockItem.qml"
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
