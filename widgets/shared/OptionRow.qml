pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import "../../"

Item {
    id: root
    property var model: []
    property int currentIndex: -1
    property color accentColor: Colors.accent // selected cell tint
    signal activated(int index)

    implicitHeight: Math.round(32 * UIScale.value)

    RowLayout {
        anchors.fill: parent
        spacing: UIScale.spacingSm

        Repeater {
            model: root.model
            delegate: Rectangle {
                id: optBtn
                required property string modelData
                required property int index

                Layout.fillWidth: true
                implicitHeight: Math.round(32 * UIScale.value)
                radius: UIScale.radiusSm
                color: root.currentIndex === optBtn.index ? Colors.withAlpha(root.accentColor, 0.15) : Colors.surfaceHigh
                border.color: root.currentIndex === optBtn.index ? root.accentColor : "transparent"
                border.width: 1

                Text {
                    anchors.fill: parent
                    anchors.leftMargin: UIScale.spacingXs
                    anchors.rightMargin: UIScale.spacingXs
                    text: optBtn.modelData
                    color: Colors.text
                    font.pixelSize: UIScale.fontSmall
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activated(optBtn.index)
                }
            }
        }
    }
}
