---
status: accepted
contact: cimpl-azd team
date: 2025-02-24
deciders: cimpl-azd team
consulted: Helm documentation, kustomize documentation
informed: Platform contributors, Helm chart integrators
---

# Helm Postrender with Kustomize for Safeguards Compliance

## Context and Problem Statement

AKS Automatic Deployment Safeguards require every container to have readiness/liveness probes, resource requests/limits, and seccomp profiles. Most upstream Helm charts (ECK operator, cert-manager, elastic-bootstrap) do not expose all of these fields as configurable values. We need a repeatable pattern to inject missing fields without forking upstream charts or maintaining custom chart versions.

## Decision Drivers

- Must work with any upstream Helm chart without forking
- Must be composable — each chart gets its own patch set
- Must integrate with Terraform's `helm_release` resource via `postrender` block
- Must be auditable — patches are declarative YAML files in version control
- Must not require chart-specific knowledge beyond the target resource kind/name

## Considered Options

- Helm postrender with kustomize patches
- Fork upstream Helm charts
- Replace all Helm charts with raw Kubernetes manifests
- Contribute patches upstream to each chart

## Decision Outcome

Chosen option: "Helm postrender with kustomize patches", because it provides a single, repeatable pattern for making any Helm chart AKS safeguards-compliant without forking or maintaining custom chart versions.

### Consequences

- Good, because a single pattern works for all charts — new chart additions follow the same recipe
- Good, because patches are declarative kustomize YAML, easy to review and audit
- Good, because upstream chart upgrades require only verifying the patch target still exists (kind + name)
- Good, because integrates natively with Terraform `helm_release` via the `postrender` block
- Bad, because each chart needs a postrender shell script + kustomization.yaml + patch files (boilerplate)
- Bad, because kustomize strategic merge patches must target the correct resource kind and name from the chart output — if a chart renames a resource, the patch silently becomes a no-op
- Bad, because debugging postrender failures requires inspecting intermediate YAML (pipe `helm template` through the script manually)

## Validation

- Each postrender script in `platform/kustomize/` is executable (`chmod +x`)
- `helm template <chart> | ./kustomize/<chart>-postrender.sh` produces YAML with injected probes
- `kubectl get pods -A -o json | jq '.items[].spec.containers[].readinessProbe'` — no null values in safeguarded namespaces

## Pros and Cons of the Options

### Helm Postrender with Kustomize

Helm's `--post-renderer` flag pipes rendered manifests through an external command. We use a shell script that runs `kubectl kustomize` to apply strategic merge patches.

Pattern per chart:
- `platform/kustomize/<chart>-postrender.sh` — shell script (stdin → kustomize → stdout)
- `platform/kustomize/<chart>/kustomization.yaml` — patch references
- `platform/kustomize/<chart>/<resource>-patch.yaml` — strategic merge patches

Example: ECK operator postrender injects tcpSocket probes on port 9443 into the `elastic-operator` StatefulSet.

- Good, because works with any Helm chart without modification
- Good, because patches are version-controlled and declarative
- Good, because composable — multiple patches per chart, one pattern for all charts
- Neutral, because requires `kubectl` available at apply time (bundled with AKS toolchain)
- Bad, because boilerplate per chart (script + kustomization + patches)
- Bad, because patch target (kind/name) must match chart output exactly

### Fork Upstream Charts

Maintain internal copies of each Helm chart with probes/resources injected directly in templates.

- Good, because no postrender complexity — standard Helm workflow
- Bad, because fork maintenance burden multiplied per chart
- Bad, because upstream security patches require manual merge into each fork
- Bad, because divergence from upstream makes community support harder

### Raw Kubernetes Manifests for Everything

Replace all Helm charts with hand-authored Kubernetes YAML, giving full control over every field.

- Good, because complete control — no patches needed
- Good, because no dependency on Helm or kustomize
- Bad, because loses Helm's templating, release management, and rollback
- Bad, because dramatically increases YAML volume and maintenance burden
- Bad, because makes upgrading components much harder (no `helm upgrade`)

### Contribute Patches Upstream

Submit PRs to each upstream chart to expose probe/resource/seccomp configuration as Helm values.

- Good, because benefits the entire community
- Good, because eliminates need for postrender once merged
- Bad, because upstream maintainer timelines are outside our control
- Bad, because some charts have design philosophies that resist these changes
- Bad, because does not solve the immediate deployment need

## More Information

- [Helm Post Rendering](https://helm.sh/docs/topics/advanced/#post-rendering)
- [Kustomize Strategic Merge Patches](https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/patches/)
- Implementation: `platform/kustomize/eck-operator-postrender.sh`, `platform/kustomize/eck-operator/`
- Related: [ADR-0001](0001-use-aks-automatic-as-deployment-target.md) (why safeguards exist)
