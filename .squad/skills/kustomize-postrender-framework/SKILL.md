# Skill: Kustomize Postrender Framework for AKS Safeguards

## Goal
Apply shared AKS safeguards compliance patches to Helm charts using kustomize components and a single postrender script.

## Inputs
- `SERVICE_NAME` environment variable (Helm release name)
- Service overlay in `platform/kustomize/services/<service>`

## Steps
1. Copy `platform/kustomize/services/partition` to a new service directory.
2. Update `probes.yaml` and `resources.yaml` for the service's endpoints and sizing.
3. Run Helm/Terraform with `SERVICE_NAME` set so `platform/kustomize/postrender.sh` selects the overlay.

## Files
- `platform/kustomize/postrender.sh`
- `platform/kustomize/components/{seccomp,security-context,topology-spread}`
- `platform/kustomize/services/<service>`
