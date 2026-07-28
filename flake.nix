{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    athroisma = {
      url = "github:zesis-shell/athroisma";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    congeries = {
      url = "github:zesis-shell/congeries";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    nixpkgs,
    athroisma,
    congeries,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forEachSystem = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: import nixpkgs {inherit system;};

    shaderNames = ["globe" "gear"];
  in {
    packages = forEachSystem (system: {
      athroisma = athroisma.packages.${system}.default;
      congeries = congeries.packages.${system}.default;
    });

    apps = forEachSystem (system: let
      pkgs = pkgsFor system;
    in {
      compile-shaders = {
        type = "app";
        program = toString (pkgs.writeShellScript "compile-shaders" ''
          set -euo pipefail
          for f in $(find . -name '_*' -prune -o -name '*.frag' -not -path '*/_*' -print | grep -E '/(${pkgs.lib.concatStringsSep "|" shaderNames})\.frag$'); do
            echo "compiling $f"
            ${pkgs.qt6.qtshadertools}/bin/qsb --qt6 -o "''${f%.frag}.qsb" "$f"
          done
        '');
      };
    });

    devShells = forEachSystem (system: let
      pkgs = pkgsFor system;
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          quickshell
          clang-tools
          imagemagick
          glsl_analyzer
          qt6.qtshadertools
          athroisma.packages.${system}.default
          congeries.packages.${system}.default
          (python3.withPackages (ps:
            with ps; [
              icalendar
              recurring-ical-events
            ]))
        ];

        QML_IMPORT_PATH = pkgs.lib.concatStringsSep ":" [
          "${pkgs.qt6.qtdeclarative}/lib/qt-6/qml"
          "${pkgs.qt6.qtquick3d}/lib/qt-6/qml"
          "${pkgs.quickshell}/lib/qt-6/qml"
          "${congeries.packages.${system}.default}/lib/qt-6/qml"
        ];

        QT_PLUGIN_PATH = pkgs.lib.concatStringsSep ":" [
          "${pkgs.qt6.qtquick3d}/lib/qt-6/plugins"
          "${pkgs.qt6.qtdeclarative}/lib/qt-6/plugins"
          "${pkgs.qt6.qtbase}/lib/qt-6/plugins"
        ];

        ZESIS_DEV = "1";
      };
    });
  };
}
