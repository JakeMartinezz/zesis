pragma Singleton
import QtQuick
import Quickshell

Singleton {
    id: root

    property bool open: false

    function show() {
        root.open = true;
    }

    function toggle() {
        root.open = !root.open;
    }

    function close() {
        root.open = false;
    }
}
