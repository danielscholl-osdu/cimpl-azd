---
agent: "agent"
description: "Run Terraform validation checks (format, validate) for both infra/ and platform/ layers."
---

# Terraform Validation

Run the standard Terraform validation workflow for this repository.

## Tasks

### 1. Format Check

Check that all Terraform files are properly formatted:

```bash
# Check infra layer
terraform fmt -check -recursive ./infra

# Check platform layer
terraform fmt -check -recursive ./platform
```

If formatting issues are found, fix them:

```bash
terraform fmt -recursive ./infra
terraform fmt -recursive ./platform
```

### 2. Validate Syntax (Optional)

**Only run if providers are already initialized.** Do not run `terraform init` without explicit permission.

```bash
# If .terraform directory exists and has providers
cd infra && terraform validate
cd ../platform && terraform validate
```

### 3. Report Results

Report:
- Which files needed formatting (if any)
- Any validation errors found
- Summary: PASS or FAIL

## Constraints

- Do NOT run `terraform init` unless explicitly requested
- Do NOT run `terraform plan` or `terraform apply`
- These are safe, read-only checks
