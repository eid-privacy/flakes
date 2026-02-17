{
  description = "A flake for all e-id things";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};

      # Define version-specific packages
      versionedPackages = {
        noir-versions = {
          v1_0_0-beta_8 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.8"; };
          v1_0_0-beta_13 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.13"; };
          v1_0_0-beta_14 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.14"; };
          v1_0_0-beta_15 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.15"; };
          v1_0_0-beta_16 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.16"; };
          v1_0_0-beta_17 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.17"; };
          v1_0_0-beta_18 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.18"; };
        };

        barretenberg-versions = {
          v1_2_1 = pkgs.callPackage ./barretenberg.nix { version = "1.2.1"; };
          v2_1_2 = pkgs.callPackage ./barretenberg.nix { version = "2.1.2"; };
          v2_1_8 = pkgs.callPackage ./barretenberg.nix { version = "2.1.8"; };
          beta_14 = pkgs.callPackage ./barretenberg.nix { version = "3.0.0-nightly.20251030-2"; };
          beta_15 = pkgs.callPackage ./barretenberg.nix { version = "3.0.0-nightly.20251104"; };
          beta_16 = pkgs.callPackage ./barretenberg.nix { version = "3.0.0-nightly.20251105"; };
          beta_17 = pkgs.callPackage ./barretenberg.nix { version = "3.0.0-nightly.20251104"; };
	  beta_18 = pkgs.callPackage ./barretenberg.nix { version = "3.0.0-nightly.20260102"; };
          beta_00 = pkgs.callPackage ./barretenberg.nix { version = "3.0.0-nightly.20260102"; };
        };
      };
    in {
      packages = {
        # Default packages (latest stable)
        default = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.13"; };
        noir = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.13"; };
        barretenberg = pkgs.callPackage ./barretenberg.nix { version = "1.2.1"; };
      };

      # Use legacyPackages for nested attribute sets
      legacyPackages = versionedPackages;
    });
}
