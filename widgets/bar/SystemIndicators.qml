import QtQuick
import "../../"
import "../bluetooth"
import "../wifi"
import "../sound"
import "../mic"
import "../aircon"

// Bundles bluetooth/wifi/sound/mic (+ aircon when enabled) into one shared panel-button box, matching
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

        // Lives here instead of as its own bar slot (its BarItemsService entry has
        // host: "system"); the bar settings toggle still turns it on and off. A Loader
        // so AirconService (and its startup fetch) only exists when it's enabled.
        Loader {
            active: BarConfig.ready && BarItemsService.isEnabled("aircon") // see SysTray's slot Loader
            visible: active && item !== null && item.available
            sourceComponent: AirconItem {
                bare: true
            }
        }
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
