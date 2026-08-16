{
  self,
  athroisma,
  congeries,
}: {
  config,
  lib,
  pkgs,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;
  cfg = config.services.zesis;
in {
  options.services.zesis = {
    enable = lib.mkEnableOption ''
      The zesis quickshell shell, deployed system-wide as a named
      Quickshell config. Any manual `quickshell`/`qs` invocation. IPC calls
      in your compositor keybinds, debugging, etc.  must pass `-c zesis`
      (or `QS_CONFIG_NAME=zesis`) or it won't find this instance
    '';

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.quickshell;
      description = "The quickshell package to run zesis with.";
    };

    configPackage = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${system}.config;
      description = ''
        The zesis QML source (merged with its compiled shaders) to deploy
        as the `zesis` named Quickshell config.
      '';
    };

    athroisma = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Put athroisma on the service's PATH, for the System Monitor widget.";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = athroisma.packages.${system}.default;
        description = "The athroisma package to use.";
      };
    };

    congeries = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Put congeries on QML_IMPORT_PATH, for the 3D globe widget.";
      };
      package = lib.mkOption {
        type = lib.types.package;
        default = congeries.packages.${system}.default;
        description = "The congeries package to use.";
      };
    };

    python = lib.mkOption {
      type = lib.types.package;
      default = pkgs.python3.withPackages (ps: with ps; [icalendar recurring-ical-events]);
      description = ''
        The python3 build to put on the service's PATH.
        Calendar (icalendar/recurring-ical-events), AirPods battery and the
        3D globe's starfield generation script all need python3.
      '';
    };

    batteriesIncluded = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Put the full set of optional runtime tools zesis's widgets can
          shell out to on the service's PATH outright, regardless of whether
          your system already has them. Off by default. The service already
          inherits your normal desktop PATH (/run/current-system/sw/bin plus
          your per-user profile), so this only matters if you want the complete
          zesis experience without having installed these yourself.
        '';
      };
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          matugen
          awww
          bluez
          avahi
          hostname
          libnotify
          procps
          xdg-utils
          gawk
          brightnessctl
          slurp
        ];
        description = "Packages put on the service's PATH when batteriesIncluded.enable is true.";
      };
    };

    inheritPath = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Append the user's normal desktop PATH (/run/current-system/sw/bin
        plus their per-user profile) to the service's PATH. Disable for a fully
        self-contained, explicit PATH instead of inheriting whatever
        happens to be installed. You'll likely also want
        `batteriesIncluded.enable = true;` in that case, to still cover the
        ordinary tools zesis's widgets need.
      '';
    };

    systemdService = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Launch zesis via a `systemd --user` service wanted by
          `graphical-session.target`. Disable this if you'd rather start it
          yourself, e.g. with `exec-once = quickshell -c zesis` in your
          compositor config. The `zesis` config is still deployed to
          `/etc/xdg/quickshell/zesis` either way.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."xdg/quickshell/zesis".source = cfg.configPackage;

    # The 3D globe's starfield data (see scripts/ensure_starfield.sh) is
    # identical for every user, so it's cached once here.
    # `configPackage` pre-declares widgets/globe3d/RealStarField.js
    # as a symlink into this directory.
    systemd.tmpfiles.rules = lib.mkIf cfg.congeries.enable [
      "d /var/cache/zesis/starfield 1777 root root -"
    ];

    systemd.user.services.zesis = lib.mkIf cfg.systemdService.enable {
      description = "Quickshell (zesis)";
      wantedBy = ["graphical-session.target"];
      after = ["graphical-session.target"];
      partOf = ["graphical-session.target"];

      enableDefaultPath = false;
      environment =
        {
          PATH = lib.concatStringsSep ":" (
            ["${cfg.python}/bin"]
            ++ lib.optional cfg.athroisma.enable "${cfg.athroisma.package}/bin"
            ++ lib.optionals cfg.batteriesIncluded.enable (map (p: "${p}/bin") cfg.batteriesIncluded.packages)
            ++ lib.optionals cfg.inheritPath ["/run/current-system/sw/bin" "/etc/profiles/per-user/%u/bin"]
          );
        }
        // lib.optionalAttrs cfg.congeries.enable {
          QML_IMPORT_PATH = lib.concatStringsSep ":" [
            "${pkgs.qt6.qtquick3d}/lib/qt-6/qml"
            "${cfg.congeries.package}/lib/qt-6/qml"
          ];
        };
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/quickshell -c zesis";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
