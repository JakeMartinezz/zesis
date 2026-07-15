pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import "../../"

Item {
    id: root

    readonly property alias isHovered: chipHover.hovered

    readonly property var _player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null

    readonly property int _textW: Math.round(110 * UIScale.value)
    readonly property int _padH: Math.round(12 * UIScale.value)
    readonly property int _pillH: Math.round(50 * UIScale.value)

    implicitWidth: iconText.implicitWidth + Math.round(UIScale.spacingSm) + _textW + _padH * 2
    implicitHeight: _pillH

    Rectangle {
        anchors.centerIn: parent
        width: parent.implicitWidth
        height: root._pillH
        radius: 100
        clip: true
        color: Colors.barBg

        Row {
            anchors.centerIn: parent
            spacing: Math.round(UIScale.spacingSm)

            Text {
                id: iconText
                anchors.verticalCenter: parent.verticalCenter
                text: "󰝚"
                color: Colors.muted
                font.pixelSize: UIScale.fontLead
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root._player ? root._player.trackTitle : ""
                width: root._textW
                elide: Text.ElideRight
                color: Colors.text
                font.pixelSize: UIScale.fontSmall
                font.bold: true
            }
        }

        HoverHandler {
            id: chipHover
        }
    }
}
