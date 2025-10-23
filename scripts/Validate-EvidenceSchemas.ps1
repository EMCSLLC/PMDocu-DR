<#
.SYNOPSIS
  Validates all PMDocu-DR evidence JSON files against their corresponding JSON Schemas.

.DESCRIPTION
  Scans docs/_evidence/ for any JSON evidence files (SignResult, VerifyResult,
  BuildGovDocsResult, etc.) and validates each against its schema in /schemas.
  Generates a summary evidence report (SchemaValidation_<timestamp>.json)
  for compliance tracking.

  🧩 Schema Enforcement:
  All PMDocu-DR schemas must conform to **JSON Schema Draft-07**.
  This script enforces that rule before validation begins.
  If any schema declares a newer or older meta-schema (e.g. 2020-12),
  the run will fail with a clear message. This prevents accidental drift
  and ensures full compatibility with PowerShell’s Test-Json cmdlet
  and GitHub Actions CI.

.OUTPUTS
  SchemaValidation_<timestamp>.json written to docs/_evidence/

.EXAMPLE
  pwsh -NoProfile -File scripts/Validate-EvidenceSchemas.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$InformationPreference = "Continue"

# --- Enforce JSON Schema Draft-07 Standard ------------------------------
$SchemaDirPath = Join-Path $PSScriptRoot '..\schemas'
$SchemaFiles = Get-ChildItem -Path $SchemaDirPath -Filter '*.schema.json' -File

$NonDraft7 = @()
foreach ($schema in $SchemaFiles) {
    $firstLines = Get-Content $schema.FullName -TotalCount 5 -ErrorAction SilentlyContinue
    if ($firstLines -notmatch 'draft-07') { $NonDraft7 += $schema.Name }
}

$SchemaEnforcement = [ordered]@{
    enforced      = $true
    standard      = 'draft-07'
    non_compliant = $NonDraft7
    status        = if ($NonDraft7.Count -gt 0) { 'FAIL' } else { 'PASS' }
    checked_count = $SchemaFiles.Count
    schema_dir    = (Resolve-Path $SchemaDirPath).Path
}

$SchemaDraftEnforcementFailed = $NonDraft7.Count -gt 0

# --- Paths --------------------------------------------------------------
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Resolve-Path (Join-Path $ScriptRoot '..')
$SchemaDir = Join-Path $RepoRoot 'schemas'
$EvidenceDir = Join-Path $RepoRoot 'docs/_evidence'

if (-not (Test-Path $SchemaDir)) { throw "Schema directory not found: $SchemaDir" }
if (-not (Test-Path $EvidenceDir)) { throw "Evidence directory not found: $EvidenceDir" }

# --- Load schemas -------------------------------------------------------
$Schemas = Get-ChildItem $SchemaDir -Filter '*.schema.json' -File

$Results = @()
$InvalidCount = 0

