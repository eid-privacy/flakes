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

> **Important — this only works if you are a *trusted* Nix user.** On a
> multi-user (daemon) Nix install, the daemon **ignores** substituters and
> public keys supplied by the client — whether they come from `devbox.json`
> `nixConfig`, a flake's own `nixConfig`, or `--extra-substituters` on the
> command line — unless your user is listed in `trusted-users`. When this
> happens Nix prints `ignoring untrusted substituter ...` and silently
> **builds from source instead**. In that case the `nixConfig` block above has
> no effect and you must use [Configuring Nix directly](#configuring-nix-directly)
> below (which needs root once) or be added to `trusted-users`. On a
> single-user Nix install there is no such restriction and `nixConfig` works as-is.

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

## Verifying the cache is actually used

If a package (notably `nargo-t256`, which is built from source) keeps
compiling instead of downloading, check whether your Nix is actually willing
to use the cache:

```bash
nix build --dry-run \
  --extra-substituters "https://eid-privacy.cachix.org" \
  --extra-trusted-public-keys "eid-privacy.cachix.org-1:lxRzvjcWd/A6Wew1tq0IK6OIMVWNJKUTy4s7EKb6C2A=" \
  github:eid-privacy/flakes#nargo-t256-versions.t256-v0_2
```

- **`... will be fetched`** with no warning → the cache works; `devbox.json`
  `nixConfig` is enough.
- **`warning: ignoring untrusted substituter ...`** → you are an untrusted
  user on a daemon install. The cache *contains* the binary, but Nix refuses
  to use it. Fix it via [Configuring Nix directly](#configuring-nix-directly)
  or by being added to `trusted-users` — see the note under
  [Configuring devbox](#configuring-devbox).

Note that `noir` and `barretenberg` download a prebuilt release binary via
`fetchurl` (a fixed-output derivation), so they are fetched directly from
GitHub and never depend on the substituter. Only `nargo-t256` is compiled
from source, which is why it is the one that benefits from — and depends on —
the cache.

## Inside containers (e.g. the devbox Docker image)

Two extra wrinkles appear in containers:

- `cachix use` may abort with `$USER must be set`. Export it first, e.g.
  `USER=root cachix use eid-privacy`, or run the binary by absolute path under
  `sudo`: `sudo env USER=root "$(command -v cachix)" use eid-privacy`.
- The container user (e.g. `devbox`) is usually **not** trusted, so the
  trusted-user rule above applies. The robust fix is to bake the cache into
  the image **at build time** (when you are root), not at runtime:

```dockerfile
USER root
RUN printf '%s\n' \
  'extra-substituters = https://eid-privacy.cachix.org' \
  'extra-trusted-public-keys = eid-privacy.cachix.org-1:lxRzvjcWd/A6Wew1tq0IK6OIMVWNJKUTy4s7EKb6C2A=' \
  >> /etc/nix/nix.conf
# (alternatively, grant trust instead: echo 'trusted-users = root devbox' >> /etc/nix/nix.conf)
USER devbox
```

## Using the cache in GitHub Actions (devbox-install-action)

When using [`jetify-com/devbox-install-action`](https://github.com/jetify-com/devbox-install-action),
the action installs Nix and Devbox for you. On GitHub-hosted runners the Nix
installer marks the runner user as trusted (`NIX_INSTALLER_TRUST_RUNNER_USER`),
so the `nixConfig` block already in your `devbox.json` is honored and the cache
is used automatically.

The catch: the action realises the packages itself. Its **last internal step**
runs `devbox run --config=. -- echo "Packages installed!"`, so `nargo-t256` is
built (or fetched) *during the action*. Any "trust the cache" step you add
**after** the action therefore runs too late — the binary is already in the
store and the substituter was never consulted on that first run.

So the substituter must be in place **before** the action runs. The action
provides exactly the hook for this: the `extra-nix-config` input is written to
`~/.config/nix/nix.conf` before its `devbox run` step (and the trusted runner
user means that per-user config is honored). Pass the cache there:

```yaml
name: build
on: [push, pull_request]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Devbox + Nix
        uses: jetify-com/devbox-install-action@v0.13.0
        with:
          project-path: .
          enable-cache: 'true'   # caches the Nix store between runs (separate from the binary cache)
          extra-nix-config: |
            extra-substituters = https://eid-privacy.cachix.org
            extra-trusted-public-keys = eid-privacy.cachix.org-1:lxRzvjcWd/A6Wew1tq0IK6OIMVWNJKUTy4s7EKb6C2A=

      - name: Build
        run: devbox run build
```

Notes:

- Use the action's `extra-nix-config` input — **not** a separate `run:` step
  after it. The action's own `devbox run` (its final internal step) is the first
  store realisation, so the substituter has to be configured by the time the
  action reaches that step. `extra-nix-config` is written before it; a later
  step is not.
- `enable-cache: 'true'` caches the Nix store via the GitHub Actions cache,
  which complements the Cachix binary cache — the former avoids re-downloading
  on subsequent runs, the latter avoids building on the first run.
- Pull-only access (downloading) needs **no** auth token. A `CACHIX_AUTH_TOKEN`
  is only required to *push* builds, which is what this repo's own
  `.github/workflows/cachix.yml` does.

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
filter-syscalls = false

# Add the following lines for cachix binaries
extra-substituters = https://eid-privacy.cachix.org
extra-trusted-public-keys = eid-privacy.cachix.org-1:lxRzvjcWd/A6Wew1tq0IK6OIMVWNJKUTy4s7EKb6C2A=
EOF
```

# Testing

If you're adding new versions, and want to make sure that the flake
builds:

```bash
nix build .#noir-versions.v1_0_0-beta_15
```

## Continuous integration (Cachix)

The `.github/workflows/cachix.yml` workflow builds every package and pushes the
results to the `eid-privacy` Cachix cache on every push to `main` (and on pull
requests, without pushing for forks without the secret).

The workflow **discovers versions automatically** from `flake.nix` — it does not
contain a hardcoded list. It enumerates the attributes with
`nix eval ... --apply builtins.attrNames`:

- every attribute under `packages.<system>` (the default packages), and
- every version inside each set under `legacyPackages.<system>`
  (`noir-versions`, `barretenberg-versions`, `nargo-t256-versions`, …).

So adding a new version (or a whole new version set) to `flake.nix` is enough —
the next CI run picks it up and caches it with no change to the workflow.

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
- `noir-versions.v1_0_0-beta_23` - 1.0.0-beta.23

The canonical source for Noir↔Barretenberg version pairings is the
`scripts/install_bb.sh` file in the noir-lang/noir repo at each release tag:

https://github.com/noir-lang/noir/blob/<tag>/scripts/install_bb.sh

Example: https://github.com/noir-lang/noir/blob/v1.0.0-beta.18/scripts/install_bb.sh

## Nargo-t256 (eid-privacy/noir fork)

- `nargo-t256` (default) - tag t256-v0.2
- `nargo-t256-versions.0c11d1`    - commit 0c11d1b6
- `nargo-t256-versions.t256-v0_1` - tag t256-v0.1 (commit e9a577066f)
- `nargo-t256-versions.t256-v0_2` - tag t256-v0.2
- `nargo-t256-versions.t256-v0_22` - tag t256-v0.22
- `nargo-t256-versions.t256-v0_22-1` - tag t256-v0.22-1
- `nargo-t256-versions.t256-v0_23` - tag t256-v0.23 (noir beta.23)

## Barretenberg

- `barretenberg` (default) - 1.2.1 (compatible with noir beta.13)
- `barretenberg-versions.v0_87_0` / `beta_8`  - 0.87.0 (noir beta.8)
- `barretenberg-versions.v1_2_1`  / `beta_13` - 1.2.1  (noir beta.13)
- `barretenberg-versions.v2_1_2`  - 2.1.2 (standalone aztec-packages stable, no Noir beta pairing)
- `barretenberg-versions.v2_1_8`  - 2.1.8 (standalone aztec-packages stable, no Noir beta pairing)
- `barretenberg-versions.beta_14` - 3.0.0-nightly.20251030-2
- `barretenberg-versions.beta_15` - 3.0.0-nightly.20251104
- `barretenberg-versions.beta_16` - 3.0.0-nightly.20251104 (20251105 release was deleted upstream)
- `barretenberg-versions.beta_17` - 3.0.0-nightly.20251104
- `barretenberg-versions.beta_18` - 3.0.0-nightly.20260102
- `barretenberg-versions.beta_19` - 4.0.0-nightly.20260120
- `barretenberg-versions.beta_20` - 5.0.0-nightly.20260324
- `barretenberg-versions.beta_21` - 5.0.0-nightly.20260324 (same BB as beta.20)
- `barretenberg-versions.beta_22` - 5.0.0-nightly.20260522
- `barretenberg-versions.beta_23` - 5.0.0-nightly.20260522 (same BB as beta.22)
