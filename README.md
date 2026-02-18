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

# Versions available

Currently the following versions are available:

## Noir
- `noir` (default) - 1.0.0-beta.13
- `noir-versions.v1_0_0-beta_13` - 1.0.0-beta.13
- `noir-versions.v1_0_0-beta_14` - 1.0.0-beta.14
- `noir-versions.v1_0_0-beta_15` - 1.0.0-beta.15
- `noir-versions.v1_0_0-beta_16` - 1.0.0-beta.16
- `noir-versions.v1_0_0-beta_17` - 1.0.0-beta.17
- `noir-versions.v1_0_0-beta_18` - 1.0.0-beta.18


## Barretenberg

For the above beta versions of noir, it installs the corresponding version
of barretenberg, according to

https://github.com/AztecProtocol/aztec-packages/blob/next/barretenberg/bbup/bb-versions.json 

- `barretenberg` (default) - 1.2.1 (compatible with noir beta.13)
- `barretenberg-versions.v1_2_1` - 1.2.1
- `barretenberg-versions.v2_1_2` - 2.1.2
- `barretenberg-versions.v2_1_8` - 2.1.8
- `barretenberg-versions.beta13` - 1.2.0
- `barretenberg-versions.beta14` - 3.0.0-nightly.20251030-2
- `barretenberg-versions.beta15` - 3.0.0-nightly.20251104
- `barretenberg-versions.beta16` - 3.0.0-nightly.20251104
- `barretenberg-versions.beta17` - 3.0.0-nightly.20251104
- `barretenberg-versions.beta18` - 3.0.0-nightly.20260102
