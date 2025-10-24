param(
    [string]$Repo = "EMCSLLC/PMDocu-DR",
    [string]$Branch = "main",
    [string[]]$Checks = @(
        'Lint PowerShell',
        'Pester Tests',
        'Evidence Schema Validation',
        'Preflight (WhatIf)'
    ),
    [int]$RequiredApprovals = 1,
    [switch]$AdminsEnforce = $true
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is required. Install from https://cli.github.com/ and run 'gh auth login'."
}

# Build request body conforming to branch protection API
$body = @{
    required_status_checks        = @{
        strict = $true
        checks = @()
    }
    enforce_admins                = [bool]$AdminsEnforce
    required_pull_request_reviews = @{
        required_approving_review_count = $RequiredApprovals
        dismiss_stale_reviews           = $true
        require_code_owner_reviews      = $false
    }
    restrictions                  = $null
}

foreach ($c in $Checks) {
    $body.required_status_checks.checks += @{ context = $c }
}

$json = $body | ConvertTo-Json -Depth 6

Write-Host ("Applying branch protection to {0}@{1}..." -f $Repo, $Branch) -ForegroundColor Cyan

# Apply protection with a one-time retry on failure (no loop)
function Invoke-ApplyBranchProtection {
    param(
        [string]$OwnerRepo,
        [string]$BranchName,
        [string]$JsonBody
    )
    # Use pipeline to provide input; check exit code explicitly since external tools don't throw by default
    $null = $JsonBody | & gh api --method PUT `
        -H "Accept: application/vnd.github+json" `
        "repos/$OwnerRepo/branches/$BranchName/protection" `
        --input -
    if ($LASTEXITCODE -ne 0) {
        throw "gh api failed with exit code $LASTEXITCODE"
    }
}

try {
    Invoke-ApplyBranchProtection -OwnerRepo $Repo -BranchName $Branch -JsonBody $json
}
catch {
    Write-Warning ("Apply failed (attempt 1/2): {0}" -f $_.Exception.Message)
    Start-Sleep -Seconds 2
    try {
        Invoke-ApplyBranchProtection -OwnerRepo $Repo -BranchName $Branch -JsonBody $json
        Write-Host "Succeeded after one retry (attempt 2)." -ForegroundColor Yellow
    }
    catch {
        throw
    }
}

# Show result
Write-Host "Current protection:" -ForegroundColor Green
$protection = gh api "repos/$Repo/branches/$Branch/protection" -H "Accept: application/vnd.github+json" | ConvertFrom-Json
$protection | Format-List *
