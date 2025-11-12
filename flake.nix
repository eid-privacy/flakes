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
        noir = pkgs.callPackage ./noir.nix {};
        barretenberg_v2_1_2 = pkgs.callPackage ./barretenberg_v2.1.2.nix {};
        noir_v1_0_0_beta_15 = pkgs.callPackage ./noir_v1.0.0_beta.15.nix {};
        barretenberg = pkgs.callPackage ./barretenberg.nix {};
        default = pkgs.callPackage ./noir.nix {};
      };
    });
}
