import QtQuick
import Quickshell
import "../../"
import "../bar"

PopupWindow {
    id: root

    required property Item anchorItem
    property Component content
    property bool hasBackground: true
    signal opened
    // For content whose height changes while open: the surface keeps implicitHeight
    // (pass the most room the content can need) and only the visible frame follows the
    // content's implicitHeight. Resizing the surface itself instead re-lays the content
    // out against a stale size on every change, which reads as a jolt. The frame is not
    // animated here: the content animates its own height and the frame just tracks it
    // (see docs/qml-patterns.md, never a Behavior on an already-animated value).
    property bool fitContent: false
    readonly property real _frameH: root.fitContent && contentLoader.item ? Math.min(root.height, contentLoader.item.implicitHeight) : root.height

    anchor.item: anchorItem
    anchor.rect.x: anchorItem.width / 2 - root.implicitWidth / 2
    anchor.rect.y: BarConfig.side === "bottom" ? -root.implicitHeight : anchorItem.height
    grabFocus: true
    visible: false
    color: "transparent"

    function open() {
        if (!visible) {
            frame.scale = 0;
            frame.opacity = 0;
            visible = true;
        }
        showAnim.start();
        root.opened();
    }

    function close() {
        if (!visible)
            return;
        showAnim.stop();
        visible = false;
    }

    onVisibleChanged: {
        if (!visible) {
            frame.scale = 0;
            frame.opacity = 0;
        }
    }

    property string _barSide: BarConfig.side
    on_BarSideChanged: root.close()

    ParallelAnimation {
        id: showAnim
        NumberAnimation {
            target: frame
            property: "scale"
            to: 1
            duration: Anim.slow
            easing.type: Easing.OutBack
            easing.overshoot: 1.4
        }
        NumberAnimation {
            target: frame
            property: "opacity"
            to: 1
            duration: Anim.medium
            easing.type: Easing.OutCubic
        }
    }

    // Clicks in the unused (transparent) part of a fitContent surface go through.
    // Explicit rect, not `item: frame`: the frame starts at scale 0 for the open
    // animation, and a region derived from the item stayed empty, so clicks fell through
    // and the compositor closed the popup.
    mask: Region {
        x: 0
        y: frame.y
        width: root.width
        height: frame.height
    }

    Item {
        id: frame
        width: parent.width
        height: root._frameH
        y: BarConfig.side === "bottom" ? parent.height - height : 0
        scale: 0
        opacity: 0
        transformOrigin: BarConfig.side === "bottom" ? Item.Bottom : Item.Top

        Rectangle {
            anchors.fill: parent
            radius: UIScale.radiusLg
            topLeftRadius: BarConfig.side === "top" ? 0 : UIScale.radiusLg
            topRightRadius: BarConfig.side === "top" ? 0 : UIScale.radiusLg
            bottomLeftRadius: BarConfig.side === "bottom" ? 0 : UIScale.radiusLg
            bottomRightRadius: BarConfig.side === "bottom" ? 0 : UIScale.radiusLg
            color: Colors.bg
            border.color: Colors.outline
            border.width: 1
            visible: root.hasBackground
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            active: root.visible
            sourceComponent: root.content
        }
    }
}
