import QtQuick
import Quickshell.Services.Mpris
import "../../"

// Icon-only at rest, like AGS's Media widget - reveals the track title briefly
// on track change or hover, then auto-collapses (AGS's Revealer, 3s timeout).
Item {
    id: root

    readonly property alias isHovered: chipHover.hovered

    readonly property var _player: Mpris.players.values.length > 0 ? Mpris.players.values[0] : null
    readonly property string _title: root._player ? root._player.trackTitle : ""

    readonly property real _iconSize: Math.round(26 * UIScale.value)
    readonly property real _textW: Math.round(110 * UIScale.value)

    property bool _revealed: false

    visible: root._player !== null
    clip: true
    implicitWidth: root._revealed ? (root._iconSize + Math.round(UIScale.spacingXs) + root._textW) : root._iconSize
    implicitHeight: root._iconSize

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Anim.medium
            easing.type: Easing.InOutCubic
        }
    }

    Timer {
        id: revealTimer
        interval: 3000
        onTriggered: if (!chipHover.hovered)
            root._revealed = false
    }

    on_TitleChanged: {
        if (root._title !== "") {
            root._revealed = true;
            revealTimer.restart();
        }
    }

    HoverHandler {
        id: chipHover
        onHoveredChanged: {
            if (hovered) {
                revealTimer.stop();
                root._revealed = true;
            } else {
                revealTimer.restart();
            }
        }
    }

    TapHandler {
        onTapped: if (root._player)
            root._player.togglePlaying()
    }

    WheelHandler {
        onWheel: function (w) {
            if (!root._player)
                return;
            if (w.angleDelta.y > 0)
                root._player.previous();
            else
                root._player.next();
        }
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(UIScale.spacingXs)

        Text {
            width: root._iconSize
            height: root._iconSize
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: "󰝚"
            color: Colors.text
            font.pixelSize: UIScale.fontLead
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root._revealed
            text: root._title
            width: root._textW
            elide: Text.ElideRight
            color: Colors.text
            font.pixelSize: UIScale.fontSmall
            font.bold: true
        }
    }
}
