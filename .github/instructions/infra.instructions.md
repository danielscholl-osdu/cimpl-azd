---
applyTo: "infra/**/*.tf"
---
# Infra Terraform Guidance
- Keep provider and module versions pinned in infra/versions.tf.
- Use variables for configuration; do not hardcode credentials.
- Avoid local-exec or external downloads unless required.
- Run terraform fmt on infra/ changes.
