<#
.SYNOPSIS
  Fails if Markdown files contain C0 control characters (excluding TAB/LF/CR).

.DESCRIPTION
  Scans tracked Markdown files for control characters in the range U+0000–U+001F,
  excluding TAB (\x09), LF (\x0A), and CR (\x0D). If any are found, prints a concise
  report and exits with code 1. Intended for CI and pre-commit usage.

.EXAMPLE
  pwsh -NoProfile -File scripts/Check-ControlChars.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Patterns to include/exclude
$IncludeGlobs = @('**/*.md')
$ExcludeGlobs = @(
    'docs/releases/**',
    'docs/signed/**',
    'docs/hashes/**',
    '.git/**'
)

function Get-TrackedMarkdownFiles {
    try {
        $git = (Get-Command git -ErrorAction Stop).Source
        $files = & git ls-files -- '**/*.md'
        if ($files) { return $files }
    }
    catch { }

    # Fallback: file system search
    $root = Get-Location
    $all = Get-ChildItem -Path $root -Recurse -File -Filter '*.md' | ForEach-Object { $_.FullName }
    return $all
}

function Test-PathMatchesGlobs {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [string[]] $Globs
    )
    foreach ($g in $Globs) {
        if ([IO.Path]::DirectorySeparatorChar -eq '\\') {
            $pattern = $g -replace '/', '\\'
        }
        else {
            $pattern = $g
        }
        if ($Path -like $pattern -or $Path -like (Join-Path (Get-Location) $pattern)) { return $true }
    }
    return $false
}

$pattern = '[\x00-\x08\x0B-\x0C\x0E-\x1F]'
$offenders = @()

$files = Get-TrackedMarkdownFiles
foreach ($f in $files) {
    $full = (Resolve-Path $f).Path
    if (-not (Test-PathMatchesGlobs -Path $full -Globs $IncludeGlobs)) { continue }
    if (Test-PathMatchesGlobs -Path $full -Globs $ExcludeGlobs) { continue }

    $text = [System.IO.File]::ReadAllText($full, [System.Text.UTF8Encoding]::new($true))
    $matches = [System.Text.RegularExpressions.Regex]::Matches($text, $pattern)
    if ($matches.Count -gt 0) {
        # Compute first few locations (line:col) for context
        $lines = $text -split "`n"
        $indices = @()
        foreach ($m in $matches | Select-Object -First 3) { $indices += $m.Index }
        $contexts = @()
        foreach ($idx in $indices) {
            $acc = 0; $lineNo = 0; $col = 0
            for ($i = 0; $i -lt $lines.Length; $i++) {
                $len = ($lines[$i] + "`n").Length
                if ($acc + $len -gt $idx) { $lineNo = $i + 1; $col = $idx - $acc + 1; break }
                $acc += $len
            }
            $contexts += "line $lineNo, col $col"
        }
        $codes = ($matches | Select-Object -First 3 | ForEach-Object { 'U+' + ([int][char]$_.Value).ToString('X4') }) -join ', '
        $offenders += [pscustomobject]@{
            file    = $full
            count   = $matches.Count
            samples = $codes
            where   = ($contexts -join '; ')
        }
    }
}

if ($offenders.Count -gt 0) {
    Write-Host "❌ Control characters found in Markdown:" -ForegroundColor Red
    foreach ($o in $offenders) {
        Write-Host " - $($o.file) : $($o.count) occurrence(s); samples: $($o.samples); at $($o.where)" -ForegroundColor Red
    }
    Write-Error "C0 control characters detected. Please remove them (or run Build-GovDocs which sanitizes)."
    exit 1
}
else {
    Write-Host "✅ No control characters found in Markdown." -ForegroundColor Green
}
