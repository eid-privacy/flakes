{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
, rev ? "t256-v0.2"
, srcHash ? "sha256-0BomTd5b9PF0QijXD3kKDrMUaj54PCdRJPSR1Z/2rck="
, cargoHash ? "sha256-6O1ILolDDJ+YfclFXm71a6tw38PKWJ/supw26H/sA90="
}:

let
  src = pkgs.fetchFromGitHub {
    owner = "eid-privacy";
    repo = "noir";
    inherit rev;
    hash = srcHash;
  };

in
pkgs.rustPlatform.buildRustPackage {
  pname = "nargo-t256";
  version = "0-unstable-${builtins.substring 0 8 rev}";

  inherit src;

  # Build only the nargo_cli workspace member
  buildAndTestSubdir = "tooling/nargo_cli";

  cargoHash = cargoHash;

  nativeBuildInputs = with pkgs; [
    pkg-config
    git
  ];

  # noirc_driver's build script calls `git rev-parse HEAD` to embed version info.
  # Since fetchFromGitHub strips .git, we create a minimal git repo so the build succeeds.
  preBuild = ''
    export HOME=$(mktemp -d)
    git init
    git config user.email "nix@nixos.org"
    git config user.name "Nix"
    git add .
    git -c commit.gpgsign=false commit -m "nix build" --allow-empty
  '';

  buildInputs = with pkgs; lib.optionals stdenv.isDarwin [
    libiconv
  ];

  # nargo_cli tests require a running environment; skip them
  doCheck = false;

  postInstall = ''
    mv $out/bin/nargo $out/bin/nargo-t256
  '';

  meta = with lib; {
    description = "Nargo (nargo_cli) built from eid-privacy/noir commit ${rev}";
    homepage = "https://github.com/eid-privacy/noir";
    license = licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "nargo-t256";
  };
}
