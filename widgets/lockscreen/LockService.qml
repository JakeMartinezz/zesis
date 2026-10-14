pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root
    signal lockRequested
    // Mirrors the session lock, for services that react to it (e.g. Tapo off-on-lock).
    property bool locked: false
    function triggerLock() {
        root.lockRequested();
    }
}
