{
  description = "Busybox in Zig";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    systems.url = "github:nix-systems/default";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      systems,
      zig-overlay,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
    in
    flake-parts.lib.mkFlake { inherit inputs; } (
      { inputs, ... }:
      {
        systems = import inputs.systems;

        perSystem =
          {
            self',
            inputs',
            system,
            pkgs,
            ...
          }:
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = [
                zig-overlay.overlays.default
              ];
            };

            legacyPackages = pkgs;

            packages =
              let
                variants = {
                  default = pkgs.zig;
                  default-zig_0_15 = pkgs.zigpkgs.master.overrideAttrs (
                    final: prev: {
                      passthru.hook = pkgs.callPackage "${inputs.nixpkgs}/pkgs/development/compilers/zig/hook.nix" {
                        zig = final.finalPackage;
                      };

                      inherit (pkgs.zig) meta;
                    }
                  );
                };

                normal = lib.mapAttrs (
                  _: zig:
                  pkgs.callPackage ./nix/package.nix {
                    inherit zig;
                    src = inputs.self;
                  }
                ) variants;

                bootstraps = lib.listToAttrs (
                  lib.attrValues (
                    lib.mapAttrs (
                      name: pkg: lib.nameValuePair "bootstrap${lib.removePrefix "default" name}" pkg.passthru.bootstrap
                    ) normal
                  )
                );
              in
              normal // bootstraps;

            checks = lib.foldAttrs (item: acc: item // acc) { } (
              lib.attrValues (
                lib.mapAttrs (
                  topName: topPkg:
                  lib.listToAttrs (
                    lib.attrValues (
                      lib.mapAttrs (name: lib.nameValuePair "${topName}-${name}") (
                        builtins.removeAttrs topPkg.passthru.tests [ "override" "overrideDerivation" "extend" "__unfix__" ]
                      )
                    )
                  )
                ) self'.packages
              )
            );
          };
      }
    );
}
