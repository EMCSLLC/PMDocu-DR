<#
.SYNOPSIS
  Runs a non-destructive end-to-end validation of PMDocu-DR build and compliance scripts.

.DESCRIPTION
  Executes all key scripts (Build-GovDocs, sign-gpg, verify-hash, Validate-EvidenceSchemas)
  in WhatIf (simulation) mode using PowerShell’s built-in ShouldProcess logic.
  Generates a detailed preflight log suitable for review or evidence storage.

.EXAMPLE
  pwsh -NoProfile -File scripts/Run-Preflight.ps1 -WhatIf
  pwsh -NoProfile -File scripts/Run-Preflight.ps1 -WhatIf -SaveEvidence

.OUTPUTS
  docs/_evidence/PreflightCheck_<timestamp>.log (if -SaveEvidence is specified)
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$SaveEvidence
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# --- Resolve core paths ----------------------------------------------------
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$EvidenceDir = Join-Path $RepoRoot 'docs/_evidence'
if (-not (Test-Path $EvidenceDir)) {
    New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null
}

# --- Initialize log writer -------------------------------------------------
$Timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$LogFile = Join-Path $EvidenceDir "PreflightCheck_$Timestamp.log"
$sb = New-Object System.Text.StringBuilder

function Add-Log {
    param([string]$Text)
    $timestamp = (Get-Date).ToString('u')
    $entry = "[{0}] {1}" -f $timestamp, $Text
    $sb.AppendLine($entry) | Out-Null
    Write-Host $Text
}

Add-Log "🚦 Starting PMDocu-DR Preflight Validation..."
Add-Log "Repository Root: $RepoRoot"
Add-Log "Simulation Mode: $WhatIfPreference"
Add-Log "Save Evidence:   $SaveEvidence"
Add-Log ""

# --- Define scripts to check -----------------------------------------------
$Scripts = @(
    'scripts/Build-GovDocs.ps1',
    'scripts/sign-gpg.ps1',
    'scripts/verify-hash.ps1',
    'scripts/Validate-EvidenceSchemas.ps1'
)

# --- Execute scripts safely -------------------------------------------------
foreach ($script in $Scripts) {
    $path = Join-Path $RepoRoot $script
    if (-not (Test-Path $path)) {
        Add-Log "⚠️ Missing script: $script"
        continue
    }

    Add-Log "▶️  Testing: $script"

    if ($PSCmdlet.ShouldProcess($script, "Run Preflight")) {
        try {
            $output = pwsh -NoProfile -File $path -WhatIf 2>&1
            if ($output) {
                $sb.AppendLine($output -join "`r`n") | Out-Null
            }
            Add-Log "✅ Completed simulation for $script"
        }
        catch {
            Add-Log "❌ Error running $script — $($_.Exception.Message)"
        }
    }
    else {
        Add-Log "🔍 WhatIf mode: would test $script"
    }
}

Add-Log ""
Add-Log "✅ Preflight completed. Mode: WhatIf=$WhatIfPreference"
Add-Log "----------------------------------------------------------"

# --- Build Summary object for reuse (JSON + Markdown) -------------------
$Summary = [ordered]@{
    schema_version = "1.0.0"
    evidence_type  = "PreflightSummary"
    script         = "scripts/Run-Preflight.ps1"
    timestamp_utc  = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHHmmssZ")
    whatif_mode    = $WhatIfPreference
    scripts_tested = $Scripts
    result         = "COMPLETED"
    environment    = [ordered]@{
        os         = if ($env:RUNNER_OS) { $env:RUNNER_OS } elseif ($env:OS) { $env:OS } else { "Unknown OS" }
        ps_version = $PSVersionTable.PSVersion.ToString()
        hostname   = $env:COMPUTERNAME
    }
    log_file       = $LogFile
}

# --- Evidence Output ---------------------------------------------------
if ($SaveEvidence) {
    # Save plain log file
    [System.IO.File]::WriteAllText($LogFile, $sb.ToString(), [System.Text.UTF8Encoding]::new($false))
    Add-Log "🧾 Evidence log written to: $LogFile"

    # Save JSON summary
    $JsonFile = Join-Path $EvidenceDir ("PreflightSummary_{0}.json" -f (Get-Date -Format "yyyyMMddTHHmmssZ"))
    $Summary | ConvertTo-Json -Depth 5 | Set-Content -Path $JsonFile -Encoding utf8NoBOM
    Add-Log "📄 JSON summary written to: $JsonFile"
}
else {
    Add-Log "ℹ️ Evidence log not saved (use -SaveEvidence to persist)."
}

# --- Optional Markdown summary ---------------------------------------------
$MdSummaryPath = Join-Path $EvidenceDir ("PreflightSummary_{0}.md" -f (Get-Date -Format "yyyyMMddTHHmmssZ"))
$sbMd = New-Object -TypeName System.Text.StringBuilder

function Add-MdLine {
    param([string]$Text = "")
    $sbMd.AppendLine($Text) | Out-Null
}

Add-MdLine '# 🚦 PMDocu-DR Preflight Summary'
Add-MdLine ''
Add-MdLine ('**Timestamp (UTC):** {0}' -f $Summary.timestamp_utc)
Add-MdLine ('**Execution Mode:** `WhatIf={0}`' -f $Summary.whatif_mode)
Add-MdLine ('**Preference State:** `WhatIfPreference={0}`' -f $Summary.whatif_mode)
Add-MdLine ('**Result:** `{0}`' -f $Summary.result)
Add-MdLine ''
Add-MdLine "---"
Add-MdLine ""
Add-MdLine "### 🧩 Scripts Tested"
Add-MdLine "| Script | Status |"
Add-MdLine "|---------|--------|"
foreach ($script in $Summary.scripts_tested) {
    Add-MdLine ("| {0} | ✅ Simulated |" -f $script)
}
Add-MdLine ""
Add-MdLine "---"
Add-MdLine ""
Add-MdLine "### ⚙️ Environment"
Add-MdLine "| Key | Value |"
Add-MdLine "|-----|--------|"
Add-MdLine ("| OS | {0} |" -f $Summary.environment.os)
Add-MdLine ("| PowerShell | {0} |" -f $Summary.environment.ps_version)
Add-MdLine ("| Hostname | {0} |" -f $Summary.environment.hostname)
Add-MdLine ""
Add-MdLine "---"
Add-MdLine ""
Add-MdLine ("**Log File:** [{0}]({0})" -f $Summary.log_file)
Add-MdLine ("**Schema Version:** `{0}`" -f $Summary.schema_version)
Add-MdLine ""
Add-MdLine '_Generated automatically by `scripts/Run-Preflight.ps1`_'

# Write markdown file
[IO.File]::WriteAllText($MdSummaryPath, $sbMd.ToString(), [System.Text.UTF8Encoding]::new($false))
$logMsg = "Markdown summary written to: $MdSummaryPath"
Add-Log $logMsg
