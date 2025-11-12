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
...
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
...
```

Or via command line:

```bash
devbox add github:eid-privacy/flakes#noir-versions.v1_0_0-beta_15
devbox add github:eid-privacy/flakes#barretenberg-versions.v2_1_2
```

# Versions available

Currently the following versions are available:

## Noir
- `noir` (default) - 1.0.0-beta.13
- `noir-versions.v1_0_0-beta_13` - 1.0.0-beta.13
- `noir-versions.v1_0_0-beta_15` - 1.0.0-beta.15

## Barretenberg
- `barretenberg` (default) - 1.2.1 (compatible with noir beta.13)
- `barretenberg-versions.v1_2_1` - 1.2.1
- `barretenberg-versions.v2_1_2` - 2.1.2
