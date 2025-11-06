# Flakes for e-ID

To have some kind of reproducibility, we started adding flakes to be able to
run things on different systems.
We mainly use devbox, so these flakes can be added like this:

```json
{
  "packages": [
    "github:eid-privacy/flakes#noir",
    "github:eid-privacy/flakes#barretenberg"
  ],
...
```

Or, of course:

```bash
devbox add github:eid-privacy/flakes#noir
devbox add github:eid-privacy/flakes#barretenberg
```

# Versions available

Currently the following flakes are available:

- noir@1.0.0-beta.13
- barretenberg@1.2.1 - which is the latest version which works with noir
