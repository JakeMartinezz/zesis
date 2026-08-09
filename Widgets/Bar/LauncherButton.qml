import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import "../../"

// Launcher button using the exact icon AGS uses (weather-clear-night-symbolic,
// from the active Gruvbox icon theme), tinted like AGS's "colored" panel-button:
// accent at rest (not just on hover), full accent on hover, on-accent while open.
Item {
    id: root

    implicitWidth: Math.round(26 * UIScale.value)
    implicitHeight: Math.round(26 * UIScale.value)

    property bool active: false
    signal clicked

    Rectangle {
        anchors.fill: parent
        radius: UIScale.radiusMd
        color: root.active ? Colors.accent : Colors.withAlpha(Colors.text, mouseArea.containsMouse ? 0.14 : 0.05)
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

    IconImage {
        id: iconImg
        visible: false
        anchors.centerIn: parent
        implicitSize: Math.round(15 * UIScale.value)
        // Quickshell's theme lookup doesn't pick up the GTK icon theme here, so
        // point straight at the file - it's the exact icon AGS renders.
        source: "file://" + Quickshell.env("HOME") + "/.nix-profile/share/icons/Gruvbox-Plus-Dark/status/symbolic/weather-clear-night-symbolic.svg"
    }

    MultiEffect {
        visible: iconImg.status === Image.Ready
        anchors.fill: iconImg
        source: iconImg
        colorization: 1.0
        colorizationColor: root.active ? Colors.onAccent : Colors.accent
        opacity: root.active || mouseArea.containsMouse ? 1.0 : 0.8

        Behavior on colorizationColor {
            ColorAnimation {
                duration: Anim.fast
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Anim.fast
            }
        }
    }

    // Fallback glyph if the icon file is ever missing
    Text {
        visible: iconImg.status !== Image.Ready
        anchors.centerIn: parent
        text: "󰖔"
        font.pixelSize: Math.round(16 * UIScale.value)
        color: root.active ? Colors.onAccent : Colors.withAlpha(Colors.accent, mouseArea.containsMouse ? 1.0 : 0.8)
    }
}
