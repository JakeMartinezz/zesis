pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../Wm"

// Blank, title-less cards used to appear in the switcher, rarely and hard to
// replicate - see the `windows` filter below for the likely cause (toplevels
// Hyprland's IPC hasn't populated yet) and mitigation.
Singleton {
    id: root

    property bool open: false
    property int selectedIndex: 0

    // 0 = single-window cards, 1 = workspace grid
    property int mode: 0

    // Settings (persisted)
    property int defaultMode: settingsData.defaultMode
    property bool confirmOnRelease: settingsData.confirmOnRelease
    property string newWorkspaceStrategy: settingsData.newWorkspaceStrategy
    property bool rememberLastMode: settingsData.rememberLastMode
    property bool followMovedWindow: settingsData.followMovedWindow

    // Runtime only, tracks whether switcher has been opened this session
    property bool _everOpened: false

    readonly property string _configDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/zesis"
    readonly property string _configPath: _configDir + "/appswitcher.json"

    property bool _loaded: false
    Component.onCompleted: Qt.callLater(function () {
        root._loaded = true;
    })

    onDefaultModeChanged: if (_loaded)
        _write()
    onConfirmOnReleaseChanged: if (_loaded)
        _write()
    onNewWorkspaceStrategyChanged: if (_loaded)
        _write()
    onRememberLastModeChanged: if (_loaded)
        _write()
    onFollowMovedWindowChanged: if (_loaded)
        _write()

    function _write() {
        writeProc.command = ["sh", "-c", "mkdir -p '" + root._configDir + "' && echo '" + JSON.stringify({
                defaultMode: root.defaultMode,
                confirmOnRelease: root.confirmOnRelease,
                newWorkspaceStrategy: root.newWorkspaceStrategy,
                rememberLastMode: root.rememberLastMode,
                followMovedWindow: root.followMovedWindow
            }) + "' > '" + root._configPath + "'"];
        writeProc.running = true;
    }

    JsonAdapter {
        id: settingsData
        property int defaultMode: 0
        property bool confirmOnRelease: true
        property string newWorkspaceStrategy: "fill"
        property bool rememberLastMode: false
        property bool followMovedWindow: false
    }

    FileView {
        path: root._configPath
        adapter: settingsData // qmllint disable missing-type
    }

    Process {
        id: writeProc
        running: false
    }

    function nextWorkspaceId() {
        var ids = WmService.workspaces.map(w => parseInt(w.name)).filter(n => !isNaN(n) && n > 0).sort((a, b) => a - b);
        if (root.newWorkspaceStrategy === "fill") {
            for (var i = 1; ; i++) {
                if (ids.indexOf(i) === -1)
                    return i;
            }
        }
        return ids.length > 0 ? ids[ids.length - 1] + 1 : 1;
    }

    property int selectedWorkspace: {
        var ws = WmService.focusedMonitor?.activeWorkspace;
        return ws ? (parseInt(ws.name) || 1) : 1;
    }

    function cycleWorkspaceForward() {
        if (!open) {
            show();
            return;
        }
        var ids = WmService.workspaces.map(w => parseInt(w.name)).filter(n => !isNaN(n)).sort((a, b) => a - b);
        if (ids.length === 0)
            return;
        var idx = ids.indexOf(selectedWorkspace);
        selectedWorkspace = ids[(idx + 1) % ids.length];
    }

    function cycleWorkspaceBack() {
        if (!open) {
            show();
            return;
        }
        var ids = WmService.workspaces.map(w => parseInt(w.name)).filter(n => !isNaN(n)).sort((a, b) => a - b);
        if (ids.length === 0)
            return;
        var idx = ids.indexOf(selectedWorkspace);
        selectedWorkspace = ids[(idx - 1 + ids.length) % ids.length];
    }

    function confirmWorkspace() {
        if (!open)
            return;
        var ws = selectedWorkspace;
        open = false;
        WmService.focusWorkspace(ws);
    }

    // onOpenChanged: console.log("[AppSwitcher] open =", open, "| windows =", windows.length)

    // Sorted by focusHistoryID ascending: index 0 = current window, 1 = most recently used, etc.
    // Filters out toplevels Hyprland's IPC hasn't populated yet - when several
    // windows open in a burst (e.g. a browser restoring many tabs as separate
    // windows), Quickshell's Hyprland.toplevels can briefly list one before
    // its lastIpcObject (address/class/title, delivered over a separate IPC
    // socket from the Wayland surface creation itself) has arrived, which is
    // what used to show up here as a blank, title-less card. It fills in on
    // its own moments later, so skipping it now just avoids the empty flash
    // rather than losing the window - it reappears once populated since this
    // is a reactive binding.
    readonly property var windows: {
        var tops = WmService.toplevels.filter(t => t.lastIpcObject && t.lastIpcObject["address"]);
        tops.sort((a, b) => {
            var fa = (a.lastIpcObject && "focusHistoryID" in a.lastIpcObject) ? a.lastIpcObject["focusHistoryID"] : 9999;
            var fb = (b.lastIpcObject && "focusHistoryID" in b.lastIpcObject) ? b.lastIpcObject["focusHistoryID"] : 9999;
            return fa - fb;
        });
        return tops;
    }

    onWindowsChanged: {
        // console.log("[AppSwitcher] windows changed, count =", windows.length, "| open =", open);
        if (selectedIndex >= windows.length)
            selectedIndex = Math.max(0, windows.length - 1);
    }

    function show() {
        // console.log("[AppSwitcher] show() called, windows =", windows.length);
        // Refresh unconditionally, before the emptiness check - refreshing
        // only on a non-empty list means a momentarily-stale/empty read (the
        // Hyprland-side list not having caught up yet) short-circuits below
        // and never asks for fresh data, so it stays stuck empty until
        // something ELSE happens to trigger a refresh.
        WmService.refreshToplevels();
        WmService.refreshMonitors();
        if (windows.length === 0)
            return;
        // Start at 1: skip current window, land on last-used
        selectedIndex = windows.length > 1 ? 1 : 0;
        if (!root.rememberLastMode || !root._everOpened)
            mode = root.defaultMode;
        _everOpened = true;
        open = true;
    }

    // Standalone entry point: opens straight into the workspace grid,
    // bypassing the app-switcher windows list (and its empty-list gate,
    // since an empty workspace set is still worth showing).
    function showWorkspaces() {
        WmService.refreshToplevels();
        WmService.refreshMonitors();
        mode = 1;
        _everOpened = true;
        open = true;
    }

    function cycleForward() {
        // console.log("[AppSwitcher] cycleForward(), open =", open);
        if (!open) {
            show();
            return;
        }
        if (windows.length === 0)
            return;
        selectedIndex = (selectedIndex + 1) % windows.length;
    }

    function cycleBack() {
        // console.log("[AppSwitcher] cycleBack(), open =", open);
        if (!open) {
            show();
            // show() lands on index 1, step to last window instead
            if (windows.length > 2)
                selectedIndex = windows.length - 1;
            return;
        }
        if (windows.length === 0)
            return;
        selectedIndex = (selectedIndex - 1 + windows.length) % windows.length;
    }

    function confirm() {
        // console.log("[AppSwitcher] confirm(), open =", open);
        if (!open)
            return;
        var idx = selectedIndex;
        var wins = windows;
        open = false;
        if (idx >= 0 && idx < wins.length) {
            var win = wins[idx];
            if (win && win.lastIpcObject) {
                var addr = win.lastIpcObject["address"];
                if (addr) {
                    // Hyprland's own focuswindow drops the previously-focused
                    // window out of fullscreen/maximize and lands on the
                    // target tiled - if we were leaving one of those, restore
                    // the same maximized (not true fullscreen, that would
                    // hide the bar) look on whatever we land on, unless it's
                    // already in that state itself (this dispatch toggles,
                    // so re-firing it on an already-maximized target would
                    // turn it back off).
                    var wasFullscreen = WmService.focusedHasFullscreen;
                    var targetAlreadyFullscreen = !!win.lastIpcObject["fullscreen"];
                    WmService.focusWindow(addr);
                    if (wasFullscreen && !targetAlreadyFullscreen)
                        WmService.maximizeActive();
                }
            }
        }
    }

    function cancel() {
        // console.log("[AppSwitcher] cancel(), open =", open);
        open = false;
    }
}
