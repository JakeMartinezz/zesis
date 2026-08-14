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

    // The wallpaper's own matugen output, with no overrides merged in - the
    // baseline "isCustomized" checks compare against, so a role that was
    // written into an override (e.g. by applying a saved theme) but happens
    // to match what this wallpaper would generate anyway doesn't read as
    // user-modified.
    readonly property var rawDarkPalette: colorData.colors.dark
    readonly property var rawLightPalette: colorData.colors.light

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
                property string background: "#120d08"
                property string surface_container: "#1e1510"
                property string surface_container_high: "#2a1e15"
                property string outline_variant: "#3d2c1e"
                property string primary: "#FFB97C"
                property string primary_fixed_dim: "#FFB97C"
                property string on_primary: "#1A100A"
                property string primary_container: "#8B6240"
                property string on_background: "#F5E6CE"
                property string on_surface_variant: "#A09080"
            }
            property JsonObject light: JsonObject {
                property string background: "#fdf6ee"
                property string surface_container: "#f0e8de"
                property string surface_container_high: "#e3d9cc"
                property string outline_variant: "#c5b8a8"
                property string primary: "#8B5A2B"
                property string primary_fixed_dim: "#FFB97C"
                property string on_primary: "#FFFFFF"
                property string primary_container: "#d4aa80"
                property string on_background: "#1a1008"
                property string on_surface_variant: "#4a3828"
            }
        }
    }
}
