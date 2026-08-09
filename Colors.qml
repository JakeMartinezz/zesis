pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string _themeDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/theme/zesis"

    // Generated theme with the user's per-role overrides applied on top, so
    // every consumer (the tokens below, the palette preview in the wallpaper
    // panel) sees the same effective colors. See ColorOverrides.
    readonly property var darkPalette: _merge(colorData.colors.dark, ColorOverrides.dark)
    readonly property var lightPalette: _merge(colorData.colors.light, ColorOverrides.light)
    readonly property var _p: ThemeState.palette === "dark" ? darkPalette : lightPalette

    function _merge(base, overrides) {
        var roles = ColorOverrides.paletteRoles;
        var out = {};
        for (var i = 0; i < roles.length; i++) {
            var key = roles[i].id;
            var ov = overrides ? overrides[key] : "";
            out[key] = (ov && ColorOverrides.isValid(ov)) ? ov : base[key];
        }
        return out;
    }

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
    // The bar can be recolored on its own; unset it just tracks the background.
    readonly property string _barOverride: ColorOverrides.get(ThemeState.palette, "bar")
    property color barBg: withAlpha(_barOverride.length > 0 ? _barOverride : bg, 0.85)

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
