import QtQuick
import QtQuick.Layouts
import "./Disc"
import "../Shared"

Item {
    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        PanelHeader {
            Layout.fillWidth: true
            breadcrumb: "SETTINGS / WORKSPACE INDICATOR"
            title: "Workspace Indicator"
        }

        WorkspaceDiscPanel {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
    }
}
