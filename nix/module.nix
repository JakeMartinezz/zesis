{
  self,
  athroisma,
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
        The zesis QML source to deploy
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

    python = lib.mkOption {
      type = lib.types.package;
      default = pkgs.python3.withPackages (ps: with ps; [icalendar recurring-ical-events]);
      description = ''
        The python3 build to put on the service's PATH.
        Calendar (icalendar/recurring-ical-events) and AirPods battery need python3.
      '';
    };

    aircon.envFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/etc/secrets/zesis-aircon.env";
      description = ''
        Env file with CL_USER=/CL_PASS= for the aircon widget, used when the keyring
        has no credentials (default: ~/.config/zesis/aircon.env). Give it as a string,
        never a Nix path, and keep it outside your flake: anything a flake can see is
        copied into the world-readable /nix/store. It must be owned by the user running
        zesis with mode 600, or the widget refuses it.
      '';
    };

    tapo.envFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "/etc/secrets/zesis-tapo.env";
      description = ''
        Env file for the Tapo light widget (default: ~/.config/zesis/tapo.env):
        TAPO_USER=/TAPO_PASS= (your TP-Link account, used when the keyring has no
        "tapo" entry) and TAPO_HOSTS= (the bulb's LAN address). Same rules as
        aircon.envFile: a string outside your flake, owned by you, mode 600.
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
          inherits your normal desktop PATH (/run/current-system/sw/bin, your
          home-manager per-user profile, and ~/.nix-profile/bin), so this only
          matters if you want the complete zesis experience without having
          installed these yourself.
        '';
      };
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = with pkgs; [
          matugen
          imagemagick
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
          libsecret
          openssl
          curl
        ];
        description = "Packages put on the service's PATH when batteriesIncluded.enable is true.";
      };
    };

    inheritPath = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Append the user's normal desktop PATH (/run/current-system/sw/bin,
        their home-manager per-user profile, and ~/.nix-profile/bin) to the
        service's PATH. Disable for a fully
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

    # Must match PamContext's `config: "quickshell"` in
    # widgets/lockscreen/LockSurface.qml - that's the PAM service name it
    # authenticates against, and the lock screen has no way to unlock
    # without it.
    security.pam.services.quickshell = {};

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
            ++ lib.optionals cfg.inheritPath ["/run/current-system/sw/bin" "/etc/profiles/per-user/%u/bin" "%h/.nix-profile/bin"]
          );
        }
        // lib.optionalAttrs (cfg.aircon.envFile != null) {
          ZESIS_AIRCON_ENV = cfg.aircon.envFile;
        }
        // lib.optionalAttrs (cfg.tapo.envFile != null) {
          ZESIS_TAPO_ENV = cfg.tapo.envFile;
        };
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/quickshell -c zesis";
        Restart = "on-failure";
        RestartSec = 5;
        # Default KillMode (control-group) sends the stop signal to every
        # process in the service's cgroup, including apps the launcher
        # spawned - so restarting/reloading zesis killed whatever you'd
        # opened through it. "process" limits the signal to the tracked
        # main PID (quickshell itself), leaving launched apps running.
        KillMode = "process";
      };
    };
  };
}
