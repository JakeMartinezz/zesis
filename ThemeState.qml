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
    property bool applying: false
    property string lastError: ""

    readonly property var wallpaperBackends: [
        {
            id: "awww",
            label: "awww",
            command: "awww img \"$1\" --transition-type fade --transition-duration 1"
        },
        {
            id: "swww",
            label: "swww",
            command: "swww img \"$1\" --transition-type fade --transition-duration 1"
        },
        {
            id: "hyprpaper",
            label: "hyprpaper",
            command: "hyprctl hyprpaper preload \"$1\" && hyprctl hyprpaper wallpaper \",$1\""
        },
        {
            id: "feh",
            label: "feh (X11)",
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
        }
    }

    function apply(wallpaperPath) {
        if (root.applying)
            return;
        root.applying = true;
        root.lastError = "";
        applyProcess._wallpaperPath = wallpaperPath;
        var setCmd = root._wallpaperSetCmd();
        var script = (setCmd.length > 0 ? setCmd + " && " : "") + "matugen image \"$1\" --source-color-index 0 --type \"$2\" --mode \"$3\"";
        applyProcess.command = ["bash", "-c", script, "--", wallpaperPath, root.schemeType, root.palette];
        applyProcess.running = true;
    }

    function togglePalette() {
        root.palette = (root.palette === "dark" ? "light" : "dark");
        root._persistState();
        if (root.applying || root.lastWallpaper === "")
            return;
        root.applying = true;
        root.lastError = "";
        applyProcess._wallpaperPath = root.lastWallpaper;
        applyProcess.command = ["bash", "-c", "matugen image \"$1\" --source-color-index 0 --type \"$2\" --mode \"$3\"", "--", root.lastWallpaper, root.schemeType, root.palette];
        applyProcess.running = true;
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
            schemeType: root.schemeType,
            wallpaperBackend: root.wallpaperBackend,
            customWallpaperCommand: root.customWallpaperCommand
        });
        saveProcess.command = ["bash", "-c", "printf '%s' \"$1\" > \"$2\"", "--", json, root._stateFile];
        saveProcess.running = true;
    }
}
