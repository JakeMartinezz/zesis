pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../"

PanelWindow {
    id: root

    property real dimmerOpacity: 0.45
    property color dimmerColor: "black"
    property real initialScale: 0
    property real showOvershoot: 1.4
    property real maxContentWidth: 0
    property real maxContentHeight: 0
    property Component content: null

    signal dimmerTapped
    signal contentLoaded(var item)

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: -1
    color: "transparent"
    visible: false

    function open() {
        if (!visible) {
            dimmer.opacity = 0;
            overlayContent.scale = initialScale;
            overlayContent.opacity = 0;
            visible = true;
        }
        unmapTimer.stop();
        hideAnim.stop();
        showAnim.start();
    }

    function close() {
        if (!visible)
            return;
        showAnim.stop();
        hideAnim.start();
        unmapTimer.restart();
    }

    // Unmaps strictly Anim.medium after a close starts, on a plain clock
    // instead of hideAnim's own running state - hideAnim.stop() (called by
    // open() when a reopen races an in-flight close, e.g. rapid-fire
    // Alt+Tab) fires the SAME `stopped` signal a natural completion would,
    // so wiring `root.visible = false` to hideAnim.onStopped closed the
    // window right back down the instant it tried to reopen, and knocked
    // AppSwitcherService.open back to false via onVisibleChanged below -
    // from the outside this just looked like the switcher had stopped
    // responding. A Timer's own stop() doesn't fire `triggered`, so
    // cancelling it here on every open() is immune to that.
    Timer {
        id: unmapTimer
        interval: Anim.medium
        onTriggered: root.visible = false
    }

    onVisibleChanged: {
        if (!visible) {
            dimmer.opacity = 0;
            overlayContent.scale = initialScale;
            overlayContent.opacity = 0;
        }
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation {
            target: dimmer
            property: "opacity"
            to: root.dimmerOpacity
            duration: Anim.medium
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: overlayContent
            property: "opacity"
            to: 1
            duration: Anim.medium
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: overlayContent
            property: "scale"
            to: 1
            duration: Anim.slow
            easing.type: Easing.OutBack
            easing.overshoot: root.showOvershoot
        }
    }

    ParallelAnimation {
        id: hideAnim
        NumberAnimation {
            target: dimmer
            property: "opacity"
            to: 0
            duration: Anim.medium
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: overlayContent
            property: "opacity"
            to: 0
            duration: Anim.fast
            easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: overlayContent
            property: "scale"
            to: root.initialScale
            duration: Anim.fast
            easing.type: Easing.InCubic
        }
    }

    Rectangle {
        id: dimmer
        anchors.fill: parent
        color: root.dimmerColor
        opacity: 0

        TapHandler {
            onTapped: root.dimmerTapped()
        }
    }

    Item {
        id: overlayContent
        anchors.centerIn: parent
        width: root.maxContentWidth > 0 ? Math.min(root.width - 80, root.maxContentWidth) : root.width
        height: root.maxContentHeight > 0 ? Math.min(root.height - 80, root.maxContentHeight) : root.height
        scale: root.initialScale
        opacity: 0

        Loader {
            anchors.fill: parent
            active: root.visible
            sourceComponent: root.content
            onLoaded: root.contentLoaded(item)
        }
    }
}
