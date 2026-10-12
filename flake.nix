{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable";
    athroisma = {
      url = "github:zesis-shell/athroisma";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    athroisma,
    ...
  }: let
    systems = ["x86_64-linux" "aarch64-linux"];
    forEachSystem = nixpkgs.lib.genAttrs systems;
    pkgsFor = system: import nixpkgs {inherit system;};
  in {
    packages = forEachSystem (system: let
      pkgs = pkgsFor system;
    in {
      athroisma = athroisma.packages.${system}.default;

      # The full deployable config, laid out for a Quickshell named config
      # (qs -c zesis), i.e. this is what belongs at <xdg config dir>/quickshell/zesis/.
      config =
        pkgs.runCommand "zesis-config" {
          nativeBuildInputs = [pkgs.lndir];
        } ''
          mkdir -p "$out"
          lndir -silent ${./.} "$out"
        '';
    });

    nixosModules.default = import ./nix/module.nix {inherit self athroisma;};

    devShells = forEachSystem (system: let
      pkgs = pkgsFor system;
    in {
      default = pkgs.callPackage ./nix/shell.nix {
        athroisma = athroisma.packages.${system}.default;
      };
    });
  };
}
