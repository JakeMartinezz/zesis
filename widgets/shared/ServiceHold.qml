import QtQuick

// Keeps a service's background work alive while `active` is true. `service` is any
// singleton with acquire()/release() (AirconService, SysMonService...); every consumer
// declares one of these instead of pairing acquire/release by hand.
QtObject {
    id: root

    property QtObject service: null
    property bool active: false
    property bool _holding: false

    function _sync() {
        if (root.active && !root._holding && root.service) {
            root._holding = true;
            root.service.acquire();
        } else if (!root.active && root._holding) {
            root._holding = false;
            root.service.release();
        }
    }

    onActiveChanged: _sync()
    onServiceChanged: _sync()
    Component.onCompleted: _sync()
    Component.onDestruction: {
        if (root._holding)
            root.service.release();
    }
}
