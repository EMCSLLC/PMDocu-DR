#!/usr/bin/env pwsh
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Write-Output "🚦 Running preflight (WhatIf) before push (warn-only)..."
& pwsh -NoProfile -File scripts/Run-Preflight.ps1 -WhatIf
$code = $LASTEXITCODE
if ($code -ne 0) {
    Write-Warning ("Preflight failed with exit code {0}. Allowing push (warn-only)." -f $code)
    exit 0
}
Write-Output "✅ Preflight completed (WhatIf)."
exit 0
