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

    systemd.user.services.zesis = lib.mkIf cfg.systemdService.enable {
      description = "Quickshell (zesis)";
      wantedBy = ["graphical-session.target"];
      after = ["graphical-session.target"];
      partOf = ["graphical-session.target"];
      path = lib.optional cfg.athroisma.enable cfg.athroisma.package;
      environment = lib.mkIf cfg.congeries.enable {
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
