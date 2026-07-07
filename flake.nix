{
  description = "A flake for all e-id things";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      lib = pkgs.lib;

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
          v1_0_0-beta_19 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.19"; };
          v1_0_0-beta_20 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.20"; };
          v1_0_0-beta_21 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.21"; };
          v1_0_0-beta_22 = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.22"; };
        };

        nargo-t256-versions = {
          "commit_0c11d1" = pkgs.callPackage ./nargo-t256.nix {
            rev = "0c11d1b6d8cef3eeab8a276066d1ae8e4139fed6";
            srcHash = "sha256-9KchEimHhDeL16zNmakwmUGNKfcw4MdrStyXKuau1Zs=";
            cargoHash = "sha256-LNfYXtjkitpD/S2BqH4qKzwGjWyUJRzyRzTydKCy+38=";
          };
          "t256-v0_1" = pkgs.callPackage ./nargo-t256.nix {
            rev = "t256-v0.1";
            srcHash = "sha256-54L9F98ZjefI6DD2HkeP/ebsGEGISMs5WLNlI33y5/8=";
            cargoHash = "sha256-LNfYXtjkitpD/S2BqH4qKzwGjWyUJRzyRzTydKCy+38=";
          };
          "t256-v0_2" = pkgs.callPackage ./nargo-t256.nix {
            rev = "t256-v0.2";
            srcHash = "sha256-0BomTd5b9PF0QijXD3kKDrMUaj54PCdRJPSR1Z/2rck=";
            cargoHash = "sha256-6O1ILolDDJ+YfclFXm71a6tw38PKWJ/supw26H/sA90=";
          };
          "t256-v0_22" = pkgs.callPackage ./nargo-t256.nix {
            rev = "t256-v0.22";
            srcHash = "sha256-ybarJDT69udlAfJqJ3u12gwGC5Ieh48f8+8X68WvNls=";
            cargoHash = "sha256-sSOT2+pIJCT+0RiP7dGW4fd0HVaPR3foR5WEq0uWooE=";
          };
          "t256-v0_22-1" = pkgs.callPackage ./nargo-t256.nix {
            rev = "t256-v0.22-1";
            srcHash = "sha256-kduSlSyWiVseGIndthhMoJuHb35O84ot29i6ezcGwFQ=";
            cargoHash = "sha256-sSOT2+pIJCT+0RiP7dGW4fd0HVaPR3foR5WEq0uWooE=";
          };
        };

        barretenberg-versions = {
          v0_87_0 = pkgs.callPackage ./barretenberg.nix { version = "0.87.0"; };
          v1_2_1  = pkgs.callPackage ./barretenberg.nix { version = "1.2.1"; };
          # v2_1_2 and v2_1_8 are stable aztec-packages releases not pinned by any Noir beta
          v2_1_2  = pkgs.callPackage ./barretenberg.nix { version = "2.1.2"; };
          v2_1_8  = pkgs.callPackage ./barretenberg.nix { version = "2.1.8"; };
          beta_8  = pkgs.callPackage ./barretenberg.nix { version = "0.87.0"; };
          beta_13 = pkgs.callPackage ./barretenberg.nix { version = "1.2.1"; };
          beta_14 = pkgs.callPackage ./barretenberg.nix { version = "3.0.0-nightly.20251030-2"; };
          beta_15 = pkgs.callPackage ./barretenberg.nix { version = "3.0.0-nightly.20251104"; };
          beta_16 = pkgs.callPackage ./barretenberg.nix { version = "3.0.0-nightly.20251104"; };
          beta_17 = pkgs.callPackage ./barretenberg.nix { version = "3.0.0-nightly.20251104"; };
          beta_18 = pkgs.callPackage ./barretenberg.nix { version = "3.0.0-nightly.20260102"; };
          beta_19 = pkgs.callPackage ./barretenberg.nix { version = "4.0.0-nightly.20260120"; };
          beta_20 = pkgs.callPackage ./barretenberg.nix { version = "5.0.0-nightly.20260324"; };
          beta_21 = pkgs.callPackage ./barretenberg.nix { version = "5.0.0-nightly.20260324"; };
          beta_22 = pkgs.callPackage ./barretenberg.nix { version = "5.0.0-nightly.20260522"; githubRepo = "barretenberg"; };
        };
      };
    in {
      packages = {
        # Default packages (latest stable)
        default = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.13"; };
        noir = pkgs.callPackage ./noir.nix { version = "1.0.0-beta.13"; };
        barretenberg = pkgs.callPackage ./barretenberg.nix { version = "1.2.1"; };

        # Nargo built from source (eid-privacy/noir fork, t256 branch)
        nargo-t256 = pkgs.callPackage ./nargo-t256.nix {
          rev = "t256-v0.2";
          srcHash = "sha256-0BomTd5b9PF0QijXD3kKDrMUaj54PCdRJPSR1Z/2rck=";
          cargoHash = "sha256-6O1ILolDDJ+YfclFXm71a6tw38PKWJ/supw26H/sA90=";
        };
      };

      # Use legacyPackages for nested attribute sets
      legacyPackages = versionedPackages;
    });
}
