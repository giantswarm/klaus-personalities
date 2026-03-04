# klaus-personalities

Klaus AI personality definitions -- OCI-packaged personality artifacts containing SOUL.md identity documents and plugin compositions.

## What is a Personality?

A **personality** defines *who* the AI is and *what plugins it uses*. Each personality is a directory containing:

- `personality.yaml` -- plugin references and optional toolchain image
- `SOUL.md` -- the identity document that shapes the AI's behavior, values, and communication style

Personalities are packaged as OCI artifacts and pushed to the registry by CI on every release tag. Release tags are created automatically when a PR is merged to `main`.

## Personalities

| Name | Description | Toolchain |
|------|-------------|-----------|
| `sre` | Giant Swarm SRE -- platform operations, incident response, infrastructure | `klaus-toolchains/go` |

## Registry Layout

Each personality is pushed as an OCI artifact to:

```
gsoci.azurecr.io/giantswarm/klaus-personalities/<name>:<tag>
```

Artifact packaging and media types are handled by `klausctl personality push`.

## Adding a New Personality

1. Create a new directory under `personalities/`:

```
personalities/my-personality/
  personality.yaml
  SOUL.md
```

2. Define the plugin list in `personality.yaml`:

```yaml
name: my-personality
description: Short description of this personality
author:
  name: Giant Swarm GmbH
repository: https://github.com/giantswarm/klaus-personalities
license: Apache-2.0
keywords:
  - giantswarm
toolchain:
  repository: gsoci.azurecr.io/giantswarm/klaus-toolchains/go
  tag: v0.1.2
plugins:
  - repository: gsoci.azurecr.io/giantswarm/klaus-plugins/gs-base
    tag: v0.1.0
  - repository: gsoci.azurecr.io/giantswarm/klaus-plugins/my-plugin
    tag: v1.0.0
```

3. Write the `SOUL.md` identity document. This defines the AI's identity, values, approach, and communication style. See existing personalities for examples.

4. Open a PR. CI will validate the structure. After merge to `main`, auto-release creates the next patch tag for each changed personality, which is then packaged and pushed to the registry.

## Using a Personality

With `klausctl`:

```yaml
# ~/.config/klausctl/config.yaml
personality: gsoci.azurecr.io/giantswarm/klaus-personalities/sre:v1.0.0
```

With the Klaus operator (`KlausInstance` CRD):

```yaml
spec:
  personality: gsoci.azurecr.io/giantswarm/klaus-personalities/sre:v1.0.0
```

## License

Apache 2.0 -- see [LICENSE](LICENSE).
