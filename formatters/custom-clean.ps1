<#
.SYNOPSIS
  Cleans Markdown files for consistent formatting.

.DESCRIPTION
  Applies normalization rules to Markdown (.md) files:
    • Converts tabs → 4 spaces
    • Removes trailing whitespace
    • Ensures a single final newline
  Supports both single-file and directory operation.
  Recursive processing by default when a folder is given.

.PARAMETER Path
  File or directory to process. If a folder is given,
  all *.md files within (recursively) are included.

.PARAMETER OnlyInclude
  Wildcard patterns of Markdown files or folders to process.
  Examples:
    -OnlyInclude "examples/*"
    -OnlyInclude "*Plan.md","docs/templates/*"

.PARAMETER Exclude
  Wildcard patterns of Markdown files or folders to skip.
  Takes priority over OnlyInclude.
  Examples:
    -Exclude "templates/*"
    -Exclude "*signoff*","*ImplementationPlan.md"

.EXAMPLE
  pwsh formatters/custom-clean.ps1 -Path docs
  Cleans all Markdown files under /docs recursively.

.EXAMPLE
  pwsh formatters/custom-clean.ps1 -Path docs -Exclude "templates/*"
  Cleans all Markdown files except those under /templates/.

.EXAMPLE
  pwsh formatters/custom-clean.ps1 -Path docs -OnlyInclude "examples/*" -Exclude "*Plan.md"
  Cleans only docs/examples/, skipping any *Plan.md file.

#>
# ---------------------------------------------------------
# 🧭 USAGE / WORKFLOW (WF)
# ---------------------------------------------------------
# Local Development:
#   pwsh scripts/run-formatter.ps1 -Source docs
#   pwsh formatters/custom-clean.ps1 -Path docs -Exclude "templates/*"
#
# CI Integration (GitHub Actions):
#   - name: Normalize Markdown
#     run: pwsh formatters/custom-clean.ps1 -Path docs -Exclude "templates/*","signed/*"
#
# Recommended Pre-Commit Hook:
#   pwsh formatters/custom-clean.ps1 -Path . -OnlyInclude "docs/*" -Exclude "docs/signed/*"
#
# ---------------------------------------------------------
# Behavior Summary:
#   • Recursive file discovery
#   • Case-insensitive matching
#   • Exclude > Include (safety-first precedence)
#   • Safe re-runs (idempotent)
# ---------------------------------------------------------

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Path,
    [string[]]$Exclude,
    [string[]]$OnlyInclude
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Format-MarkdownFile($FilePath) {
    Write-Verbose "🧽 Cleaning: $FilePath"
    $content = Get-Content -Raw -Path $FilePath

    # Tabs → 4 spaces
    $content = $content -replace "`t", '    '

    # Trim trailing spaces
    $content = $content -replace '[ \t]+$', ''

    # Ensure single final newline
    if ($content -notmatch "`r?`n$") { $content += "`r`n" }

    Set-Content -Path $FilePath -Value $content -Encoding UTF8
}

function Convert-GlobToRegex($pattern) {
    [regex]::Escape($pattern) -replace '\\\*', '.*'
}

# --- Gather Markdown files ---
if (Test-Path $Path -PathType Container) {
    $files = Get-ChildItem -Path $Path -Recurse -Include *.md -File
}
elseif (Test-Path $Path -PathType Leaf) {
    $files = , (Get-Item $Path)
}
else {
    throw "Path not found: $Path"
}

if (-not $files) {
    Write-Warning "No Markdown files found under '$Path'."
    exit 0
}

# --- Apply OnlyInclude (optional) ---
if ($OnlyInclude) {
    $includePatterns = $OnlyInclude | ForEach-Object { Convert-GlobToRegex $_ }
    $files = $files | Where-Object {
        foreach ($p in $includePatterns) {
            if ($_.FullName -match $p) { return $true }
        }
        return $false
    }
}

