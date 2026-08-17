import QtQuick
import "../../"

Item {
    id: root
    // Unconditional, never gate on visible here. See docs/qml-patterns.md #1
    implicitWidth: Math.round(26 * UIScale.value)
    implicitHeight: Math.round(26 * UIScale.value)

    property string icon: ""
    property bool active: false
    // When true, suppresses this button's own box - used when several of these
    // are bundled inside one shared panel-button box (see SystemIndicators.qml),
    // matching AGS's SystemIndicators (several plain icons in one PanelButton).
    property bool bare: false
    signal clicked

    // AGS-style panel-button (flatButtons:false): a faint persistent tint at
    // rest, brighter on hover, solid accent while active.
    Rectangle {
        anchors.fill: parent
        radius: UIScale.radiusMd
        color: root.bare ? "transparent" : (root.active ? Colors.accent : Colors.withAlpha(Colors.text, mouseArea.containsMouse ? 0.14 : 0.05))
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    Text {
        anchors.centerIn: parent
        text: root.icon
        font.pixelSize: Math.round(15 * UIScale.value)
        color: root.active ? (root.bare ? Colors.accent : Colors.onAccent) : (mouseArea.containsMouse ? Colors.accent : Colors.text)
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }
}
