# Script Fixes Design: Issues #40, #41, #42

## Overview

Three fixes to the azd deployment scripts to ensure a clean `azd up` flow.

## Fix #40: Resource provider check shows blank state

**File:** `scripts/pre-provision.ps1` (lines 80-90)
**Problem:** `az provider show` output has trailing whitespace/newlines causing `-eq "Registered"` to fail.
**Fix:** Trim output, handle null, only show registration hint when not registered.

## Fix #41: Missing subscription context in post-provision

**Files:** `scripts/ensure-safeguards.ps1`, `scripts/deploy-platform.ps1`
**Problem:** `az aks get-credentials` and `az aks show` calls lack `--subscription`, failing for multi-subscription users.
**Fix:** Read `AZURE_SUBSCRIPTION_ID` from environment (set by azd), pass to all `az` commands. Fall back to terraform output.

## Fix #42: RBAC wait loop auth error detection

**File:** `scripts/ensure-safeguards.ps1` (lines 50-75)
**Problem:** Auth failures from kubelogin waste 300s in the retry loop before failing.
**Fix:** Inspect `kubectl auth can-i` output for auth error patterns (AADSTS, unauthorized, token). Fail fast with re-auth instructions.

## Delivery

Single branch `fix/script-improvements`, one commit per fix, single PR closing all 3 issues.
