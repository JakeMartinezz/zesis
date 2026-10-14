import QtQuick
import QtQuick.Layouts
import "../../"

// Collapsible "more options" card for device cards (aircon, tapo). Full mode: the header
// row expands to show the default content below it. Compact mode (desktop widget): the
// desktop widget is a layer surface sized to its content, and growing it resizes and moves
// the window every frame, so `compactContent` swaps in place of the header (same height)
// instead of expanding below it.
SettingCard {
    id: more

    property bool compact: false
    property string title
    property string hint
    property bool open: false
    default property alias extras: body.data
    property alias compactContent: compactSlot.data

    // One column with no spacing, so the extras' gap can live inside the animated
    // height instead of popping in/out with the wrapper's visibility.
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Item {
            Layout.fillWidth: true
            implicitHeight: Math.max(moreHeader.implicitHeight, compactExtras.implicitHeight)

            RowLayout {
                id: moreHeader
                anchors.fill: parent
                spacing: UIScale.spacingSm
                // compact: crossfades with the extras row instead of expanding
                opacity: more.compact && more.open ? 0 : 1
                enabled: opacity > 0.5
                Behavior on opacity {
                    NumberAnimation {
                        duration: Anim.medium
                    }
                }
                Text {
                    text: String.fromCodePoint(0xF0493) // md-cog
                    color: Colors.textDim
                    font.pixelSize: Math.round(18 * UIScale.value)
                }
                Column {
                    Layout.fillWidth: true
                    spacing: 1
                    Text {
                        text: more.title
                        color: Colors.text
                        font.pixelSize: UIScale.fontBody
                        font.weight: Font.DemiBold
                    }
                    Text {
                        visible: !more.compact && more.hint !== ""
                        text: more.hint
                        color: Colors.textDim
                        font.pixelSize: UIScale.fontCaption
                    }
                }
                Text {
                    text: String.fromCodePoint(0xF0142) // md-chevron_right
                    color: moreHover.hovered ? Colors.accent : Colors.textDim
                    font.pixelSize: Math.round(18 * UIScale.value)
                    rotation: more.open && !more.compact ? 90 : 0
                    Behavior on rotation {
                        NumberAnimation {
                            duration: Anim.fast
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Anim.standard
                        }
                    }
                }
                HoverHandler {
                    id: moreHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    // Curve picked before toggling: a binding on `more.open` would be
                    // read stale in the same update that starts the height animation.
                    onTapped: {
                        moreAnim.easing.bezierCurve = more.open ? Anim.emphasizedAccel : Anim.emphasizedDecel;
                        moreAnim.duration = more.open ? Anim.medium : Anim.morph; // closing reads better quick
                        more.open = !more.open;
                    }
                }
            }

            RowLayout {
                id: compactExtras
                anchors.fill: parent
                visible: more.compact
                spacing: Math.round(6 * UIScale.value)
                opacity: more.compact && more.open ? 1 : 0
                enabled: opacity > 0.5
                Behavior on opacity {
                    NumberAnimation {
                        duration: Anim.medium
                    }
                }
                Text {
                    text: String.fromCodePoint(0xF0141) // md-chevron_left
                    color: backHover.hovered ? Colors.accent : Colors.textDim
                    font.pixelSize: Math.round(18 * UIScale.value)
                    HoverHandler {
                        id: backHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: more.open = false
                    }
                }
                Item {
                    Layout.fillWidth: true
                }
                RowLayout {
                    id: compactSlot
                    spacing: Math.round(6 * UIScale.value)
                }
            }
        }

        // Collapse wrapper with Anim's expand/collapse pair
        // (no overshoot: spatial dips below 0 on close).
        Item {
            id: moreWrapper
            Layout.fillWidth: true
            visible: !more.compact
            implicitHeight: more.open && !more.compact ? UIScale.spacingSm + body.implicitHeight : 0
            clip: true
            Behavior on implicitHeight {
                NumberAnimation {
                    id: moreAnim
                    duration: Anim.morph
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Anim.emphasizedDecel
                }
            }

            ColumnLayout {
                id: body
                y: UIScale.spacingSm
                width: moreWrapper.width
                spacing: UIScale.spacingSm
                opacity: more.open ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: Anim.medium
                    }
                }
            }
        }
    }
}
