<#
.SYNOPSIS
  Unit test for scripts/sign-gpg.ps1 evidence generation.

.DESCRIPTION
  Executes the sign-gpg.ps1 script on a small test file and validates that:
    - A .asc and .sha256 file are produced
    - A schema-compliant SignResult_*.json evidence file is written
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ScriptPath = Join-Path $RepoRoot 'scripts\sign-gpg.ps1'
$SchemaPath = Join-Path $RepoRoot 'schemas\SignResult.schema.json'
$EvidenceDir = Join-Path $RepoRoot 'docs\_evidence'
if (-not (Test-Path $EvidenceDir)) { New-Item -ItemType Directory -Force -Path $EvidenceDir | Out-Null }

Describe "Sign-GPG Evidence Generation" {

    It "creates a temporary test file" {
        $TestFile = Join-Path $RepoRoot 'docs\releases\TestDoc.txt'
        'Test content for GPG signing validation.' | Set-Content -Path $TestFile -Encoding UTF8
        Test-Path $TestFile | Should -BeTrue
    }

    It "runs the signing script without errors" {
        $TestFile = Join-Path $RepoRoot 'docs\releases\TestDoc.txt'
        $Output = pwsh -NoProfile -File $ScriptPath -InputFile $TestFile 2>&1
        $Output -join "`n" | Should -Match 'STATUS=SUCCESS'
    }

    It "produces signature and hash files" {
        $AscFile = Join-Path $RepoRoot 'docs\releases\TestDoc.txt.asc'
        $HashFile = Join-Path $RepoRoot 'docs\releases\TestDoc.sha256'
        (Test-Path $AscFile) | Should -BeTrue
        (Test-Path $HashFile) | Should -BeTrue
    }

    It "creates a SignResult evidence JSON file" {
        $EvidenceFiles = Get-ChildItem $EvidenceDir -Filter 'SignResult_*.json' | Sort-Object LastWriteTime -Descending
        $LatestEvidence = $EvidenceFiles | Select-Object -First 1
        $LatestEvidence | Should -Not -BeNullOrEmpty
    }

    It "validates evidence JSON against schema" {
        $LatestEvidence = (Get-ChildItem $EvidenceDir -Filter 'SignResult_*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
        $SchemaPath | Should -Exist
        $IsValid = Get-Content $LatestEvidence -Raw | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop
        $IsValid | Should -BeTrue
    }
}
