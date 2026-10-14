import QtQuick
import QtQuick.Layouts
import "../../"

// Selectable pill with an optional icon and label (aircon extras, tapo options...).
// `block`: a taller rounded block that fills an equal-width GridLayout column.
Rectangle {
    id: chip
    property color tint: Colors.accent
    property bool selected: false
    property string icon: ""
    property string label: ""
    property bool block: false
    signal clicked

    implicitWidth: chipRow.implicitWidth + UIScale.spacingMd
    implicitHeight: Math.round((block ? 34 : 26) * UIScale.value)
    radius: block ? UIScale.radiusMd : height / 2
    Layout.fillWidth: block
    Layout.preferredWidth: block ? 1 : -1 // equal columns whatever the label length
    color: selected ? Colors.withAlpha(tint, 0.22) : Colors.withAlpha(Colors.text, chipHover.hovered ? 0.08 : 0.05)
    border.color: selected ? Colors.withAlpha(tint, 0.5) : "transparent"
    border.width: 1
    Behavior on color {
        ColorAnimation {
            duration: Anim.fast
        }
    }
    Row {
        id: chipRow
        anchors.centerIn: parent
        spacing: Math.round(4 * UIScale.value)
        Text {
            visible: chip.icon.length > 0
            text: chip.icon
            color: chip.selected ? chip.tint : Colors.textDim
            font.pixelSize: UIScale.fontSmall
        }
        Text {
            visible: chip.label.length > 0
            text: chip.label
            color: chip.selected ? Colors.text : Colors.textDim
            font.pixelSize: UIScale.fontSmall
        }
    }
    HoverHandler {
        id: chipHover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: chip.clicked()
    }
}
