# Flakes for e-ID

To have some kind of reproducibility, we started adding flakes to be able to
run things on different systems.
We mainly use devbox, so these flakes can be added like this:

## Using default (latest stable) versions

```json
{
  "packages": [
    "github:eid-privacy/flakes#noir",
    "github:eid-privacy/flakes#barretenberg"
  ],
```

Or via command line:

```bash
devbox add github:eid-privacy/flakes#noir
devbox add github:eid-privacy/flakes#barretenberg
```

## Using specific versions

```json
{
  "packages": [
    "github:eid-privacy/flakes#noir-versions.v1_0_0-beta_15",
    "github:eid-privacy/flakes#barretenberg-versions.v2_1_2"
  ],
```

Or via command line:

```bash
devbox add github:eid-privacy/flakes#noir-versions.v1_0_0-beta_15
devbox add github:eid-privacy/flakes#barretenberg-versions.v2_1_2
```

# Binary Cache

Precompiled binaries are available via [Cachix](https://cachix.org), so you
don't have to build packages from source.

## Configuring devbox

Add `nixConfig` to your project's `devbox.json`:

```json
{
  "packages": [
    "github:eid-privacy/flakes#noir"
  ],
  "nixConfig": {
    "extra-substituters": "https://eid-privacy.cachix.org",
    "extra-trusted-public-keys": "eid-privacy.cachix.org-1:lxRzvjcWd/A6Wew1tq0IK6OIMVWNJKUTy4s7EKb6C2A="
  }
}
```

The public key is `eid-privacy.cachix.org-1:lxRzvjcWd/A6Wew1tq0IK6OIMVWNJKUTy4s7EKb6C2A=`.

## Configuring Nix directly

Add to `~/.config/nix/nix.conf` (or `/etc/nix/nix.conf` for system-wide):

```
substituters = https://cache.nixos.org https://eid-privacy.cachix.org
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= eid-privacy.cachix.org-1:lxRzvjcWd/A6Wew1tq0IK6OIMVWNJKUTy4s7EKb6C2A=
```

Or use `cachix use` which configures this automatically:

```bash
nix profile install nixpkgs#cachix
cachix use eid-privacy
```

# Sandboxes on Linux

On Linux only, nix uses sandboxing to build flakes, which disallows
network access.
While this is great for reproducibility, it makes the current
installers fail.
To allow creating the flakes in a Linux nix, you need to create
the following configuration:

```bash
mkdir -p ~/.config/nix
cat - <<EOF >> ~/.config/nix/nix.conf
experimental-features = nix-command flakes
sandbox = relaxed
EOF
```

# Testing

If you're adding new versions, and want to make sure that the flake
builds:

```bash
nix build .#noir-versions.v1_0_0-beta_15
```

## Updating

Once a new version is published on github, I have to run the following
command to update the local versions of the flake:

```bash
nix flake update --flake github:eid-privacy/flakes
```

Probably 

```bash
nix flake update
```

and then pushing the flake.lock file to the repo should also work.

# Versions available

Currently the following versions are available:

## Noir
- `noir` (default) - 1.0.0-beta.13
- `noir-versions.v1_0_0-beta_8`  - 1.0.0-beta.8
- `noir-versions.v1_0_0-beta_13` - 1.0.0-beta.13
- `noir-versions.v1_0_0-beta_14` - 1.0.0-beta.14
- `noir-versions.v1_0_0-beta_15` - 1.0.0-beta.15
- `noir-versions.v1_0_0-beta_16` - 1.0.0-beta.16
- `noir-versions.v1_0_0-beta_17` - 1.0.0-beta.17
- `noir-versions.v1_0_0-beta_18` - 1.0.0-beta.18
- `noir-versions.v1_0_0-beta_19` - 1.0.0-beta.19
- `noir-versions.v1_0_0-beta_20` - 1.0.0-beta.20
- `noir-versions.v1_0_0-beta_21` - 1.0.0-beta.21
- `noir-versions.v1_0_0-beta_22` - 1.0.0-beta.22

The canonical source for Noir↔Barretenberg version pairings is the
`scripts/install_bb.sh` file in the noir-lang/noir repo at each release tag:

https://github.com/noir-lang/noir/blob/<tag>/scripts/install_bb.sh

Example: https://github.com/noir-lang/noir/blob/v1.0.0-beta.18/scripts/install_bb.sh

## Nargo-t256 (eid-privacy/noir fork)

- `nargo-t256` (default) - commit b7f153bc
- `nargo-t256-versions.0c11d1`    - commit 0c11d1b6
- `nargo-t256-versions.v_2026_06_17` - commit e9a577066f

## Barretenberg

- `barretenberg` (default) - 1.2.1 (compatible with noir beta.13)
- `barretenberg-versions.v0_87_0` / `beta_8`  - 0.87.0 (noir beta.8)
- `barretenberg-versions.v1_2_1`  / `beta_13` - 1.2.1  (noir beta.13)
- `barretenberg-versions.v2_1_2`  - 2.1.2 (standalone aztec-packages stable, no Noir beta pairing)
- `barretenberg-versions.v2_1_8`  - 2.1.8 (standalone aztec-packages stable, no Noir beta pairing)
- `barretenberg-versions.beta_14` - 3.0.0-nightly.20251030-2
- `barretenberg-versions.beta_15` - 3.0.0-nightly.20251104
- `barretenberg-versions.beta_16` - 3.0.0-nightly.20251105
- `barretenberg-versions.beta_17` - 3.0.0-nightly.20251104
- `barretenberg-versions.beta_18` - 3.0.0-nightly.20260102
- `barretenberg-versions.beta_19` - 4.0.0-nightly.20260120
- `barretenberg-versions.beta_20` - 5.0.0-nightly.20260324
- `barretenberg-versions.beta_21` - 5.0.0-nightly.20260324 (same BB as beta.20)
- `barretenberg-versions.beta_22` - 5.0.0-nightly.20260522
