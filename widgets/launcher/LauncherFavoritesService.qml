pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Persisted, user-editable favorites row for the launcher. Starts out
// matching AGS's hardcoded options.launcher.apps.favorites, but from then on
// the user can add/remove apps themselves (star icon on a search result /
// right-click a favorite to unpin - see Launcher.qml).
Singleton {
    id: root

    readonly property string _configDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/zesis"
    readonly property string _configPath: _configDir + "/launcher-favorites.json"

    // "zen-twilight" (not "zen") - that's the actual installed .desktop id
    // (/run/current-system/sw/share/applications/zen-twilight.desktop),
    // heuristicLookup("zen") doesn't fuzzy-match it.
    property var ids: ["zen-twilight", "kitty", "org.gnome.Nautilus", "vesktop", "spotify"]

    function isFavorite(id) {
        return root.ids.indexOf(id) >= 0;
    }

    function add(id) {
        if (root.isFavorite(id))
            return;
        root.ids = root.ids.concat([id]);
        root._save();
    }

    function remove(id) {
        if (!root.isFavorite(id))
            return;
        root.ids = root.ids.filter(x => x !== id);
        root._save();
    }

    function toggle(id) {
        if (root.isFavorite(id))
            root.remove(id);
        else
            root.add(id);
    }

    function _save() {
        var json = JSON.stringify({
            ids: root.ids
        });
        saveProc.command = ["bash", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "--", root._configDir, json, root._configPath];
        saveProc.running = true;
    }

    JsonAdapter {
        id: favData
        property var ids: []
    }

    FileView {
        id: favFile
        path: root._configPath
        watchChanges: true
        adapter: favData // qmllint disable missing-type
        onLoaded: {
            if (favData.ids && favData.ids.length > 0)
                root.ids = favData.ids;
        }
        onFileChanged: reload()
    }

    Process {
        id: saveProc
    }
}
