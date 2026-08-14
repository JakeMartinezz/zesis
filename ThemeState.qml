pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string _home: Quickshell.env("HOME")
    readonly property string _cacheDir: _home + "/.cache/zesis"
    readonly property string _stateFile: _cacheDir + "/state.json"
    readonly property string thumbsDir: _cacheDir + "/thumbs"

    property string palette: "dark"
    property string lastWallpaper: ""
    property string wallpaperBackend: "awww"
    property string customWallpaperCommand: ""
    // "" means the default, ~/Pictures/Wallpapers.
    property string wallpapersDirOverride: ""
    readonly property string wallpapersDir: root.wallpapersDirOverride !== "" ? root.wallpapersDirOverride : (root._home + "/Pictures/Wallpapers")
    property bool autoStartWallpaperDaemon: true
    property bool applying: false
    property string lastError: ""
    // Per-monitor overrides: { "DP-1": "/path/to/wall.png", ... }. A monitor with no entry
    // here just shows lastWallpaper.
    property var perMonitorWallpaper: ({})
    // Which monitor's wallpaper drives matugen. "" = the global/all-monitors wallpaper
    property string colorSourceMonitor: ""

    // Backend commands take two positional args: $1 image path, $2 space-separated
    // list of target monitor names (always at least one real name, never
    // empty/omitted - awww/swww's daemon panics with "malformed answer" if you
    // ever call it without an explicit --outputs target, confirmed against a
    // known-working reference script that always loops per-monitor and never
    // calls it bare).
    readonly property var wallpaperBackends: [
        {
            id: "awww",
            label: "awww",
            command: "pgrep -f awww-daemon >/dev/null || { awww-daemon >/dev/null 2>&1 & sleep 2; }; for m in $2; do awww img --outputs \"$m\" --transition-type center --transition-duration 1 \"$1\"; done"
        },
        {
            id: "swww",
            label: "swww",
            command: "pgrep -f swww-daemon >/dev/null || { swww-daemon >/dev/null 2>&1 & sleep 2; }; for m in $2; do swww img --outputs \"$m\" --transition-type center --transition-duration 1 \"$1\"; done"
        },
        {
            id: "hyprpaper",
            label: "hyprpaper",
            command: "hyprctl hyprpaper preload \"$1\" && for m in $2; do hyprctl hyprpaper wallpaper \"$m,$1\"; done"
        },
        {
            id: "feh",
            label: "feh (X11, always all monitors)",
            command: "feh --bg-fill \"$1\""
        },
        {
            id: "custom",
            label: "Custom command...",
            command: ""
        }
    ]

    function _wallpaperSetCmd() {
        if (root.wallpaperBackend === "custom")
            return root.customWallpaperCommand.trim();
        for (var i = 0; i < root.wallpaperBackends.length; i++) {
            if (root.wallpaperBackends[i].id === root.wallpaperBackend)
                return root.wallpaperBackends[i].command;
        }
        return root.wallpaperBackends[0].command;
    }

    // Backends that need a persistent daemon running before `apply()` can
    // talk to them (AGS starts awww-daemon the same way on its own startup).
    // Run at zesis startup, which on this system can race the compositor's
    // layer-shell protocol not being ready yet right after login/boot - the
    // daemon opens its background layer then immediately dies, and a single
    // fire-and-forget start never notices or retries. Retry a few times a
    // second apart instead of trying once.
    readonly property var _daemonStartCommands: ({
            "awww": "for i in 1 2 3 4 5; do pgrep -f awww-daemon >/dev/null && break; awww-daemon >/dev/null 2>&1 & sleep 1; done",
            "swww": "for i in 1 2 3 4 5; do pgrep -f swww-daemon >/dev/null && break; swww-daemon >/dev/null 2>&1 & sleep 1; done"
        })

    function _ensureDaemonRunning() {
        if (!root.autoStartWallpaperDaemon)
            return;
        var cmd = root._daemonStartCommands[root.wallpaperBackend];
        if (!cmd)
            return;
        daemonStartProcess.command = ["bash", "-c", cmd];
        daemonStartProcess.running = true;
    }

    Process {
        id: daemonStartProcess
    }

    Component.onCompleted: root._ensureDaemonRunning()
    onWallpaperBackendChanged: root._ensureDaemonRunning()

    Process {
        command: ["mkdir", "-p", root.thumbsDir]
        running: true
    }

    JsonAdapter {
        id: stateData
        property string palette: "dark"
        property string lastWallpaper: ""
        property string wallpaperBackend: "awww"
        property string customWallpaperCommand: ""
        property string wallpapersDirOverride: ""
        property bool autoStartWallpaperDaemon: true
        property var perMonitorWallpaper: ({})
        property string colorSourceMonitor: ""
    }

    FileView {
        path: root._stateFile
        adapter: stateData // qmllint disable missing-type
        onLoaded: {
            root.palette = stateData.palette;
            root.lastWallpaper = stateData.lastWallpaper;
            root.wallpaperBackend = stateData.wallpaperBackend;
            root.customWallpaperCommand = stateData.customWallpaperCommand;
            root.wallpapersDirOverride = stateData.wallpapersDirOverride;
            root.autoStartWallpaperDaemon = stateData.autoStartWallpaperDaemon;
            root.perMonitorWallpaper = stateData.perMonitorWallpaper || ({});
            root.colorSourceMonitor = stateData.colorSourceMonitor;
        }
    }

    // "" resolves to the global wallpaper - the effective wallpaper for a
    // monitor with no per-monitor override of its own.
    function _effectiveWallpaper(monitor) {
        if (!monitor)
            return root.lastWallpaper;
        return root.perMonitorWallpaper[monitor] || root.lastWallpaper;
    }

    // Calls queued while one is already running (e.g. a theme applying a
    // different wallpaper to each monitor in turn) instead of being dropped -
    // the backend commands are one Process at a time, run sequentially.
    property var _queue: []

    // Sets the wallpaper for every monitor, clearing any per-monitor splits -
    // a global apply overwrites every output at the daemon level anyway.
    function apply(wallpaperPath) {
        root._enqueueOrRun(wallpaperPath, "");
    }

    function applyToMonitor(wallpaperPath, monitor) {
        if (!monitor)
            return;
        root._enqueueOrRun(wallpaperPath, monitor);
    }

    function resetMonitor(monitor) {
        if (!monitor || !(monitor in root.perMonitorWallpaper))
            return;
        var next = Object.assign({}, root.perMonitorWallpaper);
        delete next[monitor];
        root.perMonitorWallpaper = next;
        root._persistState();
        // Re-run the backend command to visually sync the output back to the
        // global wallpaper, now that this monitor's override is gone.
        if (root.lastWallpaper !== "")
            root.applyToMonitor(root.lastWallpaper, monitor);
    }

    // Picks which monitor's wallpaper drives the system color scheme, and
    // immediately recomputes colors from whatever that monitor is showing.
    function setColorSourceMonitor(monitor) {
        root.colorSourceMonitor = monitor;
        root._persistState();
        if (!hookProcess.running)
            hookProcess.running = true;
    }

    function _enqueueOrRun(wallpaperPath, monitor) {
        if (root.applying) {
            root._queue.push({
                path: wallpaperPath,
                monitor: monitor
            });
            return;
        }
        root._runApply(wallpaperPath, monitor);
    }

    // monitor: ShellScreen.name to target, or "" for all monitors - resolved
    // here to a real, space-separated monitor list either way, so the
    // backend command is never invoked without an explicit target.
    function _runApply(wallpaperPath, monitor) {
        root.applying = true;
        root.lastError = "";
        applyProcess._wallpaperPath = wallpaperPath;
        applyProcess._targetMonitor = monitor;
        var targets = (monitor && monitor.length > 0) ? monitor : Quickshell.screens.map(s => s.name).join(" ");
        applyProcess.command = ["bash", "-c", root._wallpaperSetCmd(), "--", wallpaperPath, targets];
        applyProcess.running = true;
    }

    function setWallpapersDirOverride(dir) {
        root.wallpapersDirOverride = dir;
        root._persistState();
    }

    function togglePalette() {
        root.palette = (root.palette === "dark" ? "light" : "dark");
        root._persistState();
    }

    Process {
        id: applyProcess
        property string _wallpaperPath: ""
        property string _targetMonitor: ""

        stderr: StdioCollector {
            id: applyStderr
        }

        onExited: (code, status) => { // qmllint disable signal-handler-parameters
            root.applying = false;
            if (code === 0) {
                root.lastWallpaper = applyProcess._wallpaperPath;
                if (applyProcess._targetMonitor === "") {
                    root.perMonitorWallpaper = ({});
                } else {
                    var m = Object.assign({}, root.perMonitorWallpaper);
                    m[applyProcess._targetMonitor] = applyProcess._wallpaperPath;
                    root.perMonitorWallpaper = m;
                }
                root._persistState();
                if (!hookProcess.running)
                    hookProcess.running = true;
            } else {
                root.lastError = applyStderr.text.trim() || ("Command exited with code " + code);
            }
            if (root._queue.length > 0) {
                var next = root._queue.shift();
                root._runApply(next.path, next.monitor);
            }
        }
    }

    Process {
        id: hookProcess
        command: ["bash", "-c", "hook=\"$1\"; [ -x \"$hook\" ] && exec \"$hook\"", "--", root._home + "/.config/zesis/on-theme-change"]
    }

    Process {
        id: saveProcess
    }

    function _persistState() {
        var json = JSON.stringify({
            palette: root.palette,
            lastWallpaper: root.lastWallpaper,
            wallpaperBackend: root.wallpaperBackend,
            customWallpaperCommand: root.customWallpaperCommand,
            wallpapersDirOverride: root.wallpapersDirOverride,
            autoStartWallpaperDaemon: root.autoStartWallpaperDaemon,
            perMonitorWallpaper: root.perMonitorWallpaper,
            colorSourceMonitor: root.colorSourceMonitor
        });
        saveProcess.command = ["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "--", json, root._stateFile];
        saveProcess.running = true;
    }
}
