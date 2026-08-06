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
    self,
    nixpkgs,
    athroisma,
    congeries,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forEachSystem = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: import nixpkgs {inherit system;};
    shadersFor = system: (pkgsFor system).callPackage ./nix/shaders.nix {src = ./.;};
  in {
    packages = forEachSystem (system: let
      pkgs = pkgsFor system;
    in {
      athroisma = athroisma.packages.${system}.default;
      congeries = congeries.packages.${system}.default;

      shaders = (shadersFor system).package;

      # The full deployable config. Source tree + compiled shaders merged,
      # laid out for a Quickshell named config (qs -c zesis), i.e. this
      # is what belongs at <xdg config dir>/quickshell/zesis/.
      config =
        pkgs.runCommand "zesis-config" {
          nativeBuildInputs = [pkgs.lndir];
        } ''
          mkdir -p "$out"
          lndir -silent ${./.} "$out"
          lndir -silent ${self.packages.${system}.shaders} "$out"
        '';
    });

    apps = forEachSystem (system: {
      compile-shaders = {
        type = "app";
        program = toString (shadersFor system).compile;
      };
    });

    nixosModules.default = import ./nix/module.nix {inherit self athroisma congeries;};

    devShells = forEachSystem (system: let
      pkgs = pkgsFor system;
    in {
      default = pkgs.callPackage ./nix/shell.nix {
        athroisma = athroisma.packages.${system}.default;
        congeries = congeries.packages.${system}.default;
      };
    });
  };
}