# --- Apply Exclude (always overrides include) ---
if ($Exclude) {
    $excludePatterns = $Exclude | ForEach-Object { Convert-GlobToRegex $_ }
    $files = $files | Where-Object {
        foreach ($p in $excludePatterns) {
            if ($_.FullName -match $p) {
                Write-Verbose "⏭ Skipped (excluded): $($_.FullName)"
                return $false
            }
        }
        return $true
    }
}

if (-not $files) {
    Write-Warning "No files matched include/exclude filters."
    exit 0
}

foreach ($f in $files) {
    Format-MarkdownFile $f.FullName
}

Write-Output "✅ Formatting complete. Processed $($files.Count) file(s)."


# SIG # Begin signature block
# MIIcAgYJKoZIhvcNAQcCoIIb8zCCG+8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCSlHU7H93sm1Sk
# KhrJTgtkEOtGQgqVIXTjiG0pTr4fcaCCFkowggMMMIIB9KADAgECAhBfLlcTvzVL
# tEQJ24CGEVGNMA0GCSqGSIb3DQEBCwUAMB4xHDAaBgNVBAMME1BNRG9jdS1EUiBM
# b2NhbCBEZXYwHhcNMjUxMDE3MTkyNDA0WhcNMjYxMDE3MTk0NDA0WjAeMRwwGgYD
# VQQDDBNQTURvY3UtRFIgTG9jYWwgRGV2MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEA6An7WRdj+2d/J4uwidh3vV6ppxy9cGmleY/b57DKZgJmIpNNfXSg
# 4qm9fCwLkXSZMn02GBl7BPncplW3NWuwNyhzdPqxj8r4Si7vM2BhKj1G70XKNOhZ
# vxylx9hVY6uAdjYgW+PwSrcvl88gbXK9fMRJMxbIjrw+dP5J13RxI+wtRDk8FWjA
# XO2+seT2xbXTKnxYCUEBjJ81zX8mmzyyOxE7NZgW4I11a3mdRqVv2v8XzlV0bzsy
# TA5vFITQFmkakZ9eikiV/DTkaX86jrbiy0Ypvr0vrtwtYTtvvdcWZMlDKYymf3Q7
# omaUjEwRjr+cYPNloYznEsmea13JXOroaQIDAQABo0YwRDAOBgNVHQ8BAf8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwHQYDVR0OBBYEFHs7AlVTYTU4wnkg2ig5
# JRhYbRX6MA0GCSqGSIb3DQEBCwUAA4IBAQAWHFNAeHrYA1nz86235XzMwUilXwFt
# Ea4ZEEhObpsS6cqunW1Cr7ZGzRHHNt7mUWl25KZcytep6Bt+u15vhDgk/njZSZ4y
# yMxXHQSJFe2K/XvDDVIes2OvoftF8cf+jg0kDwl1L+yVt4xuco9Nas0I9iTHFCiF
# LNicN0H8E5Okir6Mg2yj0lyK7o9R4l+/+IG+nZEB6KgCDefioEwUqfXewIjG9ZPz
# f6RPs6T24SQGjc25AHAWGsQLtTIfDbM81KdO0rHd6NhFJ1x06hIWI0NhL0FFOifx
# Yk71XE7IgPaxQcwsNaLfuuWVpWIWXr2TYlIPk9GddC0MvrSFDHB9K+2yMIIFjTCC
# BHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQswCQYD
# VQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGln
# aWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3QgQ0Ew
# HhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJVUzEV
# MBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29t
# MSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3yithZ
# wuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1Ifxp4V
# pX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDVySAd
# YyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiODCu3
# T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQjdjU
# N6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/CNda
# SaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCiEhtm
# mnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADMfRyV
# w4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QYuKZ3
# AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXKchYi
# Cd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t9dmp
# sh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU7Nfj
# gtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNt
# yA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcwAYYY
# aHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8vY2Fj
# ZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0MEUG
# A1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2Vy
# dEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqGSIb3
# DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi+Ica
# aVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n096ww
# epqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ87PcD
# x4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9vytsg
# jTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQtJ37Y
# OtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIGtDCCBJygAwIBAgIQDcesVwX/
# IZkuQEMiDDpJhjANBgkqhkiG9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UE
# ChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYD
# VQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwHhcNMjUwNTA3MDAwMDAwWhcN
# MzgwMTE0MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQs
# IEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5n
# IFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAtHgx0wqYQXK+PEbAHKx126NGaHS0URedTa2NDZS1mZaDLFTtQ2oR
# jzUXMmxCqvkbsDpz4aH+qbxeLho8I6jY3xL1IusLopuW2qftJYJaDNs1+JH7Z+Qd
# SKWM06qchUP+AbdJgMQB3h2DZ0Mal5kYp77jYMVQXSZH++0trj6Ao+xh/AS7sQRu
# QL37QXbDhAktVJMQbzIBHYJBYgzWIjk8eDrYhXDEpKk7RdoX0M980EpLtlrNyHw0
# Xm+nt5pnYJU3Gmq6bNMI1I7Gb5IBZK4ivbVCiZv7PNBYqHEpNVWC2ZQ8BbfnFRQV
# ESYOszFI2Wv82wnJRfN20VRS3hpLgIR4hjzL0hpoYGk81coWJ+KdPvMvaB0WkE/2
# qHxJ0ucS638ZxqU14lDnki7CcoKCz6eum5A19WZQHkqUJfdkDjHkccpL6uoG8pbF
# 0LJAQQZxst7VvwDDjAmSFTUms+wV/FbWBqi7fTJnjq3hj0XbQcd8hjj/q8d6ylgx
# CZSKi17yVp2NL+cnT6Toy+rN+nM8M7LnLqCrO2JP3oW//1sfuZDKiDEb1AQ8es9X
# r/u6bDTnYCTKIsDq1BtmXUqEG1NqzJKS4kOmxkYp2WyODi7vQTCBZtVFJfVZ3j7O
# gWmnhFr4yUozZtqgPrHRVHhGNKlYzyjlroPxul+bgIspzOwbtmsgY1MCAwEAAaOC
# AV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYDVR0OBBYEFO9vU0rp5AZ8esri
# kFb2L9RJ7MtOMB8GA1UdIwQYMBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcw
# AoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJv
# b3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwB
# BAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUAA4ICAQAXzvsWgBz+Bz0RdnEw
# vb4LyLU0pn/N0IfFiBowf0/Dm1wGc/Do7oVMY2mhXZXjDNJQa8j00DNqhCT3t+s8
# G0iP5kvN2n7Jd2E4/iEIUBO41P5F448rSYJ59Ib61eoalhnd6ywFLerycvZTAz40
# y8S4F3/a+Z1jEMK/DMm/axFSgoR8n6c3nuZB9BfBwAQYK9FHaoq2e26MHvVY9gCD
# A/JYsq7pGdogP8HRtrYfctSLANEBfHU16r3J05qX3kId+ZOczgj5kjatVB+NdADV
# ZKON/gnZruMvNYY2o1f4MXRJDMdTSlOLh0HCn2cQLwQCqjFbqrXuvTPSegOOzr4E
# Wj7PtspIHBldNE2K9i697cvaiIo2p61Ed2p8xMJb82Yosn0z4y25xUbI7GIN/TpV
# fHIqQ6Ku/qjTY6hc3hsXMrS+U0yy+GWqAXam4ToWd2UQ1KYT70kZjE4YtL8Pbzg0
# c1ugMZyZZd/BdHLiRu7hAWE6bTEm4XYRkA6Tl4KSFLFk43esaUeqGkH/wyW4N7Oi
# gizwJWeukcyIPbAvjSabnf7+Pu0VrFgoiovRDiyx3zEdmcif/sYQsfch28bZeUz2
# rtY/9TCA6TD8dC3JE3rYkrhLULy7Dc90G6e8BlqmyIjlgp2+VqsS9/wQD7yFylIz
# 0scmbKvFoW2jNrbM1pD2T7m3XDCCBu0wggTVoAMCAQICEAqA7xhLjfEFgtHEdqeV
# dGgwDQYJKoZIhvcNAQELBQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lD
# ZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFt
# cGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTAeFw0yNTA2MDQwMDAwMDBaFw0z
# NjA5MDMyMzU5NTlaMGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgU0hBMjU2IFJTQTQwOTYgVGltZXN0YW1w
# IFJlc3BvbmRlciAyMDI1IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoIC
# AQDQRqwtEsae0OquYFazK1e6b1H/hnAKAd/KN8wZQjBjMqiZ3xTWcfsLwOvRxUwX
# cGx8AUjni6bz52fGTfr6PHRNv6T7zsf1Y/E3IU8kgNkeECqVQ+3bzWYesFtkepEr
# vUSbf+EIYLkrLKd6qJnuzK8Vcn0DvbDMemQFoxQ2Dsw4vEjoT1FpS54dNApZfKY6
# 1HAldytxNM89PZXUP/5wWWURK+IfxiOg8W9lKMqzdIo7VA1R0V3Zp3DjjANwqAf4
# lEkTlCDQ0/fKJLKLkzGBTpx6EYevvOi7XOc4zyh1uSqgr6UnbksIcFJqLbkIXIPb
# cNmA98Oskkkrvt6lPAw/p4oDSRZreiwB7x9ykrjS6GS3NR39iTTFS+ENTqW8m6TH
# uOmHHjQNC3zbJ6nJ6SXiLSvw4Smz8U07hqF+8CTXaETkVWz0dVVZw7knh1WZXOLH
# gDvundrAtuvz0D3T+dYaNcwafsVCGZKUhQPL1naFKBy1p6llN3QgshRta6Eq4B40
# h5avMcpi54wm0i2ePZD5pPIssoszQyF4//3DoK2O65Uck5Wggn8O2klETsJ7u8xE
# ehGifgJYi+6I03UuT1j7FnrqVrOzaQoVJOeeStPeldYRNMmSF3voIgMFtNGh86w3
# ISHNm0IaadCKCkUe2LnwJKa8TIlwCUNVwppwn4D3/Pt5pwIDAQABo4IBlTCCAZEw
# DAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQU5Dv88jHt/f3X85FxYxlQQ89hjOgwHwYD
# VR0jBBgwFoAU729TSunkBnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeAMBYG
# A1UdJQEB/wQMMAoGCCsGAQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3Rh
# bXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKgUIZO
# aHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0
# YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYGZ4EM
# AQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsFAAOCAgEAZSqt8RwnBLmuYEHs
# 0QhEnmNAciH45PYiT9s1i6UKtW+FERp8FgXRGQ/YAavXzWjZhY+hIfP2JkQ38U+w
# tJPBVBajYfrbIYG+Dui4I4PCvHpQuPqFgqp1PzC/ZRX4pvP/ciZmUnthfAEP1HSh
# TrY+2DE5qjzvZs7JIIgt0GCFD9ktx0LxxtRQ7vllKluHWiKk6FxRPyUPxAAYH2Vy
# 1lNM4kzekd8oEARzFAWgeW3az2xejEWLNN4eKGxDJ8WDl/FQUSntbjZ80FU3i54t
# px5F/0Kr15zW/mJAxZMVBrTE2oi0fcI8VMbtoRAmaaslNXdCG1+lqvP4FbrQ6IwS
# BXkZagHLhFU9HCrG/syTRLLhAezu/3Lr00GrJzPQFnCEH1Y58678IgmfORBPC1JK
# kYaEt2OdDh4GmO0/5cHelAK2/gTlQJINqDr6JfwyYHXSd+V08X1JUPvB4ILfJdmL
# +66Gp3CSBXG6IwXMZUXBhtCyIaehr0XkBoDIGMUG1dUtwq1qmcwbdUfcSYCn+Own
# cVUXf53VJUNOaMWMts0VlRYxe5nK+At+DI96HAlXHAL5SlfYxJ7La54i71McVWRP
# 66bW+yERNpbJCjyCYG2j+bdpxo/1Cy4uPcU3AWVPGrbn5PhDBf3Froguzzhk++am
# i+r3Qrx5bIbY3TVzgiFI7Gq3zWcxggUOMIIFCgIBATAyMB4xHDAaBgNVBAMME1BN
# RG9jdS1EUiBMb2NhbCBEZXYCEF8uVxO/NUu0RAnbgIYRUY0wDQYJYIZIAWUDBAIB
# BQCggYQwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYK
# KwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG
# 9w0BCQQxIgQg++eNZhiBefkU+aFHoHA//D2NP6S+aQV4LZ+rSW7SghswDQYJKoZI
# hvcNAQEBBQAEggEAkNA9HoCxN8aht9ms8sIZ1xZ2tmuOUxk32/+1RiiGJTo7z08X
# RtzhZrhuzUOYaZY0PosAw+vlfZFcEZT4CkOh8uAjIcQuvDLoNIgduT0jPw7dDwDO
# D18XYPWWsNr5vSmTR4YG+e/py1Mkjf+0bHeQjBVmfy5HMzP5eztzdIx/ZGeLOImj
# hWgFlJ+2lsH98lRFbGaSV+28yICQG2tKUD/XURAe057u5eYdhyOeb4EhjCN+8Igl
# jRs/sAD2Zr8PC3FVL+VxhY2DVzQIHvEcy6EBvtey77s9McnD0tBHZIM96+9rjE/Z
# s5BZqBk79M39KenNQx3j3qeTdxUi5YMFl+hh5qGCAyYwggMiBgkqhkiG9w0BCQYx
# ggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcg
# UlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgwDQYJYIZI
# AWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJ
# BTEPFw0yNTEwMTcxOTM0MDlaMC8GCSqGSIb3DQEJBDEiBCBDqlkIVBzEkwpYcJuu
# +KhcRiSE19evVD5fx4OJAgVpGzANBgkqhkiG9w0BAQEFAASCAgAvqnvgkvrwCrhQ
# qDLP2YR6SdbC8+u4R7umVFFPMDHMTIs0anlYRiFrXNybVqklK56J2R2a0aK9SyY5
# mPwlSqHj4lX/rn5f/k6HBv7mfVZxjrBfYnKRHw7iIQH9UVtc9r4/F3ldgRglacXh
# uH3itp/24/QYTMKvSIq8gQHMLCvIIaBvwOkLsk22zmIhO3/TL9icLYJXXjvzfd1u
# ixjChnO/liBuHD8yqvTWD+G1M3R7pXZ7jKyuh5Qh7cL/ZSZG1uvcUgqFsHVZ5fud
# yi4GKgYiz21I2ZJVZ+jq2qXOKOITZCilUyHRapsW2fFLkDwjaBJSeuH018eXkg8g
# VB3CoZu2kWN69djYxb4+92c2LmkkIJMAZv2LbzOQxPOQMOqf62xrc6MTHpNPv27I
# tYxf2fT9dyBq9Euid6iHApz5E/OINyKkA/2kf3I/Kete9Cw6XUCry56U48ouCixA
# oqwGWuKX1KoBy9w9iTwDpIjMiyHYamScUs5X2sqlIl/hQCHqmgptnFkPSgI8wKyF
# X0ZSvBwgw2Nky15qYXqQL8ymP8lFGuAiEKTgU8yRTBRsoWlT2GlzdD1TrUhyClEd
# tCM5tvD+3knsHZqfEOGjLd2psnVktX7My9Wwsw+nNiFs//fYMT+HVPREYlZAdtmq
# tkKudktLE628rkk7ro7/2wcaSk1W7A==
# SIG # End signature block
