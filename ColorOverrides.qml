pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Per-role overrides on top of the wallpaper-generated theme, kept separately
// for the dark and light palettes so switching modes picks the matching set up.
// A role that isn't in the map falls back to the generated theme, which is the
// default and what every existing config gets.
Singleton {
    id: root

    readonly property string _configDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/zesis"
    readonly property string _configPath: _configDir + "/coloroverrides.json"

    // Roles that exist in the generated theme (colors.json), in the order the
    // palette preview in the wallpaper panel shows them.
    readonly property var paletteRoles: [
        {
            id: "background",
            label: "bg",
            desc: "Panel and bar background"
        },
        {
            id: "surface_container",
            label: "surface",
            desc: "Cards, rows, popups"
        },
        {
            id: "surface_container_high",
            label: "surf+",
            desc: "Raised chips and inputs"
        },
        {
            id: "outline_variant",
            label: "border",
            desc: "Panel outlines"
        },
        {
            id: "primary",
            label: "primary",
            desc: "Accent: highlights, active state"
        },
        {
            id: "primary_fixed_dim",
            label: "p.dim",
            desc: "Dimmed accent"
        },
        {
            id: "primary_container",
            label: "p.cont",
            desc: "Accent-tinted fills"
        },
        {
            id: "on_primary",
            label: "on-p",
            desc: "Text drawn on the accent"
        },
        {
            id: "on_background",
            label: "text",
            desc: "Primary text"
        },
        {
            id: "on_surface_variant",
            label: "dim",
            desc: "Muted / secondary text"
        }
    ]

    // "bar" is not a theme role - it only exists as an override, so the bar can
    // be recolored without dragging every other panel's background with it.
    readonly property var roles: paletteRoles.concat([
        {
            id: "bar",
            label: "bar",
            desc: "Bar only, defaults to bg"
        }
    ])

    // Authoritative in memory, not bound to the adapter: the file write is
    // async, so reading edits back off disk would lose any change made before
    // the previous one landed. Disk only feeds back in via _adopt().
    property var dark: ({})
    property var light: ({})

    function forPalette(palette) {
        return palette === "dark" ? root.dark : root.light;
    }

    function get(palette, role) {
        var map = root.forPalette(palette);
        var v = map ? map[role] : "";
        return (v && root.isValid(v)) ? v : "";
    }

    function isOverridden(palette, role) {
        return root.get(palette, role).length > 0;
    }

    function set(palette, role, hex) {
        if (!root.isValid(hex))
            return;
        var d = root._copy(root.dark);
        var l = root._copy(root.light);
        var target = palette === "dark" ? d : l;
        target[role] = hex.trim().toLowerCase();
        root._save(d, l);
    }

    function clear(palette, role) {
        var d = root._copy(root.dark);
        var l = root._copy(root.light);
        delete (palette === "dark" ? d : l)[role];
        root._save(d, l);
    }

    function clearPalette(palette) {
        if (palette === "dark")
            root._save({}, root._copy(root.light));
        else
            root._save(root._copy(root.dark), {});
    }

    function isValid(hex) {
        return /^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test((hex || "").trim());
    }

    function _copy(map) {
        return map ? JSON.parse(JSON.stringify(map)) : ({});
    }

    function _save(d, l) {
        root.dark = d;
        root.light = l;
        root._pendingJson = JSON.stringify({
            dark: d,
            light: l
        });
        root._flush();
    }

    // A single writer, with the latest state queued behind whatever is in
    // flight - assigning to a running Process would drop the write.
    property string _pendingJson: ""

    function _flush() {
        if (writeProc.running || root._pendingJson.length === 0)
            return;
        var json = root._pendingJson;
        root._pendingJson = "";
        writeProc.command = ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$3\"", "--", root._configDir, json, root._configPath];
        writeProc.running = true;
    }

    // Pick the file up on startup and on external edits, but never on top of a
    // write we haven't finished issuing.
    function _adopt() {
        if (writeProc.running || root._pendingJson.length > 0)
            return;
        root.dark = root._copy(overrideData.dark);
        root.light = root._copy(overrideData.light);
    }

    JsonAdapter {
        id: overrideData
        property var dark: ({})
        property var light: ({})
    }

    Connections {
        target: overrideData
        function onDarkChanged() {
            root._adopt();
        }
        function onLightChanged() {
            root._adopt();
        }
    }

    FileView {
        path: root._configPath
        watchChanges: true
        adapter: overrideData // qmllint disable missing-type
        onFileChanged: reload()
        onLoaded: root._adopt()
    }

    Process {
        id: writeProc
        running: false
        onExited: root._flush()
    }
}
