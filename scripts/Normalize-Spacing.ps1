<#
.SYNOPSIS
    Normalizes spacing around '=' and optionally aligns visible columns lint-safe.

.DESCRIPTION
    Used in pre-commit hooks and CI jobs to ensure consistent, PSScriptAnalyzer-compliant spacing.

.PARAMETER Path
    File or directory to format.

.PARAMETER CommentAlign
    Adds comment-column alignment (ignored by lint).

.PARAMETER TagNoQA
    Adds '# noqa: spacing' marker to preserve manual alignment.

.EXAMPLE
    pwsh scripts/Normalize-Spacing.ps1 -Path scripts
#>

param(
    [Parameter(Mandatory)]
    [string]$Path,
    [switch]$CommentAlign,
    [switch]$TagNoQA
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Fix-File {
    param($File)
    $lines = Get-Content $File -Encoding UTF8
    $output, $block = @(), @()

    function Flush-Block {
        if (-not $CommentAlign) { $output += $block; $block = @(); return }
        $maxLen = ($block | ForEach-Object {
                if ($_ -match '^\s*([^=\s]+)\s*=') { $matches[1].Length } else { 0 }
            } | Measure-Object -Maximum).Maximum

        foreach ($line in $block) {
            if ($line -match '^\s*([^=\s]+)\s*=\s*(.*)$') {
                $var = $matches[1]; $val = $matches[2]
                $pad = ' ' * ($maxLen - $var.Length + 1)
                $newline = "$var$pad= $val"
                if ($TagNoQA) { $newline += "  # noqa: spacing" }
                $output += $newline
            } else { $output += $line }
        }
        $block = @()
    }

    foreach ($line in $lines) {
        if ($line -match '^\s*[^#].*=\s*' -and $line -notmatch '(==|!=|-eq|\+=|-=|/=\*|>=|<=)') {
            $fixed = [regex]::Replace($line, '\s*=\s*(?![=])', ' = ')
            $block += $fixed
        } else {
            if ($block.Count -gt 0) { Flush-Block }
            $output += $line
        }
    }
    if ($block.Count -gt 0) { Flush-Block }

    $new = $output -join "`n"
    if (($lines -join "`n") -ne $new) {
        $new | Set-Content -Path $File -Encoding UTF8
        Write-Host "✅ Normalized: $File"
    }
}

if (Test-Path $Path -PathType Container) {
    Get-ChildItem $Path -Recurse -Include *.ps1 | ForEach-Object { Fix-File $_.FullName }
} elseif (Test-Path $Path -PathType Leaf) {
    Fix-File $Path
} else {
    Write-Error "Path not found: $Path"
}
