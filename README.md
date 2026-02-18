# klaus-personalities

Klaus AI personality definitions -- OCI-packaged personality artifacts containing SOUL.md identity documents and plugin compositions.

## What is a Personality?

A **personality** defines *who* the AI is and *what plugins it uses*. Each personality is a directory containing:

- `personality.yaml` -- plugin references and optional toolchain image
- `SOUL.md` -- the identity document that shapes the AI's behavior, values, and communication style

Personalities are packaged as OCI artifacts and pushed to the registry by CI on every release tag. Release tags are created automatically when a PR is merged to `main`.

## Personalities

| Name | Description | Toolchain Image |
|------|-------------|-----------------|
| `sre` | Giant Swarm SRE -- platform operations, incident response, infrastructure | `klaus-go` |
| `go` | Go developer -- idiomatic Go, testing, Giant Swarm coding standards | `klaus-go` |
| `python` | Python developer -- data engineering, scripting, automation | `klaus-python` |

## Registry Layout

Each personality is pushed as an OCI artifact to:

```
gsoci.azurecr.io/giantswarm/klaus-personalities/<name>:<tag>
```

The artifact uses custom media types:

- Config: `application/vnd.giantswarm.klaus-personality.config.v1+json`
- Content: `application/vnd.giantswarm.klaus-personality.content.v1.tar+gzip`

## Adding a New Personality

1. Create a new directory under `personalities/`:

```
personalities/my-personality/
  personality.yaml
  SOUL.md
```

2. Define the plugin list in `personality.yaml`:

```yaml
description: Short description of this personality
image: gsoci.azurecr.io/giantswarm/klaus-go:latest
plugins:
  - repository: gsoci.azurecr.io/giantswarm/klaus-plugins/gs-base
    tag: latest
  - repository: gsoci.azurecr.io/giantswarm/klaus-plugins/my-plugin
    tag: v1.0.0
```

3. Write the `SOUL.md` identity document. This defines the AI's identity, values, approach, and communication style. See existing personalities for examples.

4. Open a PR. CI will validate the structure. After merge to `main`, auto-release creates the next patch tag and all personalities are packaged and pushed to the registry.

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
