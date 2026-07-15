pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    // Which appId currently owns the popup. Empty = none.
    property string activeAppId: ""

    Timer {
        id: closeTimer
        interval: 350
        onTriggered: root.activeAppId = ""
    }

    function hover(appId) {
        activeAppId = appId;
        closeTimer.stop();
    }

    function leave() {
        closeTimer.restart();
    }
}
