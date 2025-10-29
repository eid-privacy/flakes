{
  pkgs ? import <nixpkgs> { },
}:

pkgs.stdenv.mkDerivation {
  pname = "noir";
  version = "1.0.0-beta.13";

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
    mkdir -p $out/lib

    # Set SSL certificates for curl
    export SSL_CERT_FILE="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"

    # Initialize noir for devbox
    export NARGO_HOME="$out"

    echo "Installing noirup to $NARGO_HOME..."
    curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash

    # Install specific version of noir
    echo "Installing noir version 1.0.0-beta.13..."
    "$NARGO_HOME/bin/noirup" -v 1.0.0-beta.13
  '';

  meta = with pkgs.lib; {
    description = "Noir language tools (nargo) installed via noirup";
    homepage = "https://noir-lang.org";
    license = licenses.mit;
    platforms = platforms.unix;
  };

}
