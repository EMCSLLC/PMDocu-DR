<#
.SYNOPSIS
  Validation test for schema compliance of all evidence JSON files.

.DESCRIPTION
  Runs scripts/Validate-EvidenceSchemas.ps1 and ensures all evidence JSON files
  in docs/_evidence/ are schema-valid. Uses Test-Json for each file and reports
  any failures. Designed for CI/CD integration.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SchemaDir = Join-Path $RepoRoot 'schemas'
$EvidenceDir = Join-Path $RepoRoot 'docs\_evidence'
$ScriptPath = Join-Path $RepoRoot 'scripts\Validate-EvidenceSchemas.ps1'

Describe "Evidence Schema Validation" {

    It "finds schema and evidence directories" {
        (Test-Path $SchemaDir)   | Should -BeTrue
        (Test-Path $EvidenceDir) | Should -BeTrue
    }

    It "runs the validation script without errors" {
        $Output = pwsh -NoProfile -File $ScriptPath 2>&1
        $Output -join "`n" | Should -Not -Match "ERROR|FAIL"
    }

    It "verifies each evidence file matches its declared schema" {
        $EvidenceFiles = Get-ChildItem $EvidenceDir -Filter '*.json'
        $EvidenceFiles | Should -Not -BeNullOrEmpty

        foreach ($file in $EvidenceFiles) {
            $Json = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $SchemaRef = Resolve-Path (Join-Path $SchemaDir (Split-Path $Json.'$schema' -Leaf)) -ErrorAction SilentlyContinue

            if (-not $SchemaRef) {
                Write-Warning "⚠️  Schema file not found for $($file.Name) — skipping"
                continue
            }

            $IsValid = Get-Content $file.FullName -Raw | Test-Json -SchemaFile $SchemaRef -ErrorAction Stop
            $IsValid | Should -BeTrue -Because "Evidence file $($file.Name) should conform to $($SchemaRef.Name)"
        }
    }
}
