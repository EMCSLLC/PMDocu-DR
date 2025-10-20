<#
.SYNOPSIS
    Applies v1.2 JSON evidence validation blocks to all CI workflows.

.DESCRIPTION
    Scans .github/workflows for known PMDocu-DR YAMLs and ensures each
    contains a “Validate JSON Evidence” step per the v1.2 compliance matrix.
    Backs up originals, applies patch, and commits automatically.

.EXAMPLE
    pwsh -File scripts/Apply-EvidenceValidation.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

Write-Information "[patch] Starting evidence validation patch (v1.2)..."

$workflowDir = '.github/workflows'
$backupsDir = 'docs/_evidence/workflow_backups'
New-Item -ItemType Directory -Force -Path $backupsDir | Out-Null

$patches = @{
    'build-docs.yml'       = @'
      - name: 🔍 Validate Build Evidence
        shell: pwsh
        run: |
          Write-Information "[ci-docs] Verifying JSON build evidence..."
          $files = Get-ChildItem 'docs/_evidence' -Filter 'BuildResult-*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
          if (-not $files) { Write-Error "[ci-docs] ❌ No build evidence found."; exit 1 }
          try {
              $null = Get-Content $files.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
              Write-Information "[ci-docs] ✅ $($files.Name) is valid JSON."
          } catch {
              Write-Error "[ci-docs] ❌ Invalid or unreadable build evidence file."
              exit 1
          }
'@

    'verify-signature.yml' = @'
      - name: 🔍 Validate Signature Evidence
        shell: pwsh
        run: |
          Write-Information "[ci-verify] Checking JSON integrity for signature verification..."
          $files = Get-ChildItem 'docs/_evidence' -Filter 'VerifyResult-*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
          if (-not $files) { Write-Error "[ci-verify] ❌ No VerifyResult evidence found."; exit 1 }
          try {
              $null = Get-Content $files.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
              Write-Information "[ci-verify] ✅ $($files.Name) is valid JSON."
          } catch {
              Write-Error "[ci-verify] ❌ Evidence file invalid JSON."
              exit 1
          }
'@

    'lint-powershell.yml'  = @'
      - name: 🔍 Validate Analyzer Evidence
        shell: pwsh
        run: |
          Write-Information "[ci-ps] Validating AnalyzerReport JSON..."
          $files = Get-ChildItem 'docs/_evidence' -Filter 'AnalyzerReport-*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
          if (-not $files) { Write-Error "[ci-ps] ❌ AnalyzerReport evidence missing."; exit 1 }
          try {
              $null = Get-Content $files.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
              Write-Information "[ci-ps] ✅ $($files.Name) passed JSON verification."
          } catch {
              Write-Error "[ci-ps] ❌ Invalid AnalyzerReport JSON format."
              exit 1
          }
'@

    'lint-markdown.yml'    = @'
      - name: 🔍 Validate JSON Evidence
        shell: pwsh
        run: |
          Write-Information "[ci-md] Verifying JSON evidence integrity..."
          $files = Get-ChildItem 'docs/_evidence' -Filter 'MarkdownReport-*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
          if (-not $files) { Write-Error "[ci-md] ❌ No JSON evidence found."; exit 1 }
          try {
              $null = Get-Content $files.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
              Write-Information "[ci-md] ✅ $($files.Name) is valid JSON."
          } catch {
              Write-Error "[ci-md] ❌ Invalid JSON format in $($files.Name)."
              exit 1
          }
'@

    'build-readme.yml'     = @'
      - name: 🔍 Validate README Build Evidence
        shell: pwsh
        run: |
          Write-Information "[ci-readme] Verifying JSON evidence integrity..."
          $files = Get-ChildItem 'docs/_evidence' -Filter 'ReadmeBuild-*.json' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
          if (-not $files) { Write-Error "[ci-readme] ❌ README build evidence missing."; exit 1 }
          try {
              $null = Get-Content $files.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
              Write-Information "[ci-readme] ✅ $($files.Name) is valid JSON."
          } catch {
              Write-Error "[ci-readme] ❌ Invalid or malformed README evidence file."
              exit 1
          }
'@
}

$patched = @()

foreach ($file in $patches.Keys) {
    $path = Join-Path $workflowDir $file
    if (-not (Test-Path $path)) { Write-Warning "[skip] $file not found."; continue }

    Copy-Item $path (Join-Path $backupsDir "$file.bak") -Force
    Write-Information "[patch] Backed up $file."

    $content = Get-Content -Raw -Path $path -Encoding UTF8

    if ($content -match 'Validate (JSON|Analyzer|Signature|Build) Evidence') {
        Write-Information "[skip] $file already patched."
        continue
    }

    $updated = $content.TrimEnd() + "`n" + $patches[$file]
    Set-Content -Path $path -Value $updated -Encoding UTF8
    Write-Information "[patch] Added validation block to $file."
    $patched += $file
}

if ($patched.Count -gt 0) {
    git add $workflowDir
    git commit -m "🔍 Add JSON evidence validation (v1.2 compliance)"
    git push origin main
    Write-Information "[patch] ✅ Patched and committed $($patched.Count) workflow(s): $($patched -join ', ')"
}
else {
    Write-Information "[patch] No workflows required changes."
}

Write-Information "[patch] Completed."

