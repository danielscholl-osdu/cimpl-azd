# Decision: Partition postrender wiring and bootstrap image pinning

## Context
- The shared kustomize postrender script requires a SERVICE_NAME environment variable.
- The Partition bootstrap image in ROSA defaults to `:latest`, which AKS Automatic blocks.

## Decision
- Use Helm postrender with `/usr/bin/env` to pass `SERVICE_NAME=partition` to `platform/kustomize/postrender.sh`.
- Pin the Partition bootstrap image to the same tag as the main Partition image (`67dedce7`) until an upstream bootstrap tag is confirmed.

## Consequences
- All service Helm releases can reuse the shared postrender script without per-service wrapper scripts.
- Bootstrap image tag may need updates once the authoritative tag is identified.
