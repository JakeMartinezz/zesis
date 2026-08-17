pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool testMode: false
    property int testPercent: 65
    property bool popupOpen: false

    property bool available: testMode ? true : false
    property int current: 0
    property int max: 100
    readonly property int percent: testMode ? testPercent : (max > 0 ? Math.round(current / max * 100) : 0)

    function set(pct) {
        if (testMode) {
            testPercent = Math.max(1, Math.min(100, Math.round(pct)));
            return;
        }
        _setProc.command = ["brightnessctl", "set", Math.round(pct) + "%"];
        _setProc.running = true;
    }

    function adjust(delta) {
        var next = Math.max(1, Math.min(100, percent + delta));
        set(next);
    }

    function refresh() {
        _buf = "";
        _proc.running = true;
    }

    property string _buf: ""

    onPopupOpenChanged: if (popupOpen)
        refresh()

    Process {
        id: _proc
        running: !root.testMode
        // -m = machine readable: "dev,name,type,current,max"
        command: ["sh", "-c", "brightnessctl -m 2>/dev/null | head -1 | awk -F',' '{printf \"{\\\"available\\\":true,\\\"current\\\":%s,\\\"max\\\":%s}\\n\",$4,$5}' " + "|| echo '{\"available\":false}'"]

        stdout: SplitParser {
            onRead: data => root._buf += data + "\n"
        }

        onRunningChanged: {
            if (!running && root._buf.length > 0) {
                var line = root._buf.trim();
                root._buf = "";
                try {
                    var d = JSON.parse(line);
                    root.available = d.available ?? false;
                    if (d.available) {
                        root.current = d.current ?? 0;
                        root.max = d.max ?? 100;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: _setProc
        running: false
        onRunningChanged: if (!running)
            root.refresh()
    }

    // Only poll while a brightness UI is actually open - `available`/`percent`
    // just need to be correct once at startup for the bar icon, not kept live
    // every 3s in the background for a value nobody's looking at.
    Timer {
        interval: 3000
        running: !root.testMode && root.popupOpen
        repeat: true
        onTriggered: root.refresh()
    }
}
