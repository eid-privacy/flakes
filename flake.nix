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
        barretenberg = pkgs.callPackage ./barretenberg.nix {};
        default = pkgs.callPackage ./noir.nix {};
      };
    });
}
