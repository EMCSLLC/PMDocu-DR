<#
.SYNOPSIS
  Runs the configured Markdown formatter for PMDocu-DR.

.DESCRIPTION
  Detects and invokes the selected Markdown formatter (custom or default)
  to normalize Markdown files across the repository.

  Produces both human-readable log output (via Write-Information)
  and structured result objects (via Write-Output).

.PARAMETER Source
  Root directory or file to format. Defaults to "docs".

.PARAMETER Exclude
  Wildcard patterns for files/folders to skip.

.PARAMETER OnlyInclude
  Wildcard patterns for files/folders to include.

.PARAMETER FormatterName
  Formatter script name (without extension). Defaults to "format-markdown".

.EXAMPLE
  pwsh scripts/run-formatter.ps1 -Source docs

.EXAMPLE
  pwsh scripts/run-formatter.ps1 -Source docs -Exclude "templates/*"

.EXAMPLE
  pwsh scripts/run-formatter.ps1 -Source docs -OnlyInclude "examples/*" -Exclude "*Plan.md"
#>
# ---------------------------------------------------------
# 🧭 WORKFLOW (WF)
# ---------------------------------------------------------
# Local:
#   pwsh scripts/run-formatter.ps1 -Source docs
#
# CI (GitHub Actions):
#   - name: Run Markdown Formatter
#     run: pwsh scripts/run-formatter.ps1 -Source docs -Exclude "templates/*" `
#          -InformationAction Continue | Tee-Object -FilePath "formatter.log"
#
# ---------------------------------------------------------

[CmdletBinding()]
param(
    [string]$Source = "docs",
    [string[]]$Exclude,
    [string[]]$OnlyInclude,
    [string]$FormatterName = "format-markdown"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Locate formatter ---------------------------------------------------------
$formatterPath = Join-Path -Path (Join-Path $PSScriptRoot "..\formatters") -ChildPath "$FormatterName.ps1"
if (-not (Test-Path $formatterPath)) {
    throw "Formatter not found: $formatterPath"
}

Write-Information "🧹 Running formatter '$FormatterName' on '$Source'"

# --- Execute formatter --------------------------------------------------------
$invokeParams = @{
    Path = $Source
}
if ($Exclude) { $invokeParams.Exclude = $Exclude }
if ($OnlyInclude) { $invokeParams.OnlyInclude = $OnlyInclude }

$results = & $formatterPath @invokeParams -InformationAction Continue

if (-not $results) {
    Write-Warning "No files were processed."
    return
}

Write-Information "✅ Formatter completed successfully."
Write-Information "📊 Processed $($results.Count) file(s)."

# --- Emit structured summary --------------------------------------------------
$summary = [PSCustomObject]@{
    Formatter = $FormatterName
    SourcePath = (Resolve-Path $Source).Path
    Processed = $results.Count
    Timestamp = (Get-Date -Format 's')
    Results = $results
}

$summary | Write-Output

# SIG # Begin signature block
# MIIcAgYJKoZIhvcNAQcCoIIb8zCCG+8CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAJGzWllGGn7LPa
# OXKTcKFFQsfVMIXA0gwu6UGbv5g9gaCCFkowggMMMIIB9KADAgECAhBfLlcTvzVL
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
# 9w0BCQQxIgQgJQT5BYQr+Oj/1uYEisXM54QaAwgsf+pFCd/3PDHumogwDQYJKoZI
# hvcNAQEBBQAEggEAfGUcrR2qgW3o83BCc50BRe88qyY66rLWmn130woDfpjCCfp3
# NVXkSH4GO7td8lBiw6dZgzpHgL6WeMh4n/7YdPtO1m0o7gxK2P93eL307Fvl7716
# WKEtrukMoakI3PW6xsKZB+UADorSMyC8mJ02B2d/ul99YOX3zS/3Gz6vffCEBlTh
# oaXUKOsPmYfxA4+b3Zc0cspeQfaR8lE6xbUlwE3G//F1Eq/UhKNdQeOVjMGm+sTp
# 5yji+qc+kfy4JTCRGeaZR8nW2fe1VxXBsTdrUfnvdqo6mHy5SUAoxVg7p1exbvIC
# a1AhWt7XIWHfCamCZjy13woNMEdOD5OnjW1JyaGCAyYwggMiBgkqhkiG9w0BCQYx
# ggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwg
# SW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcg
# UlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgwDQYJYIZI
# AWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3DQEJ
# BTEPFw0yNTEwMTcxOTM0MTBaMC8GCSqGSIb3DQEJBDEiBCAlktHXkwdlyU9AtVrD
# voWFWU+1jELIh/fgiv1rDZIjxzANBgkqhkiG9w0BAQEFAASCAgCcbVbbFXJlecVc
# rHkDjvyOsj9iSxuPBMEL21A40lIj/tW5qy/AcPfIt6qC6IoDz3lLzm4MrJdQvkmc
# PfX01fQ5yD85WElzpazyNqNaDzepl7JU2BTS6F33RhSp1TkUyhg2SqOoFfn88to8
# RR6CFh7OgvGDb8a0h486xNZyEbczhhEriA1ntpvfAFVooYagDkBMbdkXwCg3ps33
# 2tqCyXq/pdin+p+G238fPl2YwKDH5AOrjkZ7wx1c4rDkBL//AEITacs/XEXrGu9r
# pvNtXyEBzneql1AzL+WzaIXXSiarRLjaOWC3k8GtuRH4aEatMAHPJXfwgNJvxP9S
# BdSfK6Od9vpcK6jYKAAeRlOGfUY4jPbfahh73LDVTd7UQeCyYQ27TJ67xbGFV9s+
# lXgfmECNINcUgR6pjcm3lDU3AcLroLU0wCEjIMC8vo/+NjAEHuRJpdbCGlbTdv9z
# T3zhOF8sOX0COkGdFDNs9bvcFFRpZjyifMw67I7LYYV5vJPp6AygE60lpGKgtW68
# A1NmlwSGAJwfqiG3p94d5g98fhqfoURypeLjpLVwenBHwhb9xasXeQLregpcNHq4
# KE4PEF46NUtBS/N/L5fHh4SKp+zGT49Ai1fAyafgGPDlQ29vlyOuO0xVL2Yb0gWN
# 40bs0SlKz4sgWVPeYLWQ8oKDr5Bmrg==
# SIG # End signature block
