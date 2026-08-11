pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Named, portable snapshots of a full dark+light color set - independent of
// ColorOverrides' live wallpaper/global scope. Saving a theme captures
// whatever colors are effectively showing right now (matugen's own
// generation for the current wallpaper, or a hand-tweaked override, doesn't
// matter which). Applying one just re-plays that snapshot through
// ColorOverrides.set(), one role at a time, so it lands in whichever scope
// (per-wallpaper or global) is currently active there - no separate
// merge/write path to keep in sync.
Singleton {
    id: root

    readonly property string _configDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/zesis"
    readonly property string _configPath: _configDir + "/colorthemes.json"

    property var themes: [] // [{name, dark: {role: hex}, light: {role: hex}}]

    function _indexOf(name) {
        for (var i = 0; i < root.themes.length; i++) {
            if (root.themes[i].name === name)
                return i;
        }
        return -1;
    }

    function exists(name) {
        return root._indexOf(name) >= 0;
    }

    // Snapshots the colors currently in effect under `name`, overwriting
    // any theme already saved under that exact name.
    function save(name) {
        var trimmed = (name || "").trim();
        if (trimmed.length === 0)
            return;
        var entry = {
            name: trimmed,
            dark: root._snapshot("dark"),
            light: root._snapshot("light")
        };
        var list = root.themes.slice();
        var idx = root._indexOf(trimmed);
        if (idx >= 0)
            list[idx] = entry;
        else
            list.push(entry);
        root._save(list);
    }

    function _snapshot(palette) {
        var src = palette === "dark" ? Colors.darkPalette : Colors.lightPalette;
        var out = {};
        for (var i = 0; i < ColorOverrides.paletteRoles.length; i++) {
            var id = ColorOverrides.paletteRoles[i].id;
            out[id] = src[id];
        }
        var bar = ColorOverrides.get(palette, "bar");
        if (bar.length > 0)
            out.bar = bar;
        return out;
    }

    // Writes every role of the theme into ColorOverrides, in whatever scope
    // (per-wallpaper or global) is currently active there.
    function apply(name) {
        var idx = root._indexOf(name);
        if (idx < 0)
            return;
        var entry = root.themes[idx];
        root._applyPalette("dark", entry.dark);
        root._applyPalette("light", entry.light);
    }

    function _applyPalette(palette, roleMap) {
        for (var role in roleMap)
            ColorOverrides.set(palette, role, roleMap[role]);
    }

    function remove(name) {
        var idx = root._indexOf(name);
        if (idx < 0)
            return;
        var list = root.themes.slice();
        list.splice(idx, 1);
        root._save(list);
    }

    function _save(list) {
        root.themes = list;
        root._pendingJson = JSON.stringify({
            themes: list
        });
        root._flush();
    }

    property string _pendingJson: ""

    function _flush() {
        if (writeProc.running || root._pendingJson.length === 0)
            return;
        var json = root._pendingJson;
        root._pendingJson = "";
        writeProc.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "--", root._configDir, json, root._configPath];
        writeProc.running = true;
    }

    function _adopt() {
        if (writeProc.running || root._pendingJson.length > 0)
            return;
        root.themes = themeData.themes ? JSON.parse(JSON.stringify(themeData.themes)) : [];
    }

    JsonAdapter {
        id: themeData
        property var themes: []
    }

    Connections {
        target: themeData
        function onThemesChanged() {
            root._adopt();
        }
    }

    FileView {
        path: root._configPath
        watchChanges: true
        adapter: themeData // qmllint disable missing-type
        onFileChanged: reload()
        onLoaded: root._adopt()
    }

    Process {
        id: writeProc
        running: false
        onExited: root._flush()
    }
}
