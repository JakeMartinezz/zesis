pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "Widgets/Bar"
import "Widgets/WorkspaceIndicator"
import "Widgets/Music"
import "Widgets/Notifications"
import "Widgets/LockScreen"
import "Widgets/Keybinds"
import "Widgets/AppSwitcher"
import "Widgets/Shared"
import "Widgets/WidgetHome"
import "Widgets/Polkit"
import "Widgets/Display"
import "Widgets/Calendar"
import "Widgets/Home"
import "Widgets/Sound"
import "Widgets/PumpPanel"
import "Widgets/Clock"
import "Widgets/Desktop"
import "Widgets/Taskbar"
// These imports are needed for BarItemsService to function correctly
import "Widgets/Brightness"
import "Widgets/Mic"
import "Widgets/Battery"
import "Widgets/Record"

Scope {
    // Singletons instantiated at startup for startup-apply logic
    property string _displayInit: DisplayService.monitorName
    property var _calInit: CalendarService.events

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: root

            required property ShellScreen modelData

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.margins {
                top: BarConfig.side === "top" ? BarConfig.edgeGap : 0
                bottom: BarConfig.side === "bottom" ? BarConfig.edgeGap : 0
                left: BarConfig.side === "left" ? BarConfig.edgeGap : 0
                right: BarConfig.side === "right" ? BarConfig.edgeGap : 0
            }
            screen: modelData

            // Strip = pill thickness on the short axis, full-edge span on the long axis.
            // This avoids any centering math, edgeGap is the only outer-gap knob.
            implicitHeight: BarConfig.isVertical ? 0 : Math.round(50 * UIScale.value)
            implicitWidth: BarConfig.isVertical ? Math.round(50 * UIScale.value) : 0

            anchors {
                top: BarConfig.side !== "bottom"
                bottom: BarConfig.side !== "top"
                left: BarConfig.side !== "right"
                right: BarConfig.side !== "left"
            }

            color: "transparent"

            SysTray {
                id: trayWidget
                x: BarConfig.isVertical ? 0 : (parent.width - width - BarConfig.endGap)
                y: BarConfig.isVertical ? (parent.height - height - BarConfig.endGap) : 0
            }

            Connections {
                target: LockService
                function onLockRequested() {
                    lockScreen.triggerLock();
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens
        delegate: PanelWindow {
            id: centerIsland
            required property ShellScreen modelData
            screen: modelData

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "zesis:taskbar"
            WlrLayershell.margins {
                top: BarConfig.side === "top" ? BarConfig.edgeGap : 0
                bottom: BarConfig.side === "bottom" ? BarConfig.edgeGap : 0
                left: BarConfig.side === "left" ? BarConfig.edgeGap : 0
                right: BarConfig.side === "right" ? BarConfig.edgeGap : 0
            }
            anchors {
                top: BarConfig.side === "top"
                bottom: BarConfig.side === "bottom"
                left: BarConfig.side === "left"
                right: BarConfig.side === "right"
            }
            exclusiveZone: -1
            color: "transparent"

            readonly property bool _hasMusic: Mpris.players.values.length > 0
            property bool wantsMusic: false

            implicitWidth: BarConfig.isVertical ? Math.round(50 * UIScale.value) : islandRow.implicitWidth
            implicitHeight: BarConfig.isVertical ? islandRow.implicitHeight : Math.round(50 * UIScale.value)

            Row {
                id: islandRow
                anchors.centerIn: parent
                spacing: Math.round(6 * UIScale.value)

                MusicChip {
                    id: musicChip
                    visible: centerIsland._hasMusic && !BarConfig.isVertical
                    onIsHoveredChanged: {
                        if (isHovered) {
                            centerIsland.wantsMusic = true;
                            musicHideTimer.stop();
                        } else if (!popupHover.hovered) {
                            musicHideTimer.restart();
                        }
                    }
                }

                Taskbar {
                    id: taskbarPill
                }
            }

            Timer {
                id: musicHideTimer
                interval: 300
                onTriggered: centerIsland.wantsMusic = false
            }

            PopupWindow {
                id: musicPopup
                visible: centerIsland.wantsMusic && centerIsland._hasMusic
                grabFocus: false
                color: "transparent"
                implicitWidth: 400
                implicitHeight: 260

                anchor {
                    window: centerIsland
                    rect.x: {
                        if (BarConfig.side === "left")
                            return centerIsland.width;
                        if (BarConfig.side === "right")
                            return -musicPopup.implicitWidth;
                        return musicChip.implicitWidth / 2 - musicPopup.implicitWidth / 2;
                    }
                    rect.y: {
                        if (BarConfig.side === "bottom")
                            return -musicPopup.implicitHeight;
                        if (BarConfig.isVertical)
                            return centerIsland.height / 2 - musicPopup.implicitHeight / 2;
                        return centerIsland.height;
                    }
                }

                HoverHandler {
                    id: popupHover
                    onHoveredChanged: {
                        if (hovered) {
                            musicHideTimer.stop();
                            centerIsland.wantsMusic = true;
                        } else if (!musicChip.isHovered) {
                            musicHideTimer.restart();
                        }
                    }
                }

                Loader {
                    anchors.fill: parent
                    active: centerIsland._hasMusic
                    sourceComponent: MusicController {
                        popupVisible: musicPopup.visible
                    }
                }
            }
        }
    }

    PanelWindow {
        WlrLayershell.layer: WlrLayer.Top
        anchors {
            top: BarConfig.side !== "bottom"
            bottom: BarConfig.side === "bottom"
            left: BarConfig.side !== "right"
            right: BarConfig.side === "right"
        }
        exclusiveZone: -1
        implicitWidth: indicator.implicitWidth
        implicitHeight: indicator.implicitHeight
        color: "transparent"

        mask: Region {
            shape: indicator.maskShape
            x: indicator.maskX
            y: indicator.maskY
            width: indicator.maskWidth
            height: indicator.maskHeight
        }

        WorkspaceIndicator {
            id: indicator
            anchors.fill: parent
            corner: {
                if (BarConfig.side === "bottom")
                    return "bottomLeft";
                if (BarConfig.side === "right")
                    return "topRight";
                return "topLeft";
            }
        }
    }

    LockScreen {
        id: lockScreen
    }

    PolkitAuth {}

    FullscreenOverlay {
        id: keybindOverlay
        maxContentWidth: 1100
        maxContentHeight: 820
        content: Component {
            Keybinds {}
        }

        property bool _kbOpen: KeybindService.popupOpen
        on_KbOpenChanged: _kbOpen ? open() : close()

        onVisibleChanged: if (!visible)
            KeybindService.popupOpen = false
        onDimmerTapped: KeybindService.popupOpen = false
        onContentLoaded: item => item.focusSearch()
    }

    IpcHandler {
        target: "keybinds"
        function toggle() {
            KeybindService.popupOpen = !KeybindService.popupOpen;
        }
    }

    PanelWindow {
        id: homeOverlay

        readonly property int panelWidth: Math.round(1200 * UIScale.value)
        readonly property int panelHeight: Math.round(760 * UIScale.value)

        WlrLayershell.namespace: "zesis:homePanel"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        exclusiveZone: -1
        color: "transparent"

        anchors {
            top: true
            left: true
        }
        margins {
            top: Math.round((screen.height - panelHeight) / 2)
            left: Math.round((screen.width - panelWidth) / 2)
        }

        implicitWidth: panelWidth
        implicitHeight: panelHeight

        visible: HomePanelService.open
        onVisibleChanged: if (visible)
            homePanel.forceActiveFocus()

        HomePanel {
            id: homePanel
            anchors.fill: parent
        }
    }

    // PumpPanel {}
    // ValvePanel {}
    // WheelTest {}

    IpcHandler {
        target: "home"
        function toggle() {
            HomePanelService.open = !HomePanelService.open;
        }
    }

    FullscreenOverlay {
        id: appSwitcherOverlay
        dimmerOpacity: 0.60
        dimmerColor: "#0a0806"
        initialScale: 0.94
        showOvershoot: 1.1
        content: Component {
            AppSwitcher {}
        }

        property bool _asOpen: AppSwitcherService.open
        on_AsOpenChanged: _asOpen ? open() : close()

        onVisibleChanged: if (!visible)
            AppSwitcherService.open = false
        onDimmerTapped: AppSwitcherService.confirm()
        onContentLoaded: item => item.forceActiveFocus()
    }

    IpcHandler {
        target: "appswitcher"
        function cycle() {
            AppSwitcherService.mode === 1 ? AppSwitcherService.cycleWorkspaceForward() : AppSwitcherService.cycleForward();
        }
        function back() {
            AppSwitcherService.mode === 1 ? AppSwitcherService.cycleWorkspaceBack() : AppSwitcherService.cycleBack();
        }
        function confirm() {
            AppSwitcherService.mode === 1 ? AppSwitcherService.confirmWorkspace() : AppSwitcherService.confirm();
        }
        function cancel() {
            AppSwitcherService.cancel();
        }
    }

    WidgetHomeSidebar {}

    VolumeOsd {}

    // Desktop widgets
    IpcHandler {
        target: "desktop"
        function toggleConfig() {
            DesktopWidgetStore.configMode = !DesktopWidgetStore.configMode;
        }
    }

    DesktopConfigOverlay {}

    Instantiator {
        model: DesktopWidgetStore.enabledKeys
        delegate: DesktopWidget {
            required property string modelData
            storeKey: modelData
            content: DesktopWidgetCatalog.componentFor(modelData)
        }
    }

    // Notification toasts, top-right overlay, stacks below the bar
    PanelWindow {
        id: notifPanel
        readonly property real notifW: Math.round(340 * UIScale.value)

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: NotifServer.replyActive ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        anchors {
            top: true
            right: true
        }
        exclusiveZone: 0
        implicitWidth: notifW + 140
        implicitHeight: 600
        color: "transparent"
        visible: NotifServer.count > 0 && !NotifServer.muted

        Column {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 70
            anchors.rightMargin: 16
            spacing: 8
            width: notifPanel.notifW

            Repeater {
                model: NotifServer.notifications
                delegate: NotifItem {
                    required property var modelData
                    notification: modelData
                    width: parent.width
                }
            }
        }
    }
}
