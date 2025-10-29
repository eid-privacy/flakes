{
  description = "E-ID Privacy Flakes - Custom Nix packages for development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          noir = pkgs.stdenv.mkDerivation {
            pname = "noir-devbox";
            version = "1.0.0-beta.13";

            src = pkgs.emptyDirectory;

            nativeBuildInputs = [ pkgs.makeWrapper ];

            buildInputs = [ pkgs.bash pkgs.curl ];

            dontUnpack = true;
            dontBuild = true;

            installPhase = ''
              mkdir -p $out/bin
              mkdir -p $out/lib

              # Create a wrapper script that sets up noir
              cat > $out/bin/noir-setup <<'EOF'
              #!/usr/bin/env bash
              set -e

              # Set NARGO_HOME to .devbox/nargo
              export NARGO_HOME=$PWD/.devbox/nargo
              mkdir -p "$NARGO_HOME"

              # Install noirup if not already installed
              if [ ! -f "$NARGO_HOME/bin/noirup" ]; then
                echo "Installing noirup to $NARGO_HOME..."
                export PATH="$NARGO_HOME/bin:$PATH"
                curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
              fi

              # Install specific version of noir
              if [ ! -f "$NARGO_HOME/bin/nargo" ]; then
                echo "Installing noir version 1.0.0-beta.13..."
                export PATH="$NARGO_HOME/bin:$PATH"
                "$NARGO_HOME/bin/noirup" -v 1.0.0-beta.13
              fi

              echo "Noir setup complete. NARGO_HOME=$NARGO_HOME"
              EOF

              chmod +x $out/bin/noir-setup

              # Create wrapper scripts for noir tools that ensure setup
              for tool in nargo noirup; do
                cat > $out/bin/$tool <<EOF
              #!/usr/bin/env bash
              export NARGO_HOME=\''${NARGO_HOME:-\$PWD/.devbox/nargo}
              export PATH="\$NARGO_HOME/bin:\$PATH"

              # Run setup if nargo is not found
              if [ ! -f "\$NARGO_HOME/bin/$tool" ]; then
                $out/bin/noir-setup
              fi

              exec "\$NARGO_HOME/bin/$tool" "\$@"
              EOF
                chmod +x $out/bin/$tool
              done

              # Create init hook script that devbox can call
              cat > $out/lib/init-hook.sh <<'EOF'
              # Initialize noir for devbox
              export NARGO_HOME=''${NARGO_HOME:-$PWD/.devbox/nargo}
              export PATH="$NARGO_HOME/bin:$PATH"

              # Run setup on first use
              if [ ! -f "$NARGO_HOME/bin/nargo" ]; then
                echo "Setting up noir for the first time..."
                ${"\${DEVBOX_PACKAGES_DIR}"}/noir-devbox/bin/noir-setup
              fi
              EOF
            '';

            meta = with pkgs.lib; {
              description = "Noir language tools (nargo) installed via noirup";
              homepage = "https://noir-lang.org";
              license = licenses.mit;
              platforms = platforms.unix;
            };
          };
        };

        # Set default package
        packages.default = self.packages.${system}.noir;
      }
    );
}
