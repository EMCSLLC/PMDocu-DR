#!/usr/bin/env pwsh
Write-Output "🔧 Running Normalize-Spacing.ps1 pre-commit formatter..."
$changed = git diff --cached --name-only --diff-filter=ACM | Where-Object { $_ -like '*.ps1' }
foreach ($f in $changed) {
    pwsh -NoProfile -File scripts/Normalize-Spacing.ps1 -Path $f
    git add $f
}
Write-Output "✅ Spacing normalization complete."
