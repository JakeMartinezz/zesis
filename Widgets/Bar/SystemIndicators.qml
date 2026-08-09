import QtQuick
import "../../"
import "../Bluetooth"
import "../Wifi"
import "../Sound"
import "../Mic"

// Bundles bluetooth/wifi/sound/mic into one shared panel-button box, matching
// AGS's SystemIndicators.ts (several plain icons inside a single PanelButton).
// Each icon keeps its own click-to-open popup - AGS routes all of these into
// one shared quicksettings window, but quickshell doesn't have an equivalent
// unified panel yet, so the per-service popups stay.
Item {
    id: root

    readonly property real _hPad: Math.round(6 * UIScale.value)

    implicitWidth: row.implicitWidth + root._hPad * 2
    implicitHeight: Math.round(26 * UIScale.value)

    Rectangle {
        anchors.fill: parent
        radius: UIScale.radiusMd
        color: Colors.withAlpha(Colors.text, groupHover.hovered ? 0.14 : 0.05)
        Behavior on color {
            ColorAnimation {
                duration: Anim.fast
            }
        }
    }

    HoverHandler {
        id: groupHover
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 0

        BluetoothItem {
            bare: true
        }
        WifiItem {
            bare: true
        }
        SoundItem {
            bare: true
        }
        MicItem {
            bare: true
        }
    }
}
