<#
.SYNOPSIS
    Tests Build-GovDocs.ps1 for successful execution and evidence output.

.DESCRIPTION
    Confirms that the Build-GovDocs.ps1 script:
    - Runs without error
    - Generates PDFs in docs/releases/
    - Produces a BuildGovDocsResult-*.json file in docs/_evidence/
    - JSON file conforms to required schema keys

.NOTES
    Maintainer: EMCSLLC / PMDocu-DR QA
    Revision: v1.1 – 2025-10-19
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Describe 'Build-GovDocs.ps1' {

    BeforeAll {
        $Root = Resolve-Path (Join-Path $PSScriptRoot '..') | ForEach-Object { $_.Path }
        $Script = Join-Path $Root 'scripts/Build-GovDocs.ps1'
        $EvidenceDir = Join-Path $Root 'docs/_evidence'
        $ReleaseDir = Join-Path $Root 'docs/releases'
    }

    It 'Should exist in scripts directory' {
        Test-Path $Script | Should -BeTrue
    }

    It 'Should execute without throwing' {
        { & $Script } | Should -Not -Throw
    }

    It 'Should produce at least one PDF in docs/releases' {
        $pdfs = Get-ChildItem -Path $ReleaseDir -Filter '*.pdf' -ErrorAction SilentlyContinue
        $pdfs.Count | Should -BeGreaterThan 0
    }

    It 'Should generate BuildGovDocsResult evidence JSON' {
        $jsonFile = Get-ChildItem -Path $EvidenceDir -Filter 'BuildGovDocsResult-*.json' | 
            Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $jsonFile | Should -Not -BeNullOrEmpty
    }

    Context 'Validate JSON structure' {
        $jsonFile = Get-ChildItem -Path $EvidenceDir -Filter 'BuildGovDocsResult-*.json' |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1

        It 'Should contain required top-level keys' {
            $data = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            $data | Should -Not -BeNullOrEmpty
            $data.PSObject.Properties.Name | Should -Contain 'evidence_type'
            $data.PSObject.Properties.Name | Should -Contain 'timestamp_utc'
            $data.PSObject.Properties.Name | Should -Contain 'build_summary'
            $data.PSObject.Properties.Name | Should -Contain 'evidence_outputs'
        }

        It 'Should indicate build success and verified signatures' {
            $data = Get-Content $jsonFile.FullName -Raw | ConvertFrom-Json
            $data.build_summary.build_status | Should -BeExactly 'Success'
            $data.build_summary.signatures_verified | Should -BeTrue
            $data.build_summary.hashes_verified | Should -BeTrue
        }
    }
}

