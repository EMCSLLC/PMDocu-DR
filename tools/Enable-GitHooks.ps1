param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$hooksDir = Join-Path $repoRoot '.git/hooks'
if (-not (Test-Path $hooksDir)) {
    throw "This doesn't look like a Git repository (missing .git/hooks)."
}

$rootForBash = ($repoRoot -replace '\\', '/')
$preCommitWrapperLines = @(
    '#!/usr/bin/env bash',
    'set -euo pipefail',
    ('exec pwsh -NoLogo -NoProfile -File "{0}/.githooks/pre-commit.ps1"' -f $rootForBash)
)
$preCommitWrapper = $preCommitWrapperLines -join "`n"

$prePushWrapperLines = @(
    '#!/usr/bin/env bash',
    'set -euo pipefail',
    ('exec pwsh -NoLogo -NoProfile -File "{0}/.githooks/pre-push.ps1"' -f $rootForBash)
)
$prePushWrapper = $prePushWrapperLines -join "`n"

# Write wrappers into .git/hooks (not tracked, avoids lint noise)
[IO.File]::WriteAllText((Join-Path $hooksDir 'pre-commit'), $preCommitWrapper, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $hooksDir 'pre-push'), $prePushWrapper, [Text.UTF8Encoding]::new($false))

Write-Host "✅ Installed Git hooks wrappers to .git/hooks" -ForegroundColor Green
Write-Host " - pre-commit -> .githooks/pre-commit.ps1"
Write-Host " - pre-push    -> .githooks/pre-push.ps1"

Write-Host "Tip: If Git complains about permissions, you can run: git config core.hooksPath .git/hooks" -ForegroundColor Yellow
