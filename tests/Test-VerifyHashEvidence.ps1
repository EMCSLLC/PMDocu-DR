<#
.SYNOPSIS
  Unit test for scripts/verify-hash.ps1 evidence generation.

.DESCRIPTION
  Executes verify-hash.ps1 on a known signed file and validates:
    - Hash and signature verification succeed.
    - VerifyResult_*.json evidence file exists.
    - Evidence passes JSON schema validation.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$VerifyScript = Join-Path $RepoRoot 'scripts\verify-hash.ps1'
$SchemaPath = Join-Path $RepoRoot 'schemas\VerifyResult.schema.json'
$EvidenceDir = Join-Path $RepoRoot 'docs\_evidence'

Describe "Verify-Hash Evidence Validation" {

    BeforeAll {
        # Create mock test files if not present
        $ReleaseDir = Join-Path $RepoRoot 'docs\releases'
        if (-not (Test-Path $ReleaseDir)) { New-Item -ItemType Directory -Force -Path $ReleaseDir | Out-Null }

        $TestFile = Join-Path $ReleaseDir 'TestVerify.txt'
        'Verification test content.' | Set-Content -Path $TestFile -Encoding UTF8

        # Generate hash file
        $HashValue = (Get-FileHash -Algorithm SHA256 $TestFile).Hash
        $HashFile = [System.IO.Path]::ChangeExtension($TestFile, '.sha256')
        "$HashValue  $(Split-Path $TestFile -Leaf)" | Set-Content -Path $HashFile -Encoding ASCII

        # Optionally sign with GPG if available
        $SigFile = "$TestFile.asc"
        try {
            & gpg --batch --yes --armor --detach-sign --output $SigFile $TestFile | Out-Null
        } catch {
            Write-Warning "GPG not available in this environment; skipping signature test."
        }
    }

    It "runs the verify-hash.ps1 script without error" {
        $TestFile = Join-Path $RepoRoot 'docs\releases\TestVerify.txt'
        $Output = pwsh -NoProfile -File $VerifyScript -InputFile $TestFile 2>&1
        $Output -join "`n" | Should -Match 'STATUS=SUCCESS'
    }

    It "creates a VerifyResult evidence JSON file" {
        $EvidenceFiles = Get-ChildItem $EvidenceDir -Filter 'VerifyResult_*.json' | Sort-Object LastWriteTime -Descending
        $EvidenceFiles | Should -Not -BeNullOrEmpty
    }

    It "produces schema-compliant VerifyResult JSON" {
        $LatestEvidence = (Get-ChildItem $EvidenceDir -Filter 'VerifyResult_*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
        $SchemaPath | Should -Exist
        $IsValid = Get-Content $LatestEvidence -Raw | Test-Json -SchemaFile $SchemaPath -ErrorAction Stop
        $IsValid | Should -BeTrue -Because "Evidence file should conform to VerifyResult.schema.json"
    }

    It "reports hash and signature verification results correctly" {
        $LatestEvidence = (Get-ChildItem $EvidenceDir -Filter 'VerifyResult_*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
        $Json = Get-Content $LatestEvidence -Raw | ConvertFrom-Json
        $Json.hash_match | Should -BeTrue
        if ($Json.signature_file) {
            $Json.signature_verified | Should -BeTrue
        }
    }
}
