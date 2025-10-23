<#
.SYNOPSIS
  Converts governance Markdown documents to signed PDF deliverables.

.DESCRIPTION
  Iterates over governance Markdown files in docs/gov or docs/review,
  converts each to PDF using Pandoc + XeLaTeX, and emits a schema-compliant
  BuildGovDocsResult_<timestamp>.json evidence record.

.EXAMPLE
  pwsh -NoProfile -File scripts/Build-GovDocs.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

Write-Host "=== 🧾 Starting Governance Document Build ==="

# --- Path setup -----------------------------------------------------------
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot '..')
$DocsRoot = Join-Path $RepoRoot 'docs'
$SrcDirs = @('gov', 'review') | ForEach-Object { Join-Path $DocsRoot $_ } | Where-Object { Test-Path $_ }
$OutDir = Join-Path $DocsRoot 'releases'
$EvidenceDir = Join-Path $DocsRoot '_evidence'
$SchemaPath = Join-Path $RepoRoot 'schemas\BuildGovDocsResult.schema.json'

# --- Directory setup -------------------------------------------------------
$GovDir = Join-Path $DocsRoot 'gov'
if (-not (Test-Path $GovDir)) {
    Write-Warning "⚠️ Governance directory not found at: $GovDir"
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
if (-not (Test-Path $EvidenceDir)) { New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null }

# --- Environment info (cross-platform) -----------------------------------
$LibPath = Join-Path $PSScriptRoot 'lib/Get-OsInfo.ps1'
$OsInfo = if (Test-Path $LibPath) { & $LibPath } else {
    [PSCustomObject]@{
        OsName    = $env:RUNNER_OS
        HostName  = $env:COMPUTERNAME
        PsVersion = $PSVersionTable.PSVersion.ToString()
        Platform  = 'Unknown'
    }
}
$OSName = $OsInfo.OsName
$Hostname = $OsInfo.HostName
$PSVersion = $OsInfo.PsVersion

# --- Font detection ------------------------------------------------------
$Font = if ($IsWindows) { 'DejaVu Sans' } elseif ($IsLinux) { 'Liberation Sans' } else { 'Helvetica' }

# --- Converter metadata --------------------------------------------------
$StartTime = Get-Date
$ConverterTool = "pandoc"
$PandocVersion = (& pandoc --version | Select-String '^pandoc' | Select-Object -First 1).ToString().Trim()

$SourceFiles = @()
$OutputFiles = @()
$Warnings = @()
$Errors = @()

# --- File conversion loop -------------------------------------------------
foreach ($dir in $SrcDirs) {
    Write-Host "📂 Scanning $dir ..."
    $mdFiles = Get-ChildItem -Path $dir -Filter '*.md' -File -ErrorAction SilentlyContinue
    foreach ($file in $mdFiles) {
        $SourceFiles += $file.FullName
        $pdfName = [System.IO.Path]::ChangeExtension($file.Name, '.pdf')
        $pdfPath = Join-Path $OutDir $pdfName
        try {
            Write-Host "🛠️  Converting: $($file.Name) → $pdfName"
            & pandoc $file.FullName -o $pdfPath --pdf-engine=xelatex -V "mainfont=$Font" 2>&1 | Out-Null
            if (Test-Path $pdfPath) {
                $OutputFiles += $pdfPath
            }
            else {
                throw "Conversion failed: $pdfName not created."
            }
        }
        catch {
            $msg = $_.Exception.Message
            Write-Warning "⚠️  $msg"
            $Warnings += $msg
            $Errors += $msg
        }
    }
}

# --- Step X: Update compliance footer timestamp --------------------------
$MatrixPath = Join-Path $GovDir 'CI-Compliance-Matrix.md'
if (Test-Path $MatrixPath) {
    try {
        $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss UTC')
        $content = Get-Content $MatrixPath -Raw -Encoding utf8

        if ($content -match '\$\(Get-Date') {
            # Replace placeholder pattern with fresh UTC timestamp
            $updated = $content -replace '\$\(Get-Date.+?\)', $timestamp
            $updated | Set-Content -Path $MatrixPath -Encoding utf8NoBOM
            Write-Host "🕒 Updated CI-Compliance-Matrix.md timestamp: $timestamp"
        }
        else {
            Write-Warning "⚠️  No timestamp placeholder found in CI-Compliance-Matrix.md — footer not updated."
        }

    }
    catch {
        Write-Warning "⚠️  Failed to update CI-Compliance-Matrix.md timestamp: $($_.Exception.Message)"
    }
}
else {
    Write-Warning "⚠️  CI-Compliance-Matrix.md not found in $DocsDir — skipping timestamp update."
}

# --- Build result summary -------------------------------------------------
$EndTime = Get-Date
$Duration = [math]::Round(($EndTime - $StartTime).TotalSeconds, 2)
$Status = if ($Errors.Count -eq 0) { "SUCCESS" } elseif ($OutputFiles.Count -gt 0) { "PARTIAL" } else { "FAILURE" }

$Timestamp = $EndTime.ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$EvidenceFile = Join-Path $EvidenceDir "BuildGovDocsResult_$Timestamp.json"

$BuildResult = [ordered]@{
    '$schema'        = '../schemas/BuildGovDocsResult.schema.json'
    timestamp        = $EndTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    status           = $Status
    source_files     = $SourceFiles
    output_files     = $OutputFiles
    converter        = [ordered]@{
        tool    = $ConverterTool
        version = $PandocVersion
        options = "--pdf-engine=xelatex -V mainfont='$Font'"
    }
    duration_seconds = $Duration
    environment      = [ordered]@{
        os         = $OSName
        ps_version = $PSVersion
        hostname   = $Hostname
    }
    warnings         = $Warnings
    errors           = $Errors
    evidence_output  = $EvidenceFile
}

$Json = $BuildResult | ConvertTo-Json -Depth 6 | Out-String
$Json | Set-Content -Path $EvidenceFile -Encoding utf8NoBOM

Write-Host "🧾 Evidence JSON written: $EvidenceFile"

# --- Schema self-validation ----------------------------------------------
if (Test-Path $SchemaPath) {
    $IsValid = Get-Content $EvidenceFile -Raw | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop
    if ($IsValid) {
        Write-Host "✅ Schema validation passed for: $EvidenceFile"
    }
    else {
        Write-Warning "⚠️  Schema validation failed for: $EvidenceFile"
    }
}
else {
    Write-Warning "⚠️  Schema file not found: $SchemaPath"
}

# --- Summary output for CI -----------------------------------------------
Write-Output ("SOURCE_COUNT={0}" -f $SourceFiles.Count)
Write-Output ("OUTPUT_COUNT={0}" -f $OutputFiles.Count)
Write-Output ("STATUS={0}" -f $Status)
Write-Output ("EVIDENCE_FILE={0}" -f $EvidenceFile)

if ($Status -ne "SUCCESS") { exit 1 }
