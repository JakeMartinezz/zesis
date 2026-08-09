pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.SystemTray

GridLayout {
    rows: 1
    columns: -1
    rowSpacing: 4
    columnSpacing: 4

    Repeater {
        model: SystemTray.items
        delegate: TrayIcon {
            required property SystemTrayItem modelData
            item: modelData
        }
    }
}
