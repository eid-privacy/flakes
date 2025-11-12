{
  pkgs ? import <nixpkgs> { },
  version ? "1.2.1",
}:

pkgs.stdenv.mkDerivation {
  pname = "barretenberg";
  inherit version;

  dontUnpack = true;

  src = pkgs.emptyDirectory;

  nativeBuildInputs = [
    pkgs.makeWrapper
    pkgs.bash
    pkgs.curl
    pkgs.cacert
    pkgs.git
  ];

  buildInputs = [ ];

  installPhase = ''
    mkdir -p $out/bin

    # Set SSL certificates for curl
    export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

    # Installation directory
    export BB_PATH="$out/bin"
    BBUP="$BB_PATH/bbup"
    curl -L https://raw.githubusercontent.com/AztecProtocol/aztec-packages/master/barretenberg/bbup/bbup -o "$BBUP"
    chmod a+x "$BBUP"
    "$BBUP" --version ${version}
    echo Files are: $( ls -R $out )
  '';

  meta = with pkgs.lib; {
    description = "Barretenberg ZKP part for noir";
    homepage = "https://noir-lang.org";
    license = licenses.mit;
    platforms = platforms.unix;
  };
}
