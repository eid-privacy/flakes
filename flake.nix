{
  description = "A flake for all e-id things";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      packages = {
        # Default packages (latest stable)
        default = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.13"; };
        noir = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.13"; };
        barretenberg = pkgs.callPackage ./barretenberg.nix { version = "1.2.1"; };

        # Version-specific packages organized by tool
        noir-versions = {
          v1_0_0-beta_13 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.13"; };
          v1_0_0-beta_15 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.15"; };
        };

        barretenberg-versions = {
          v1_2_1 = pkgs.callPackage ./barretenberg.nix { version = "1.2.1"; };
          v2_1_2 = pkgs.callPackage ./barretenberg.nix { version = "2.1.2"; };
        };
      };
    });
}
