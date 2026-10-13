import QtQuick
import QtQuick.Layouts
import "../../"

// Device card header: name + status line on the left, power switch on the right.
RowLayout {
    id: root

    property string title: ""
    property string status: ""
    property bool checked: false
    property color accentColor: Colors.accent
    property bool compact: false
    signal toggled

    Layout.fillWidth: true
    spacing: UIScale.spacingSm

    Column {
        Layout.fillWidth: true
        Layout.preferredWidth: 1 // fill what the switch leaves, not the title's full width
        spacing: 2
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.title
            color: Colors.text
            font.pixelSize: root.compact ? UIScale.fontSubhead : UIScale.fontTitle
            font.weight: Font.DemiBold
        }
        Text {
            width: parent.width
            elide: Text.ElideRight
            text: root.status
            color: Colors.textDim
            font.pixelSize: UIScale.fontSmall
        }
    }
    ToggleSwitch {
        implicitWidth: Math.round((root.compact ? 46 : 58) * UIScale.value)
        implicitHeight: Math.round((root.compact ? 26 : 32) * UIScale.value)
        checked: root.checked
        accentColor: root.accentColor
        icon: String.fromCodePoint(0xF0425) // md-power
        onToggled: root.toggled()
    }
}
