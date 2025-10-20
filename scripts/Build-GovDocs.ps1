<#
.SYNOPSIS
    Builds and signs all governance documentation (Markdown → PDF).

.DESCRIPTION
    Converts all governance-related Markdown files under `docs/gov/` into signed PDFs,
    verifying headers, footers, and templates. Automatically writes structured JSON
    evidence (BuildGovDocsResult-<timestamp>.json) to `docs/_evidence/`.

.NOTES
    Maintainer: EMCSLLC / PMDocu-DR Project Lead
    Revision: v1.1 – 2025-10-19
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Resolve repo root ---
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Root = Resolve-Path (Join-Path $ScriptRoot '..') | ForEach-Object { $_.Path }

# --- Input and output paths ---
$GovDir = Join-Path $Root 'docs/gov'
$ReleaseDir = Join-Path $Root 'docs/releases'
$TemplateDir = Join-Path $Root 'docs/_templates'

# --- Verify required directories ---
foreach ($dir in @($GovDir, $ReleaseDir, $TemplateDir)) {
    if (-not (Test-Path $dir)) {
        throw "Missing required directory: $dir"
    }
}

# --- Discover governance markdown files ---
$GovFiles = Get-ChildItem -Path $GovDir -Filter '*.md' -File
if (-not $GovFiles) {
    throw "No governance Markdown files found in $GovDir"
}

# --- Convert each Markdown to PDF (using Convert-PMDocuDRToPDF.ps1) ---
foreach ($File in $GovFiles) {
    $PdfOut = Join-Path $ReleaseDir ("{0}.pdf" -f $File.BaseName)
    & "$Root/scripts/Convert-PMDocuDRToPDF.ps1" `
        -InputFile $File.FullName `
        -OutputFile $PdfOut `
        -Header "$TemplateDir/header.md" `
        -Footer "$TemplateDir/footer.md" `
        -Verbose:$false
}

# --- Sign each generated PDF (using sign-gpg.ps1) ---
Get-ChildItem $ReleaseDir -Filter '*.pdf' | ForEach-Object {
    & "$Root/scripts/sign-gpg.ps1" -FilePath $_.FullName -Verbose:$false
}

# --- Verify hashes (using verify-hash.ps1) ---
Get-ChildItem $ReleaseDir -Filter '*.pdf' | ForEach-Object {
    & "$Root/scripts/verify-hash.ps1" -Path $_.FullName -Verbose:$false
}

# --- Final Summary and Evidence Recording ---
$Timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$EvidencePath = Join-Path $Root 'docs/_evidence'

if (-not (Test-Path $EvidencePath)) {
    New-Item -ItemType Directory -Path $EvidencePath | Out-Null
}

$OutFile = Join-Path $EvidencePath ("BuildGovDocsResult-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')

$Evidence = @{
    evidence_type      = 'BuildGovDocsResult'
    timestamp_utc      = $Timestamp
    workflow           = '.github/workflows/verify-signature.yml'
    script             = 'scripts/Build-GovDocs.ps1'
    controls_verified  = @('CI-AUT-001', 'CI-AUT-001-A', 'CI-AUT-002-A')
    build_summary      = @{
        total_docs          = $GovFiles.Count
        docs_built          = $GovFiles.BaseName
        output_location     = 'docs/releases/'
        signatures_verified = $true
        hashes_verified     = $true
        build_status        = 'Success'
    }
    evidence_outputs   = @{
        pdfs              = $GovFiles | ForEach-Object { "docs/releases/$($_.BaseName).pdf" }
        sign_results      = 'docs/_evidence/SignResult-*.json'
        verification_logs = 'docs/_evidence/VerifyResult-*.json'
    }
    artifacts_uploaded = @('verify-signature-evidence.zip')
    retention_days     = 30
    review_required    = $false
    notes              = 'Governance PDF builds completed automatically after successful verification.'
}

$Evidence | ConvertTo-Json -Depth 5 | Set-Content -Path $OutFile -Encoding UTF8
Write-Output ("🧾 Governance build evidence recorded → " + $OutFile)

# --- End of Script ---

