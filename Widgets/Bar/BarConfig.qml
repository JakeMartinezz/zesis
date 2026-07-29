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

    readonly property bool isVertical: side === "left" || side === "right"

    function write(newSide) {
        _save(newSide, root.edgeGap, root.endGap, root.itemStates, root.itemOrder);
    }

    function writeEdgeGap(newGap) {
        _save(root.side, newGap, root.endGap, root.itemStates, root.itemOrder);
    }

    function writeEndGap(newGap) {
        _save(root.side, root.edgeGap, newGap, root.itemStates, root.itemOrder);
    }

    function writeItemStates(states) {
        _save(root.side, root.edgeGap, root.endGap, states, root.itemOrder);
    }

    function writeItemOrder(order) {
        _save(root.side, root.edgeGap, root.endGap, root.itemStates, order);
    }

    function _save(s, eg, en, states, order) {
        const json = '{"side":"' + s + '","edgeGap":' + eg + ',"endGap":' + en + ',"itemStates":' + JSON.stringify(states) + ',"itemOrder":' + JSON.stringify(order) + '}';
        writeProc.command = ["sh", "-c", "mkdir -p '" + root._configDir + "' && printf '%s' '" + json + "' > '" + root._configPath + "'"];
        writeProc.running = true;
    }

    JsonAdapter {
        id: barData
        property string side: "top"
        property int edgeGap: 8
        property int endGap: 20
        property var itemStates: ({})
        property var itemOrder: []
    }

    FileView {
        path: root._configPath
        watchChanges: true
        adapter: barData
        onFileChanged: reload()
    }

    Process {
        id: writeProc
        running: false
    }
}
