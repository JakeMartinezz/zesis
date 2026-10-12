import QtQuick

// Keeps AirconService's daemon alive while `active` is true. Every consumer (bar popup,
// desktop widget) declares one of these instead of pairing acquire/release by hand.
QtObject {
    id: root

    property bool active: false
    property bool _holding: false

    function _sync() {
        if (root.active && !root._holding) {
            root._holding = true;
            AirconService.acquire();
        } else if (!root.active && root._holding) {
            root._holding = false;
            AirconService.release();
        }
    }

    onActiveChanged: _sync()
    Component.onCompleted: _sync()
    Component.onDestruction: {
        if (root._holding)
            AirconService.release();
    }
}
