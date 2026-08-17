import QtQuick

// Connection-state derivation + failure relay for a single network row -
// used by both the bar dropdown (Wifi.qml) and the full panel
// (WifiPanel.qml), which otherwise duplicated this near-verbatim.
QtObject {
    id: root

    required property var network
    required property var pendingNetwork

    readonly property bool isConnected: network.connected
    readonly property bool isPending: pendingNetwork === network
    readonly property bool isChanging: network.stateChanging

    signal connectionFailed(string reason)

    property Connections _conn: Connections {
        target: root.network
        function onConnectionFailed(reason) {
            root.connectionFailed(reason);
        }
    }
}
