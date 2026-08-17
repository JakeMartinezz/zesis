pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string _configDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/zesis"
    readonly property string _configPath: _configDir + "/barconfig.json"

    property string side: barData.side
    property int edgeGap: barData.edgeGap
    property int endGap: barData.endGap
    property var itemStates: barData.itemStates
    property var itemOrder: barData.itemOrder
    // ids the user chose to always keep tucked behind the overflow toggle,
    // regardless of available width
    property var itemCollapsed: barData.itemCollapsed
    // monitor names (ShellScreen.name) the bar should appear on. Empty = all
    // monitors (default), so existing configs keep working unchanged.
    property var enabledMonitors: barData.enabledMonitors

    // The persisted config (edgeGap etc.) loads asynchronously. If the bar
    // window maps before this resolves, it commits to the compositor with the
    // JsonAdapter's compiled-in defaults, and the wlr-layer-shell margin never
    // gets re-committed once the real value arrives - the bar visibly "floats"
    // until something else (e.g. a settings change) forces a re-commit. Gate
    // the window's mapping on this instead.
    property bool ready: false

    function write(newSide) {
        _save(newSide, root.edgeGap, root.endGap, root.itemStates, root.itemOrder, root.itemCollapsed, root.enabledMonitors);
    }

    function writeEdgeGap(newGap) {
        _save(root.side, newGap, root.endGap, root.itemStates, root.itemOrder, root.itemCollapsed, root.enabledMonitors);
    }

    function writeEndGap(newGap) {
        _save(root.side, root.edgeGap, newGap, root.itemStates, root.itemOrder, root.itemCollapsed, root.enabledMonitors);
    }

    function writeItemStates(states) {
        _save(root.side, root.edgeGap, root.endGap, states, root.itemOrder, root.itemCollapsed, root.enabledMonitors);
    }

    function writeItemOrder(order) {
        _save(root.side, root.edgeGap, root.endGap, root.itemStates, order, root.itemCollapsed, root.enabledMonitors);
    }

    function writeItemCollapsed(collapsed) {
        _save(root.side, root.edgeGap, root.endGap, root.itemStates, root.itemOrder, collapsed, root.enabledMonitors);
    }

    function writeEnabledMonitors(monitors) {
        _save(root.side, root.edgeGap, root.endGap, root.itemStates, root.itemOrder, root.itemCollapsed, monitors);
    }

    function _save(s, eg, en, states, order, collapsed, monitors) {
        const json = JSON.stringify({
            side: s,
            edgeGap: eg,
            endGap: en,
            itemStates: states,
            itemOrder: order,
            itemCollapsed: collapsed,
            enabledMonitors: monitors
        });
        writeProc.command = ["bash", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "--",
            root._configDir, json, root._configPath];
        writeProc.running = true;
    }

    JsonAdapter {
        id: barData
        property string side: "top"
        property int edgeGap: 8
        property int endGap: 8
        property var itemStates: ({})
        property var itemOrder: []
        property var itemCollapsed: ({})
        property var enabledMonitors: []
    }

    FileView {
        path: root._configPath
        watchChanges: true
        adapter: barData // qmllint disable missing-type
        onFileChanged: reload()
        onLoaded: root.ready = true
        onLoadFailed: root.ready = true // e.g. no config saved yet - defaults are already correct
    }

    Process {
        id: writeProc
        running: false
    }
}
