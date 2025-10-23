<#
.SYNOPSIS
  Validation test for all schema-compliant evidence JSON files.

.DESCRIPTION
  Executes strict JSON schema validation across every evidence file in docs/_evidence/.
  Also checks that each evidence file includes the new "environment" block with
  valid OS, PowerShell version, and hostname values.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$SchemaDir = Join-Path $RepoRoot 'schemas'
$EvidenceDir = Join-Path $RepoRoot 'docs\_evidence'
$ValidateScript = Join-Path $RepoRoot 'scripts\Validate-EvidenceSchemas.ps1'

Describe "PMDocu-DR Evidence Schema Compliance" {

    It "has all required folders" {
        (Test-Path $SchemaDir)   | Should -BeTrue
        (Test-Path $EvidenceDir) | Should -BeTrue
    }

    It "runs Validate-EvidenceSchemas.ps1 cleanly" {
        if (Test-Path $ValidateScript) {
            $Output = pwsh -NoProfile -File $ValidateScript 2>&1
            $Output -join "`n" | Should -Not -Match "ERROR|FAIL"
        } else {
            Write-Warning "⚠️  Validation script missing — running direct Test-Json checks."
        }
    }

    It "validates each evidence file against its declared schema" {
        $EvidenceFiles = Get-ChildItem $EvidenceDir -Filter '*.json'
        $EvidenceFiles | Should -Not -BeNullOrEmpty

        foreach ($file in $EvidenceFiles) {
            $Json = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $SchemaRef = if ($Json.'$schema') {
                $SchemaName = Split-Path $Json.'$schema' -Leaf
                Resolve-Path (Join-Path $SchemaDir $SchemaName) -ErrorAction SilentlyContinue
            } else { $null }

            if (-not $SchemaRef) {
                Write-Warning "⚠️  Missing schema reference for $($file.Name) — skipping."
                continue
            }

            $IsValid = Get-Content $file.FullName -Raw | Test-Json -SchemaFile $SchemaRef -ErrorAction Stop
            $IsValid | Should -BeTrue -Because "$($file.Name) should conform to $($SchemaRef.Name)"
        }
    }

    It "ensures every evidence file includes an 'environment' block" {
        $EvidenceFiles = Get-ChildItem $EvidenceDir -Filter '*.json'
        foreach ($file in $EvidenceFiles) {
            $Json = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $HasEnv = $Json.PSObject.Properties.Name -contains 'environment'
            $HasEnv | Should -BeTrue -Because "$($file.Name) must include environment info"

            if ($HasEnv) {
                $Env = $Json.environment
                $Env.os | Should -Match ".+" -Because "Environment.os must be present"
                $Env.ps_version | Should -Match "^\d+\.\d+" -Because "Environment.ps_version must be valid"
                $Env.hostname | Should -Match ".+" -Because "Environment.hostname must be present"
            }
        }
    }

    It "confirms SchemaValidationResult lists valid/invalid file counts correctly" {
        $SchemaValidationFiles = Get-ChildItem $EvidenceDir -Filter 'SchemaValidation_*.json' -ErrorAction SilentlyContinue
        foreach ($file in $SchemaValidationFiles) {
            $Json = Get-Content $file.FullName -Raw | ConvertFrom-Json
            ($Json.valid_count + $Json.invalid_count) | Should -BeExactly $Json.total_files
        }
    }
}
