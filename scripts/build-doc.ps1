<#
.SYNOPSIS
  Converts Markdown → PDF, applies header/footer, and generates SHA256 hash.
  Falls back to text-only PDF if TeX engine not found.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SourceMd,
    [string]$OutDir = "docs/releases",
    [switch]$NoFormat
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $PSCommandPath
$Templates = Join-Path $ScriptDir "../docs/templates"
$Header = Join-Path $Templates "header.md"
$Footer = Join-Path $Templates "footer.md"

if (-not (Test-Path $SourceMd)) { throw "Source file not found: $SourceMd" }
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

if (-not $NoFormat) {
    $formatter = Join-Path $ScriptDir "run-formatter.ps1"
    if (Test-Path $formatter) { & $formatter -Source $SourceMd }
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName() + ".md")
@(
    if (Test-Path $Header) { Get-Content $Header -Raw } else { "" }
    Get-Content $SourceMd -Raw
    if (Test-Path $Footer) { Get-Content $Footer -Raw } else { "" }
) | Set-Content -Encoding UTF8 -Path $temp

$pdfName = (Split-Path $SourceMd -LeafBase) + ".pdf"
$pdfFile = Join-Path $OutDir $pdfName

# --- Detect TeX / PDF engine ---
if (Get-Command xelatex -ErrorAction SilentlyContinue) {
    $engine = 'xelatex'
} elseif (Get-Command wkhtmltopdf -ErrorAction SilentlyContinue) {
    $engine = 'wkhtmltopdf'
} else {
    $engine = $null
}

try {
    if ($engine) {
        Write-Information "📄 Converting $SourceMd → $pdfFile (engine: $engine)" -InformationAction Continue
        pandoc $temp -o $pdfFile --standalone --pdf-engine=$engine --quiet
    } else {
        Write-Warning "⚠️ No TeX or HTML PDF engine found — creating placeholder text PDF."
        $content = "[PMDocu-DR Placeholder PDF — install TeX for full rendering]`n`n" + (Get-Content -Raw $temp)
        Set-Content -Path $pdfFile -Value $content -Encoding UTF8
    }

    if (-not (Test-Path $pdfFile)) { throw "PDF not created: $pdfFile" }

    $hashFile = "$pdfFile.sha256"
    $hash = (Get-FileHash -Algorithm SHA256 $pdfFile).Hash
    $hash | Out-File -Encoding ascii $hashFile

    Write-Information "✅ PDF built: $pdfFile" -InformationAction Continue
    Write-Information "🔐 SHA256  : $hashFile" -InformationAction Continue
}
finally {
    Remove-Item -Path $temp -Force -ErrorAction SilentlyContinue
}
