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
    property string wallpaperFolder: _home + "/Pictures/Wallpapers"
    property bool applying: false
    property string lastError: ""

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
            command: "pgrep -x awww-daemon >/dev/null || { awww-daemon >/dev/null 2>&1 & sleep 2; }; for m in $2; do awww img --outputs \"$m\" --transition-type fade --transition-duration 1 \"$1\"; done"
        },
        {
            id: "swww",
            label: "swww",
            command: "pgrep -x swww-daemon >/dev/null || { swww-daemon >/dev/null 2>&1 & sleep 2; }; for m in $2; do swww img --outputs \"$m\" --transition-type fade --transition-duration 1 \"$1\"; done"
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
    readonly property var _daemonStartCommands: ({
            "awww": "pgrep -x awww-daemon >/dev/null || { awww-daemon >/dev/null 2>&1 & }",
            "swww": "pgrep -x swww-daemon >/dev/null || { swww-daemon >/dev/null 2>&1 & }"
        })

    function _ensureDaemonRunning() {
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
        property string wallpaperFolder: ""
    }

    FileView {
        path: root._stateFile
        adapter: stateData // qmllint disable missing-type
        onLoaded: {
            root.palette = stateData.palette;
            root.lastWallpaper = stateData.lastWallpaper;
            root.wallpaperBackend = stateData.wallpaperBackend;
            root.customWallpaperCommand = stateData.customWallpaperCommand;
            root.wallpaperFolder = stateData.wallpaperFolder || (root._home + "/Pictures/Wallpapers");
        }
    }

    // monitor: ShellScreen.name to target, or "" for all monitors (default) -
    // resolved here to a real, space-separated monitor list either way, so the
    // backend command is never invoked without an explicit target.
    function apply(wallpaperPath, monitor) {
        if (root.applying)
            return;
        root.applying = true;
        root.lastError = "";
        applyProcess._wallpaperPath = wallpaperPath;
        var targets = (monitor && monitor.length > 0) ? monitor : Quickshell.screens.map(s => s.name).join(" ");
        applyProcess.command = ["bash", "-c", root._wallpaperSetCmd(), "--", wallpaperPath, targets];
        applyProcess.running = true;
    }

    function setWallpaperFolder(path) {
        root.wallpaperFolder = path;
        root._persistState();
    }

    function togglePalette() {
        root.palette = (root.palette === "dark" ? "light" : "dark");
        root._persistState();
    }

    Process {
        id: applyProcess
        property string _wallpaperPath: ""

        stderr: StdioCollector {
            id: applyStderr
        }

        onExited: (code, status) => { // qmllint disable signal-handler-parameters
            root.applying = false;
            if (code === 0) {
                root.lastWallpaper = applyProcess._wallpaperPath;
                root._persistState();
                if (!hookProcess.running)
                    hookProcess.running = true;
            } else {
                root.lastError = applyStderr.text.trim() || ("Command exited with code " + code);
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
            wallpaperFolder: root.wallpaperFolder
        });
        saveProcess.command = ["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "--", json, root._stateFile];
        saveProcess.running = true;
    }
}
