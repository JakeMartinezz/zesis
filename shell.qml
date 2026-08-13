pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "Widgets/Bar"
import "Widgets/Notifications"
import "Widgets/LockScreen"
import "Widgets/Keybinds"
import "Widgets/AppSwitcher"
import "Widgets/ThemeCycler"
import "Widgets/Power"
import "Widgets/Shared"
import "Widgets/WidgetHome"
import "Widgets/Polkit"
import "Widgets/Display"
import "Widgets/Calendar"
import "Widgets/Diaspora"
import "Widgets/Home"
import "Widgets/Settings"
import "Widgets/Sound"
import "Widgets/PumpPanel"
import "Widgets/Clock"
import "Widgets/Desktop"
import "Widgets/Taskbar"
import "Widgets/Launcher"
// These imports are needed for BarItemsService to function correctly
import "Widgets/Brightness"
import "Widgets/Mic"
import "Widgets/Battery"
import "Widgets/Record"

Scope {
    // Singletons instantiated at startup for startup-apply logic
    property string _displayInit: DisplayService.monitorName
    property var _calInit: CalendarService.events
    property bool _locationSharingInit: LocationSharingService.ready

    Variants {
        // Empty BarConfig.enabledMonitors = show on every monitor (default).
        // If none of the configured monitors are currently connected (e.g. the
        // laptop was undocked), fall back to showing on every monitor instead
        // of vanishing entirely - the saved preference is kept as-is and takes
        // effect again once a matching monitor reconnects.
        model: {
            if (BarConfig.enabledMonitors.length === 0)
                return Quickshell.screens;
            const matched = Quickshell.screens.filter(s => BarConfig.enabledMonitors.includes(s.name));
            return matched.length > 0 ? matched : Quickshell.screens;
        }
        delegate: PanelWindow {
            id: root

            required property ShellScreen modelData

            // Don't map the surface until the persisted edgeGap/side have actually
            // loaded - mapping with the compiled-in defaults first means the real
            // margin never gets committed to the compositor (see BarConfig.ready).
            visible: BarConfig.ready

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.margins {
                top: BarConfig.side === "top" ? BarConfig.edgeGap : 0
                bottom: BarConfig.side === "bottom" ? BarConfig.edgeGap : 0
            }
            screen: modelData

            // Strip = pill thickness on the short axis, full-edge span on the long axis.
            // This avoids any centering math, edgeGap is the only outer-gap knob.
            implicitHeight: Math.round(34 * UIScale.value)
            implicitWidth: 0

            anchors {
                top: BarConfig.side !== "bottom"
                bottom: BarConfig.side !== "top"
                left: true
                right: true
            }

            // A single continuous strip, like the AGS bar's flat `.bar { background-color: $bg }` -
            // individual widgets sit directly on it rather than floating in separate group pills.
            color: Colors.barBg

            // Gap kept between the taskbar/music island and the systray pill before the
            // tray starts collapsing
            readonly property real _islandGap: Math.round(16 * UIScale.value)

            SysTray {
                id: trayWidget
                x: parent.width - width - BarConfig.endGap
                y: 0
                // Budget = space from the island's right edge to the tray's own right
                // boundary. Depends only on islandRow's geometry, never trayWidget's own
                // width/x, so it can't be circular.
                maxWidth: Math.max(0, (root.width - BarConfig.endGap) - (islandRow.x + islandRow.width) - root._islandGap)
            }

            // No background/radius of its own - sits flush on the bar's continuous
            // surface, like AGS's start box (launcher + workspaces + media).
            Item {
                id: startPill
                readonly property real _pad: Math.round(10 * UIScale.value)

                x: BarConfig.endGap
                y: 0
                implicitWidth: startRow.implicitWidth + _pad
                implicitHeight: Math.round(34 * UIScale.value)

                Grid {
                    id: startRow
                    anchors.centerIn: parent
                    spacing: Math.round(4 * UIScale.value)
                    rows: 1
                    columns: -1

                    LauncherButton {
                        active: HomePanelService.open
                        onClicked: HomePanelService.open = !HomePanelService.open
                    }

                    Workspaces {
                        id: workspacesWidget
                    }
                }
            }

            // No background/radius of its own - sits flush on the bar's continuous
            // surface, like AGS's taskbar (each icon carries its own panel-button tint).
            Item {
                id: islandRow
                anchors.centerIn: parent
                implicitWidth: taskbarPill.implicitWidth
                implicitHeight: taskbarPill.implicitHeight

                Taskbar {
                    id: taskbarPill
                }
            }

            Connections {
                target: LockService
                function onLockRequested() {
                    lockScreen.triggerLock();
                }
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

        readonly property int panelWidth: Math.round(1360 * UIScale.value)
        readonly property int panelHeight: Math.round(860 * UIScale.value)

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

    Launcher {}

    IpcHandler {
        target: "launcher"
        function toggle() {
            LauncherService.toggle();
        }
    }

    PanelWindow {
        id: settingsWindow

        implicitWidth: Math.round(1360 * UIScale.value)
        implicitHeight: Math.round(860 * UIScale.value)

        WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        visible: SettingsPanelService.open
        onVisibleChanged: if (visible)
            settingsPanel.forceActiveFocus()

        SettingsPanel {
            id: settingsPanel
            anchors.fill: parent
        }
    }

    IpcHandler {
        target: "settings"
        function toggle() {
            SettingsPanelService.open = !SettingsPanelService.open;
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

    FullscreenOverlay {
        id: themeCyclerOverlay
        dimmerOpacity: 0.60
        dimmerColor: "#0a0806"
        initialScale: 0.94
        showOvershoot: 1.1
        content: Component {
            ThemeCycler {}
        }

        property bool _tcOpen: ThemeCyclerService.open
        on_TcOpenChanged: _tcOpen ? open() : close()

        onVisibleChanged: if (!visible)
            ThemeCyclerService.open = false
        onDimmerTapped: ThemeCyclerService.confirm()
        onContentLoaded: item => item.forceActiveFocus()
    }

    IpcHandler {
        target: "themecycler"
        function cycle() {
            ThemeCyclerService.cycleForward();
        }
        function back() {
            ThemeCyclerService.cycleBack();
        }
        function confirm() {
            ThemeCyclerService.confirm();
        }
        function cancel() {
            ThemeCyclerService.cancel();
        }
    }

    FullscreenOverlay {
        id: powerOverlay
        maxContentWidth: 520
        maxContentHeight: 200
        content: Component {
            PowerMenu {
                onCloseRequested: powerOverlay.close()
            }
        }

        onDimmerTapped: powerOverlay.close()
        onContentLoaded: item => item.focusMenu()
    }

    IpcHandler {
        target: "power"
        function toggle() {
            powerOverlay.visible ? powerOverlay.close() : powerOverlay.open();
        }
    }

    WidgetHomeSidebar {}

    VolumeOsd {}

    MicOsd {}

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
