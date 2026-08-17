import QtQuick

// Click-twice-to-confirm state machine for destructive/overwrite actions.
// First confirm(key) arms it and starts a timeout, returning false (caller
// should wait for a second click); confirm(key) with the same key again
// within the window disarms and returns true (caller should proceed).
// Used by PowerMenu.qml (reboot/shutdown) and AppearancePanel.qml
// (overwrite an existing saved theme).
QtObject {
    id: root

    property int timeoutMs: 3000
    property string armedKey: ""

    function isArmed(key) {
        return key !== "" && root.armedKey === key;
    }

    function confirm(key) {
        if (root.armedKey === key) {
            root.armedKey = "";
            return true;
        }
        root.armedKey = key;
        _timer.restart();
        return false;
    }

    function disarm() {
        root.armedKey = "";
    }

    property Timer _timer: Timer {
        interval: root.timeoutMs
        onTriggered: root.armedKey = ""
    }
}
