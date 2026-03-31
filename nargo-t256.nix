{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
}:

let
  commit = "b7f153bcda440ee4556629ffe41d728aba177939";

  src = pkgs.fetchFromGitHub {
    owner = "eid-privacy";
    repo = "noir";
    rev = commit;
    hash = "sha256-8fSOl1kVuRuwYClQMgcEB2S2nqE0rfETt/4FFJ7lZ68=";
  };

in
pkgs.rustPlatform.buildRustPackage {
  pname = "nargo-t256";
  version = "0-unstable-${builtins.substring 0 8 commit}";

  inherit src;

  # Build only the nargo_cli workspace member
  buildAndTestSubdir = "tooling/nargo_cli";

  cargoHash = "sha256-aWxNXDPC11dCJyzrFQdmYDUHkkngqpakhFrmUCQwPGE=";

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

  buildInputs = with pkgs; lib.optionals stdenv.isDarwin (with darwin.apple_sdk.frameworks; [
    Security
    SystemConfiguration
    CoreFoundation
  ]);

  # nargo_cli tests require a running environment; skip them
  doCheck = false;

  meta = with lib; {
    description = "Nargo (nargo_cli) built from eid-privacy/noir commit ${commit}";
    homepage = "https://github.com/eid-privacy/noir";
    license = licenses.mit;
    platforms = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    mainProgram = "nargo";
  };
}
