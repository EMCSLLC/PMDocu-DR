<#
.SYNOPSIS
  Builds a Markdown document into a PDF and optionally signs it.

.DESCRIPTION
  Converts a Markdown (.md) file to PDF using pandoc + xelatex
  (Unicode-safe, supports emoji and symbols).
  Can optionally GPG-sign and verify hashes.
  Produces CI-friendly structured output.

.PARAMETER File
  Path to the Markdown source file.

.PARAMETER Out
  Output folder for the PDF (default: "docs/releases").

.PARAMETER Font
  Main font for the PDF (default: "DejaVu Sans").

.PARAMETER Sign
  If specified, runs sign-gpg.ps1 after building the PDF.

.EXAMPLE
  pwsh -NoProfile -File scripts/build-doc.ps1 `
    -File docs/pm/ChangeRequest.md -Sign -Verbose
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$File,
    [string]$Out = "docs/releases",
    [string]$Font = "DejaVu Sans",
    [ValidateSet('tectonic', 'xelatex', 'lualatex')]
    [string]$Engine = 'tectonic',
    [switch]$Sign
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
    $File = (Resolve-Path $File).Path
    if (-not (Test-Path $Out)) {
        New-Item -ItemType Directory -Force -Path $Out | Out-Null
    }

    $Pdf = Join-Path $Out ("{0}.pdf" -f [IO.Path]::GetFileNameWithoutExtension($File))

    Write-Verbose "Building PDF to $Pdf"

    $pandocArgs = @(
        $File,
        "--from=markdown",
        "--to=pdf",
        "--pdf-engine=$Engine",
        "-V", "mainfont=$Font",
        "-V", "geometry:margin=1in",
        "--metadata", "title=$(Split-Path $File -LeafBase)",
        "-o", $Pdf
    )

    $process = Start-Process -FilePath "pandoc" -ArgumentList $pandocArgs `
        -Wait -NoNewWindow -PassThru

    if ($process.ExitCode -ne 0) {
        throw "Pandoc exited with code $($process.ExitCode)"
    }

    if (-not (Test-Path $Pdf)) {
        throw "PDF not found after build: $Pdf"
    }

    Write-Output ("PDF_BUILT={0}" -f $Pdf)

    if ($Sign) {
        $signScript = Join-Path $PSScriptRoot "sign-gpg.ps1"
        if (-not (Test-Path $signScript)) {
            throw "Signing script missing: $signScript"
        }

        Write-Verbose "Signing PDF..."
        & $signScript -InputFile $Pdf
        if ($LASTEXITCODE -ne 0) {
            throw "Signing failed for $Pdf"
        }

        Write-Output ("PDF_SIGNED={0}" -f $Pdf)
    }

    # Future step: hash verification
    # & "$PSScriptRoot/verify-hash.ps1" -InputFile $Pdf -Quiet

    Write-Output "STATUS=SUCCESS"
}
catch {
    Write-Error ("STATUS=FAILURE | MESSAGE={0}" -f $_.Exception.Message)
    exit 1
}

