import QtQuick
import "../../"

// Small accent-tinted pill button. Auto-sizes to its label (with a floor
// matching the original fixed-size button this was extracted from), so it
// also works for longer labels like "Re-scatter (new random)".
Item {
    id: root
    signal activated

    property string label: ""

    readonly property real _minWidth: Math.round(58 * UIScale.value)
    implicitWidth: Math.max(_minWidth, labelText.implicitWidth + UIScale.spacingMd * 2)
    implicitHeight: Math.round(32 * UIScale.value)

    Rectangle {
        anchors.fill: parent
        radius: UIScale.radiusSm
        color: hoverHandler.hovered ? Colors.withAlpha(Colors.accent, 0.28) : Colors.withAlpha(Colors.accent, 0.14)
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }

        Text {
            id: labelText
            anchors.centerIn: parent
            text: root.label
            color: Colors.accent
            font.pixelSize: UIScale.fontSmall
            font.weight: Font.DemiBold
        }
    }

    HoverHandler {
        id: hoverHandler
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
