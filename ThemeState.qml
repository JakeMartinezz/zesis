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
    property string schemeType: "scheme-tonal-spot"
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
            command: "bin=\"aw\"\"ww-daemon\"; pgrep -f \"$bin\" >/dev/null || { \"$bin\" >/dev/null 2>&1 & sleep 2; }; for m in $2; do awww img --outputs \"$m\" --transition-type center --transition-duration 1 \"$1\"; done"
        },
        {
            id: "swww",
            label: "swww",
            command: "bin=\"sw\"\"ww-daemon\"; pgrep -f \"$bin\" >/dev/null || { \"$bin\" >/dev/null 2>&1 & sleep 2; }; for m in $2; do swww img --outputs \"$m\" --transition-type center --transition-duration 1 \"$1\"; done"
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
            "awww": "bin=\"aw\"\"ww-daemon\"; for i in 1 2 3 4 5; do pgrep -f \"$bin\" >/dev/null && break; \"$bin\" >/dev/null 2>&1 & sleep 1; done",
            "swww": "bin=\"sw\"\"ww-daemon\"; for i in 1 2 3 4 5; do pgrep -f \"$bin\" >/dev/null && break; \"$bin\" >/dev/null 2>&1 & sleep 1; done"
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
        property string schemeType: "scheme-tonal-spot"
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
            root.schemeType = stateData.schemeType;
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

    // Sets the wallpaper for every monitor. This overwrites every output at the daemon
    // level, so it also wipes any per-monitor overrides (onExited below) and always
    // recomputes the system color scheme from it.
    function apply(wallpaperPath) {
        root._apply(wallpaperPath, "", true);
    }

    function applyToMonitor(wallpaperPath, monitor) {
        if (!monitor)
            return;
        root._apply(wallpaperPath, monitor, root.colorSourceMonitor === monitor);
    }

    function resetMonitor(monitor) {
        if (!monitor || !(monitor in root.perMonitorWallpaper))
            return;
        var next = Object.assign({}, root.perMonitorWallpaper);
        delete next[monitor];
        root.perMonitorWallpaper = next;
        root._persistState();
        // Re-run the backend command to visually sync the output, but don't let it
        // re-record an override, cause that's what we just cleared. Recolor if this
        // monitor was the color source, since its effective wallpaper just changed
        // back to global.
        if (root.lastWallpaper !== "")
            root._apply(root.lastWallpaper, monitor, root.colorSourceMonitor === monitor, false);
    }

    // Picks which monitor's wallpaper drives the system color scheme, and immediately
    // recomputes colors from whatever that monitor is currently showing.
    function setColorSourceMonitor(monitor) {
        if (root.colorSourceMonitor === monitor)
            return;
        root.colorSourceMonitor = monitor;
        root._persistState();
        var path = root._effectiveWallpaper(monitor);
        if (path !== "")
            root._recolor(path);
    }

    // Calls queued while one is already running (e.g. a theme applying a
    // different wallpaper to each monitor in turn) instead of being dropped -
    // the backend/matugen commands are one Process at a time, run
    // sequentially.
    property var _queue: []

    function _recolor(path) {
        if (root.applying) {
            root._queue.push({
                kind: "recolor",
                path: path
            });
            return;
        }
        root._runRecolor(path);
    }

    function _runRecolor(path) {
        root.applying = true;
        root.lastError = "";
        applyProcess._wallpaperPath = path;
        applyProcess._monitor = "";
        applyProcess._persistOverride = false;
        applyProcess.command = ["bash", "-c", "matugen image \"$1\" --source-color-index 0 --type \"$2\" --mode \"$3\"", "--", path, root.schemeType, root.palette];
        applyProcess.running = true;
    }

    function _apply(wallpaperPath, monitor, recolor, persistOverride = true) {
        if (root.applying) {
            root._queue.push({
                kind: "apply",
                wallpaperPath: wallpaperPath,
                monitor: monitor,
                recolor: recolor,
                persistOverride: persistOverride
            });
            return;
        }
        root._runApply(wallpaperPath, monitor, recolor, persistOverride);
    }

    // monitor: ShellScreen.name to target, or "" for all monitors - resolved
    // here to a real, space-separated monitor list either way, so the
    // backend command is never invoked without an explicit target.
    function _runApply(wallpaperPath, monitor, recolor, persistOverride) {
        root.applying = true;
        root.lastError = "";
        applyProcess._wallpaperPath = wallpaperPath;
        applyProcess._monitor = monitor;
        applyProcess._persistOverride = persistOverride;
        var targets = (monitor && monitor.length > 0) ? monitor : Quickshell.screens.map(s => s.name).join(" ");
        var parts = [root._wallpaperSetCmd()];
        if (recolor)
            parts.push("matugen image \"$1\" --source-color-index 0 --type \"$3\" --mode \"$4\"");
        applyProcess.command = ["bash", "-c", parts.join(" && "), "--", wallpaperPath, targets, root.schemeType, root.palette];
        applyProcess.running = true;
    }

    function _runNextQueued() {
        if (root._queue.length === 0)
            return;
        var next = root._queue.shift();
        if (next.kind === "recolor")
            root._runRecolor(next.path);
        else
            root._runApply(next.wallpaperPath, next.monitor, next.recolor, next.persistOverride);
    }

    function setWallpapersDirOverride(dir) {
        root.wallpapersDirOverride = dir;
        root._persistState();
    }

    function togglePalette() {
        root.palette = (root.palette === "dark" ? "light" : "dark");
        root._persistState();
        var path = root._effectiveWallpaper(root.colorSourceMonitor);
        if (path !== "")
            root._recolor(path);
    }

    Process {
        id: applyProcess
        property string _wallpaperPath: ""
        property string _monitor: ""
        property bool _persistOverride: true

        stderr: StdioCollector {
            id: applyStderr
        }

        onExited: (code, status) => { // qmllint disable signal-handler-parameters
            root.applying = false;
            if (code === 0) {
                if (applyProcess._persistOverride) {
                    if (applyProcess._monitor === "") {
                        root.lastWallpaper = applyProcess._wallpaperPath;
                        // A global apply just overwrote every output at the daemon level,
                        // so any per-monitor overrides we were tracking are stale now.
                        if (Object.keys(root.perMonitorWallpaper).length > 0)
                            root.perMonitorWallpaper = {};
                    } else {
                        var next = Object.assign({}, root.perMonitorWallpaper);
                        next[applyProcess._monitor] = applyProcess._wallpaperPath;
                        root.perMonitorWallpaper = next;
                    }
                }
                root._persistState();
                if (!hookProcess.running)
                    hookProcess.running = true;
            } else {
                root.lastError = applyStderr.text.trim() || ("Command exited with code " + code);
            }
            root._runNextQueued();
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
            schemeType: root.schemeType,
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
