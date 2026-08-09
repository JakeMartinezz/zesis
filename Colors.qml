pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string _themeDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/theme/zesis"

    readonly property var _p: ThemeState.palette === "dark" ? colorData.colors.dark : colorData.colors.light
    readonly property var darkPalette: colorData.colors.dark
    readonly property var lightPalette: colorData.colors.light

    // Named tokens, mapped from MD3 semantic roles
    property color bg: _p.background
    property color surface: _p.surface_container
    property color surfaceHigh: _p.surface_container_high
    property color outline: _p.outline_variant
    property color accent: _p.primary
    property color onAccent: _p.on_primary
    property color muted: _p.on_surface_variant
    property color text: _p.on_background
    property color textDim: _p.on_surface_variant
    property color barBg: withAlpha(bg, 0.85)

    function withAlpha(col, alpha) {
        var c = Qt.color(col);
        return Qt.rgba(c.r, c.g, c.b, alpha);
    }

    FileView {
        path: root._themeDir + "/colors.json"
        watchChanges: true
        adapter: colorData // qmllint disable missing-type
        onFileChanged: reload()
    }

    JsonAdapter {
        id: colorData
        property JsonObject colors: JsonObject {
            property JsonObject dark: JsonObject {
                property string background: "#282828"
                property string surface_container: "#3c3836"
                property string surface_container_high: "#504945"
                property string outline_variant: "#665c54"
                property string primary: "#71b877"
                property string primary_fixed_dim: "#609c65"
                property string on_primary: "#63452c"
                property string primary_container: "#425a44"
                property string on_background: "#ebdbb2"
                property string on_surface_variant: "#a89984"
            }
            property JsonObject light: JsonObject {
                property string background: "#fffffa"
                property string surface_container: "#f2ede4"
                property string surface_container_high: "#e5ddc9"
                property string outline_variant: "#cbbfa0"
                property string primary: "#426ede"
                property string primary_fixed_dim: "#3459b8"
                property string on_primary: "#eeeeee"
                property string primary_container: "#c9d6f5"
                property string on_background: "#080808"
                property string on_surface_variant: "#6b6255"
            }
        }
    }
}
