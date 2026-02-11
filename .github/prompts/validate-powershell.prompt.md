---
agent: "agent"
description: "Validate PowerShell script syntax for all scripts in scripts/ directory."
---

# PowerShell Validation

Validate the syntax of all PowerShell scripts in this repository.

## Task

Run syntax validation on all .ps1 files:

```bash
pwsh -Command '
$scripts = Get-ChildItem -Path ./scripts -Filter "*.ps1" -Recurse
$hasError = $false

foreach ($script in $scripts) {
    $errors = $null
    $tokens = [System.Management.Automation.PSParser]::Tokenize(
        (Get-Content $script.FullName -Raw),
        [ref]$errors
    )

    if ($errors.Count -gt 0) {
        Write-Host "FAIL: $($script.Name)" -ForegroundColor Red
        foreach ($error in $errors) {
            Write-Host "  Line $($error.Token.StartLine): $($error.Message)" -ForegroundColor Yellow
        }
        $hasError = $true
    } else {
        Write-Host "PASS: $($script.Name)" -ForegroundColor Green
    }
}

if ($hasError) {
    Write-Host "`nValidation FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`nAll scripts valid" -ForegroundColor Green
    exit 0
}
'
```

## Report Results

List each script with PASS/FAIL status and any syntax errors found.

## Constraints

- This is a read-only syntax check
- Do NOT execute the scripts
- Do NOT modify the scripts (unless asked to fix errors)
