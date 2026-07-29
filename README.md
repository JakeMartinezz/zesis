# zesis

*ζέσις - Greek for "boiling", "seething": the act of bubbling up with heat or fervor*

A graphical shell with a mind of its own, using [Quickshell](https://quickshell.outfoxxed.me), targeting Wayland compositors.

Contributions and adaptations are welcome - the config is written to be portable across user systems rather than hardcoded to a specific machine.

---

## Requirements

### Required
- [Quickshell](https://quickshell.outfoxxed.me) (Qt 6)
- [Matugen](https://github.com/InioX/matugen)
- A Wayland compositor that implements `wlr-layer-shell`
- A [Nerd Font](https://www.nerdfonts.com/) or the `nerd-fonts.symbols-only` package for icons
- One wallpaper-setting backend: [awww](https://codeberg.org/LGFae/awww) (default), [swww](https://codeberg.org/LGFae/awww), `hyprpaper`, `feh`, or a custom command, configurable in the Wallpaper settings panel

### Optional
- Hyprland - workspace/window management, keybind cheatsheet, display picker (only backend currently implemented)
- `ext-session-lock` compositor support + PAM configuration - lock screen (see below)
- `avahi` + `smbclient` + `keyutils` - Network widget
- [athroisma](https://github.com/zesis-shell/athroisma) - System Monitor widget (see below)
- `python3` + [`icalendar`](https://pypi.org/project/icalendar/) + [`recurring-ical-events`](https://pypi.org/project/recurring-ical-events/) - Calendar widget (parses `.ics` files and expands recurring events).
- magick (wallpaper preview)
- awk (for credential search)
- QtQuick3D + QtDeclarative (Qt 6.6+) and [Congeries](https://github.com/zesis-shell/congeries) - 3D geodesic rod globe (Home panel, dev-mode). Without these the panel falls back to a "3D globe unavailable" message, the rest of zesis is unaffected.

## Setup

Clone the repo and point Quickshell at it:

```sh
git clone https://github.com/zesis-shell/zesis ~/.config/quickshell
quickshell
```

### Lock screen (NixOS)

Add PAM support for the lock screen in your NixOS config:

```nix
security.pam.services.quickshell = {};
```

### Other distros

Create `/etc/pam.d/quickshell` with contents appropriate for your system (typically mirroring `login` or `swaylock`).

### Compiling shaders

`ShaderEffect`-based widgets (currently the 2D globe) load a pre-baked `.qsb` binary, not the `.frag` source directly - `*.qsb` files are gitignored build artifacts, so they need to be compiled locally before those widgets will render. If a `.qsb` is missing or invalid, the affected widget shows an on-screen warning.

With Nix:

```sh
nix run .#compile-shaders
```

Without Nix, `qsb` comes from Qt's `qtshadertools` module, on most distros this is a separate package from Qt/Quickshell itself and often isn't pulled in automatically (e.g. on Arch, `qt6-shadertools` is only a *build-time* dependency of the `quickshell` package, not a runtime one), so you may need to install it explicitly:

```sh
# Arch
sudo pacman -S qt6-shadertools
```

Then run `qsb` directly for each `.frag` file:

```sh
qsb --qt6 -o Widgets/Globe2D/GlobeShader/globe.qsb Widgets/Globe2D/GlobeShader/globe.frag
```

### System monitor (athroisma)

The System Monitor widget shells out to a bare `athroisma` command, so it needs to be on `PATH`, it's otherwise entirely optional, the rest of zesis is unaffected if it's missing.

With Nix, `flake.nix` already declares `athroisma` as a flake input and puts it on the devshell's `PATH`, but again that only covers `nix develop`.

Arch users can install it from the AUR instead: [`athroisma-git`](https://aur.archlinux.org/packages/athroisma-git).

Otherwise, it's a small Rust binary, build it with Cargo and put the result on `PATH`:

```sh
git clone https://github.com/zesis-shell/athroisma
cd athroisma
cargo build --release
install -Dm755 target/release/athroisma ~/.local/bin/athroisma
```

Make sure `~/.local/bin` (or wherever you installed it) is on `PATH` for whatever launches zesis.

### 3D globe (Congeries)

The Home panel's 3D geodesic rod globe, needs [Congeries](https://github.com/zesis-shell/congeries), a native QtQuick3D plugin from a sibling repo, it's entirely optional. If it's missing that panel just shows a "3D globe unavailable" message instead of failing.

With Nix, `flake.nix` already declares `congeries` as a flake input and wires it into the devshell's `QML_IMPORT_PATH`/`QT_PLUGIN_PATH`, but that only covers `nix develop`, not however you actually run zesis day to day. Make Congeries available at the same scope zesis itself runs at, the same way you already do for Quickshell: system-wide via a NixOS module, per-user via hjem/home-manager, or wired into whatever systemd service launches zesis.

Without Nix, build it manually with CMake and add the result to `QML_IMPORT_PATH`:

```sh
git clone https://github.com/zesis-shell/congeries
cd congeries
cmake -B build -G Ninja
cmake --build build
cmake --install build --prefix ~/.local

export QML_IMPORT_PATH="$HOME/.local/lib/qt-6/qml:$QML_IMPORT_PATH"
```

Dependencies: Qt 6.6+ (`Core`, `Qml`, `Quick3D`) and `libpipewire-0.3`, see Congeries' own README for details.

---

## Architecture

### Theming
Colors live in `colors.json` and are exposed via the `Colors` singleton (`Colors.qml`). Editing `colors.json` hot-reloads the theme at runtime without restarting Quickshell. See the token list in `Colors.qml` for available palette properties.

### Compositor backend
All Hyprland-specific calls (workspace/window data, dispatch commands, monitor queries) are isolated behind a two-layer abstraction in `Widgets/Wm/`:

- **`HyprlandWmBackend`** - the only file that imports `Quickshell.Hyprland`. Exposes reactive `workspaces`, `toplevels`, and `focusedMonitor` properties, plus named action functions (`focusWorkspace`, `moveWindow`, `preselect`, etc.).
- **`WmService`** - compositor-agnostic singleton. Widgets bind to `WmService.*`. Swapping compositors means writing a new backend and changing one line: `property QtObject _backend: SwayWmBackend {}`.

The Display widget follows the same pattern with `DisplayHyprlandBackend`, and the Keybinds widget has its own `HyprlandBackend` for reading binds.

## Development

A Nix flake is included with a devshell that provides Quickshell with the correct `QML_IMPORT_PATH`:

```sh
nix develop
```

An `.envrc` is included for [direnv](https://direnv.net/) users - `direnv allow` will drop you into the devshell automatically on `cd`.

This makes `qmlls` and `clangd` aware of Quickshell's QML modules for IDE completions and type checking.

### Editor setup

Create an empty `.qmlls.ini` file next to `shell.qml`. Quickshell populates it with a managed `qmlls` configuration on first run.

```sh
touch .qmlls.ini
```

`.qmlls.ini` is gitignored - its content is machine-specific.

#### VSCode / VSCodium

Enable `qt-qml.qmlls.useQmlImportPathEnvVar` in your workspace settings so `qmlls` picks up `QML_IMPORT_PATH` from the devshell. `.vscode/` is gitignored; manage your own local workspace settings.

## Contributing

PRs and issues are welcome - especially for portability improvements.

## License

Zesis is licensed under the [GNU General Public License v3.0](LICENSE) or later.