# --- Validate all evidence files ---------------------------------------
foreach ($schema in $Schemas) {
    $schemaName = [IO.Path]::GetFileNameWithoutExtension($schema.Name)
    $evidenceFiles = Get-ChildItem $EvidenceDir -Filter "$schemaName*.json" -ErrorAction SilentlyContinue
    if (-not $evidenceFiles) { continue }

    foreach ($file in $evidenceFiles) {
        try {
            $json = Get-Content $file.FullName -Raw
            $isValid = Test-Json -Json $json -SchemaFile $schema.FullName -ErrorAction Stop

            $Results += [ordered]@{
                schema        = $schema.Name
                evidence      = $file.Name
                valid         = $isValid
                timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            }

            if (-not $isValid) { $InvalidCount++ }

        }
        catch {
            $InvalidCount++
            $Results += [ordered]@{
                schema        = $schema.Name
                evidence      = $file.Name
                valid         = $false
                error         = $_.Exception.Message
                timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
        }
    }
}

# --- Summary & Placeholder Coverage ------------------------------------
$total = $Results.Count
$overallFailure = ($InvalidCount -gt 0) -or $SchemaDraftEnforcementFailed

# --- Auto-generate placeholder evidence for missing schemas ------------
$AllSchemaNames = $Schemas | ForEach-Object { [IO.Path]::GetFileNameWithoutExtension($_.Name) }
$Placeholders = @()

foreach ($schemaFile in $Schemas) {
    $schemaName = $schemaFile.Name
    $alreadyValidated = $Results | Where-Object { $_.schema -eq $schemaName }
    if (-not $alreadyValidated) {
        $Placeholders += [ordered]@{
            schema        = $schemaName
            evidence      = $null
            valid         = $false
            error         = "No evidence files found for this schema type."
            note          = "Placeholder entry — schema validated but no corresponding evidence JSON found."
            timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
    }
}

if ($Placeholders.Count -gt 0) {
    $Results += $Placeholders
}

# --- Annotate any invalid results with notes ---------------------------
foreach ($r in $Results) {
    if (-not $r.valid -and -not ($r.Keys -contains 'note')) {
        $r['note'] = "Schema validation failed — review required."
    }
}

$MissingCount = $Placeholders.Count
$total = $Results.Count
$ValidCount = $total - $InvalidCount - $MissingCount
$Completeness = if ($total -eq 0) { 0 } else { [math]::Round(($ValidCount / $total) * 100, 2) }

# --- Determine review triggers ----------------------------------------
$ReviewReasons = @()
if ($InvalidCount -gt 0) { $ReviewReasons += "invalid_files" }
if ($MissingCount -gt 0) { $ReviewReasons += "missing_schemas" }
if ($SchemaDraftEnforcementFailed) { $ReviewReasons += "non_draft7" }

$RequiresReview = $ReviewReasons.Count -gt 0
$FinalStatus = if ($RequiresReview) { "REVIEW_REQUIRED" } else { "SUCCESS" }

# --- Step: Validate CI-Compliance-Matrix footer timestamp ----------------
$FooterCheck = [ordered]@{
    file_exists     = $false
    placeholder_ok  = $false
    timestamp_valid = $false
    status          = "SKIPPED"
    message         = ""
}

$MatrixPath = Join-Path $RepoRoot 'docs/gov/CI-Compliance-Matrix.md'
if (Test-Path $MatrixPath) {
    $FooterCheck.file_exists = $true
    try {
        $content = Get-Content $MatrixPath -Raw -Encoding utf8
        # Match a UTC timestamp at the end or footer section
        if ($content -match '(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+UTC)') {
            $FooterCheck.placeholder_ok = $true
            $tsString = $Matches[1]
            $tsParsed = [datetime]::ParseExact($tsString, 'yyyy-MM-dd HH:mm:ss UTC', $null)
            $ageHours = [math]::Round((New-TimeSpan -Start $tsParsed -End (Get-Date).ToUniversalTime()).TotalHours, 2)
            if ($ageHours -le 24) {
                $FooterCheck.timestamp_valid = $true
                $FooterCheck.status = "PASS"
                $FooterCheck.message = "Timestamp is current (${ageHours}h old)."
            }
            else {
                $FooterCheck.status = "FAIL"
                $FooterCheck.message = "Timestamp is stale (${ageHours}h old)."
            }
        }
        else {
            $FooterCheck.status = "FAIL"
            $FooterCheck.message = "Timestamp placeholder not found."
        }
    }
    catch {
        $FooterCheck.status = "ERROR"
        $FooterCheck.message = $_.Exception.Message
    }
}
else {
    $FooterCheck.status = "MISSING"
    $FooterCheck.message = "CI-Compliance-Matrix.md not found."
}

# --- Step: Validate CI-Compliance-Matrix footer timestamp ----------------
$FooterCheck = [ordered]@{
    file_exists           = $false
    placeholder_ok        = $false
    timestamp_valid       = $false
    aligned_with_evidence = $false
    status                = "SKIPPED"
    message               = ""
}

# (rest of your footer validation logic that updates $FooterCheck)
# ...
# ...
# After it's fully built and has status + message, THEN build evidence

# --- Setup validation Evidence JSON ---
$OutputFile = Join-Path $EvidenceDir ("SchemaValidation_{0}.json" -f (Get-Date -Format "yyyyMMddTHHmmssZ"))

$Evidence = [ordered]@{
    schema_version       = "1.0.0"
    evidence_type        = "SchemaValidationResult"
    script               = "scripts/Validate-EvidenceSchemas.ps1"
    timestamp_utc        = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    total_validated      = $total
    valid_count          = $ValidCount
    invalid_count        = $InvalidCount
    missing_count        = $MissingCount
    completeness_percent = $Completeness
    draft_enforcement    = $SchemaEnforcement
    review_reasons       = $ReviewReasons
    results              = $Results
    environment          = [ordered]@{
        os         = if ($env:RUNNER_OS) { $env:RUNNER_OS } elseif ($env:OS) { $env:OS } else { "Unknown OS" }
        ps_version = $PSVersionTable.PSVersion.ToString()
        hostname   = $env:COMPUTERNAME
    }
    status               = $FinalStatus
    footer_check         = $FooterCheck   # ✅ Now safely added here
}


$MatrixPath = Join-Path $RepoRoot 'docs/gov/CI-Compliance-Matrix.md'
if (Test-Path $MatrixPath) {
    $FooterCheck.file_exists = $true
    try {
        $content = Get-Content $MatrixPath -Raw -Encoding utf8
        # Match UTC-style footer timestamp
        if ($content -match '(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+UTC)') {
            $FooterCheck.placeholder_ok = $true
            $tsString = $Matches[1]
            $tsParsed = [datetime]::ParseExact($tsString, 'yyyy-MM-dd HH:mm:ss UTC', $null)
            $ageHours = [math]::Round((New-TimeSpan -Start $tsParsed -End (Get-Date).ToUniversalTime()).TotalHours, 2)

            # Determine newest evidence timestamp for comparison
            $EvidenceFiles = Get-ChildItem -Path $EvidenceDir -Filter '*.json' -File -ErrorAction SilentlyContinue
            if ($EvidenceFiles) {
                $NewestEvidence = ($EvidenceFiles | Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1)
                $NewestEvidenceTime = $NewestEvidence.LastWriteTimeUtc
                if ($tsParsed -ge $NewestEvidenceTime) {
                    $FooterCheck.aligned_with_evidence = $true
                }
                else {
                    $FooterCheck.message += " Footer timestamp older than latest evidence ($($NewestEvidence.Name))."
                }
            }

            # Evaluate timestamp validity (<= 24h old)
            if ($ageHours -le 24) {
                $FooterCheck.timestamp_valid = $true
            }

            # Determine final status
            if ($FooterCheck.timestamp_valid -and $FooterCheck.aligned_with_evidence) {
                $FooterCheck.status = "PASS"
                $FooterCheck.message += " Timestamp current (${ageHours}h old) and aligned."
            }
            else {
                $FooterCheck.status = "FAIL"
                if (-not $FooterCheck.timestamp_valid) {
                    $FooterCheck.message += " Timestamp stale (${ageHours}h old)."
                }
                if (-not $FooterCheck.aligned_with_evidence) {
                    $FooterCheck.message += " Footer older than latest evidence file."
                }
            }

        }
        else {
            $FooterCheck.status = "FAIL"
            $FooterCheck.message = "Timestamp placeholder not found."
        }
    }
    catch {
        $FooterCheck.status = "ERROR"
        $FooterCheck.message = $_.Exception.Message
    }
}
else {
    $FooterCheck.status = "MISSING"
    $FooterCheck.message = "CI-Compliance-Matrix.md not found."
}

# Attach to overall evidence record
$Evidence['footer_check'] = $FooterCheck



# --- Step 7: Generate Markdown Summary (StringBuilder version) ----------------
$SummaryMdPath = Join-Path $EvidenceDir ("SchemaValidationSummary_{0}.md" -f (Get-Date -Format "yyyyMMddTHHmmssZ"))

# --- Initialize StringBuilder helper ----------------------------------------
$sb = New-Object -TypeName System.Text.StringBuilder
function Add-Line {
    param([string]$Text = "")
    $script:sb.AppendLine($Text) | Out-Null
}

# --- Safety checks -----------------------------------------------------------
$FooterStatus = if ($FooterCheck -and $FooterCheck.status) { $FooterCheck.status } else { "N/A" }
$FooterMsg = if ($FooterCheck -and $FooterCheck.message) { $FooterCheck.message } else { "No message." }

# --- Header ------------------------------------------------------------------
Add-Line ("# 🧩 Schema Validation Summary")
Add-Line ""
Add-Line ("**Timestamp (UTC):** {0}" -f $Evidence.timestamp_utc)
Add-Line ('**Status:** `{0}`' -f $FinalStatus)
Add-Line ""

# --- Validation Metrics Table ------------------------------------------------
$CompletenessText = ('{0}%' -f $Completeness)

$metrics = @(
    @{ Metric = 'Total Schemas'; Count = $Evidence.total_validated; Details = '' },
    @{ Metric = 'Valid'; Count = $Evidence.valid_count; Details = '' },
    @{ Metric = 'Invalid'; Count = $Evidence.invalid_count; Details = '' },
    @{ Metric = 'Missing'; Count = $Evidence.missing_count; Details = '' },
    @{ Metric = 'Completeness (%)'; Count = $CompletenessText; Details = '' }
)

Add-Line "### 📊 Validation Metrics"
Add-Line ""
Add-Line '| Metric | Count | Details |'
Add-Line '|--------|-------|---------|'
foreach ($m in $metrics) {
    Add-Line ("| {0} | {1} | {2} | " -f $m.Metric, $m.Count, $m.Details)
}
Add-Line ""
Add-Line "### ⚙️ Draft Enforcement"
Add-Line ('**Status:** `{0}`' -f $Evidence.draft_enforcement.status)
$nonCompliant = if ($Evidence.draft_enforcement.non_compliant -and $Evidence.draft_enforcement.non_compliant.Count -gt 0) {
    ($Evidence.draft_enforcement.non_compliant -join ', ')
}
else { 'None' }
Add-Line ("**Non-compliant Schemas:** {0}" -f $nonCompliant)

# --- Footer Timestamp Validation --------------------------------------------
Add-Line ""
Add-Line "### 🕒 Footer Timestamp Validation"
Add-Line ('**Footer Check Status:** `{0}`' -f $FooterStatus)
Add-Line ('**Message:** {0}' -f $FooterMsg)

# --- Footer ------------------------------------------------------------------
Add-Line ""
Add-Line '_Generated by `scripts/Validate-EvidenceSchemas.ps1`_'

# --- Write Markdown summary --------------------------------------------------
$null = [IO.File]::WriteAllText($SummaryMdPath, $sb.ToString(), [Text.UTF8Encoding]::new($false))
Write-Output ("🧾 Markdown summary written: {0}" -f $SummaryMdPath)

$Evidence | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputFile -Encoding utf8NoBOM

# --- Structured CI Summary ---------------------------------------------
$EnforceStatus = if ($SchemaDraftEnforcementFailed) { 'FAIL' } else { 'PASS' }

Write-Output ("SUMMARY: VALID={0} INVALID={1} MISSING={2} COMPLETENESS={3}% ENFORCEMENT={4} STATUS={5} REASONS={6}" -f $ValidCount, $InvalidCount, $MissingCount, $Completeness, $EnforceStatus, $FinalStatus, ($ReviewReasons -join ','))

Write-Output ("EVIDENCE_FILE={0}" -f $OutputFile)

# --- Exit Code Logic ---------------------------------------------------
if ($RequiresReview) {
    exit 1
}
else {
    exit 0
}
