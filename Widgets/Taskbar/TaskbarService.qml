pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Which TaskbarItem instance currently owns the popup. Null = none.
    // Keyed by instance.
    property var activeItem: null

    // Taskbar icons rendered as tinted symbolic (AGS's bar.taskbar.monochrome)
    // instead of full-color, when the app ships a symbolic icon variant.
    property bool monochrome: false

    readonly property string _configDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/zesis"
    readonly property string _configPath: _configDir + "/taskbar.json"

    function setMonochrome(value) {
        root.monochrome = value;
        root._save();
    }

    function _save() {
        const json = '{"monochrome":' + (root.monochrome ? "true" : "false") + '}';
        writeProc.command = ["sh", "-c", "mkdir -p '" + root._configDir + "' && printf '%s' '" + json + "' > '" + root._configPath + "'"];
        writeProc.running = true;
    }

    JsonAdapter {
        id: taskbarData
        property bool monochrome: false
    }

    FileView {
        path: root._configPath
        watchChanges: true
        adapter: taskbarData // qmllint disable missing-type
        onLoaded: root.monochrome = taskbarData.monochrome
        onFileChanged: reload()
    }

    Process {
        id: writeProc
        running: false
    }

    Timer {
        id: closeTimer
        interval: 350
        onTriggered: root.activeItem = null
    }

    function hover(item) {
        activeItem = item;
        closeTimer.stop();
    }

    function leave() {
        closeTimer.restart();
    }
}
