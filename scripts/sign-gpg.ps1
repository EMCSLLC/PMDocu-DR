<#
.SYNOPSIS
  Signs or verifies files using GPG detached signatures.

.DESCRIPTION
  - Default mode: signs TargetFile using GPG detached signature (.asc)
  - Optional -Verify switch: verifies an existing signature
  - Reads default KeyId from defaults/build.conf.yml if -KeyId not supplied
  - Checks for gpg binary and valid keyring
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$TargetFile,
  [string]$KeyId,
  [switch]$Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Pre-flight checks -------------------------------------------------------

if (-not (Get-Command gpg -ErrorAction SilentlyContinue)) {
    throw "GPG not found. Please install Gpg4win or add gpg.exe to PATH."
}

if (-not (Test-Path $TargetFile)) {
    throw "File not found: $TargetFile"
}

# --- Verify Mode -------------------------------------------------------------
if ($Verify) {
    $SigFile = "$TargetFile.asc"
    if (-not (Test-Path $SigFile)) {
        throw "Missing signature file: $SigFile"
    }

    Write-Host "🔍 Verifying signature for: $TargetFile"
    & gpg --verify $SigFile $TargetFile
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Signature verified successfully."
    } else {
        Write-Warning "❌ Signature verification failed or untrusted key."
    }
    return
}

# --- Load default KeyId from config if not provided --------------------------
if (-not $KeyId) {
    $configPath = Join-Path (Split-Path -Parent $PSCommandPath) "../defaults/build.conf.yml"
    if (Test-Path $configPath) {
        $configText = Get-Content $configPath -Raw
        if ($configText -match "keyid:\s*([A-Fa-f0-9]{8,40})") {
            $KeyId = $Matches[1]
            Write-Host "🧩 Using default KeyId from config: $KeyId"
        } else {
            Write-Warning "⚠️ No KeyId found in $configPath. Using first available key."
        }
    } else {
        Write-Warning "⚠️ Config file not found ($configPath). Using first available key."
    }
}

# --- Detect available keys if KeyId missing ----------------------------------
if (-not $KeyId) {
    $keys = gpg --list-secret-keys --keyid-format LONG 2>$null | Select-String -Pattern "sec\s+rsa\d+/\K([A-F0-9]{8,40})"
    if ($keys) {
        $KeyId = $keys.Matches[0].Groups[1].Value
        Write-Host "🧩 Using first detected local key: $KeyId"
    } else {
        throw "No private keys found in GPG keyring. Cannot sign file."
    }
}

# --- Perform signing ---------------------------------------------------------
$OutSig = "$TargetFile.asc"
$cmd = "gpg --batch --yes --armor --detach-sign --local-user $KeyId --output `"$OutSig`" `"$TargetFile`""

Write-Host "🔏 Signing: $TargetFile"
Invoke-Expression $cmd

# --- Validate result ---------------------------------------------------------
if (Test-Path $OutSig) {
    Write-Host "✅ Signature: $OutSig"

    # Auto-verify to ensure correctness
    Write-Host "🔍 Verifying signature..."
    & gpg --verify $OutSig $TargetFile
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Signature verified successfully."
    } else {
        Write-Warning "⚠️ Signature verification failed or untrusted key."
    }
} else {
    Write-Warning "❌ Signature not created."
}

# SIG # Begin signature block
# MIIb3QYJKoZIhvcNAQcCoIIbzjCCG8oCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUwiAZV6BbQVbJHTjIOEs2Mwel
# Z0WgghZKMIIDDDCCAfSgAwIBAgIQWygODpAbH7FEXnXEAhkixDANBgkqhkiG9w0B
# AQsFADAeMRwwGgYDVQQDDBNIeXBlclYtRFIgTG9jYWwgRGV2MB4XDTI1MTAxMjE3
# NDQxNloXDTI2MTAxMjE4MDQxNlowHjEcMBoGA1UEAwwTSHlwZXJWLURSIExvY2Fs
# IERldjCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBANeWzrTEP0aVY8Ae
# bRXyika6Mu099n13IdB8BNKiQ2mK+l9DQNTu6TYO/5I5YBORTra/LuKJOLp5cC4G
# qyw2IBzuOluoc444ww9o4NckY5dxba+o6/sI0JogSbhaLINYbbnYVxb9VeY2w9Gx
# 1050hEPDrGj4HUtXNajS0Gxha+Y2tmV+LGcUInS0TIt/eOKqXT32NOme6kVJCt9V
# ULBSzUkTZDUmM/8n8Ow09z4Sf3RYFRQv5sSG9/F9PC+IOjxCwmluD9Pa9uEYyC3x
# P2S88aXpO7Uzb7hfAxx1cFN+yGEEB/T237fg4ZbdMINFS8zxuD3snWyBOzy5BKdh
# GvCXXDkCAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUF
# BwMDMB0GA1UdDgQWBBRYoFdAdeM5Ns7JIXsLwc5eYxhKujANBgkqhkiG9w0BAQsF
# AAOCAQEAP9ICSl+XqfQmW4BL18FKte+Jt8KZpLt6fpmiYdiqFlnj5cxqZUdTGlBz
# 4mesg+HC9hDPpGlyvg9EaqGF47Xa7gvsPZPXGs+Rkw12oMFm2kCuDlpx30PuWHTy
# CCxS8YmGtviaLFlQP0tBVj6o3cKYQgcE4EJbaBS/PEeAwDjpI63k4/q0XwugaaSU
# 56i+vj+iezXrrvdxXBcG1biLtheFyWEfZZ+3tt6KzNJZmZBWpTNvEQlEgFxPFaTs
# Dd0ZO7SvErtsJzlIgHbCJspxmumqKBdqdAySs2vTcBKVYI8mwITCi+nK/vxIZZWo
# GOo+TtcUa3CO9cLDqxfUo0hEhrguoTCCBY0wggR1oAMCAQICEA6bGI750C3n79tQ
# 4ghAGFowDQYJKoZIhvcNAQEMBQAwZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERp
# Z2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMb
# RGlnaUNlcnQgQXNzdXJlZCBJRCBSb290IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMx
# MTEwOTIzNTk1OVowYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IElu
# YzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQg
# VHJ1c3RlZCBSb290IEc0MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# v+aQc2jeu+RdSjwwIjBpM+zCpyUuySE98orYWcLhKac9WKt2ms2uexuEDcQwH/Mb
# pDgW61bGl20dq7J58soR0uRf1gU8Ug9SH8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlq
# czKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxb
# Grzryc/NrDRAX7F6Zu53yEioZldXn1RYjgwrt0+nMNlW7sp7XeOtyU9e5TXnMcva
# k17cjo+A2raRmECQecN4x7axxLVqGDgDEI3Y1DekLgV9iPWCPhCRcKtVgkEy19sE
# cypukQF8IUzUvK4bA3VdeGbZOjFEmjNAvwjXWkmkwuapoGfdpCe8oU85tRFYF/ck
# XEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDgohIbZpp0yt5LHucOY67m1O+SkjqePdwA
# 5EUlibaaRBkrfsCUtNJhbesz2cXfSwQAzH0clcOP9yGyshG3u3/y1YxwLEFgqrFj
# GESVGnZifvaAsPvoZKYz0YkH4b235kOkGLimdwHhD5QMIR2yVCkliWzlDlJRR3S+
# Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHFynIWIgnffEx1P2PsIV/EIFFrb7GrhotP
# wtZFX50g/KEexcCPorF+CiaZ9eRpL5gdLfXZqbId5RsCAwEAAaOCATowggE2MA8G
# A1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYEFOzX44LScV1kTN8uZz/nupiuHA9PMB8G
# A1UdIwQYMBaAFEXroq/0ksuCMS1Ri6enIZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5
# BggrBgEFBQcBAQRtMGswJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0
# LmNvbTBDBggrBgEFBQcwAoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0Rp
# Z2lDZXJ0QXNzdXJlZElEUm9vdENBLmNydDBFBgNVHR8EPjA8MDqgOKA2hjRodHRw
# Oi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3Js
# MBEGA1UdIAQKMAgwBgYEVR0gADANBgkqhkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhf
# oKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv
# 9P+Aufih9/Jy3iS8UgPITtAq3votVs/59PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZ
# y51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0POz3A8eHqNJMQBk1RmppVLC4oVaO7KTV
# Peix3P0c2PR3WlxUjG/voVA9/HYJaISfb8rbII01YBwCA8sgsKxYoA5AY8WYIsGy
# WfVVa88nq2x2zm8jLfR+cWojayL/ErhULSd+2DrZ8LaHlv1b0VysGMNNn3O3Aamf
# V6peKOK5lDCCBrQwggScoAMCAQICEA3HrFcF/yGZLkBDIgw6SYYwDQYJKoZIhvcN
# AQELBQAwYjELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcG
# A1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3Rl
# ZCBSb290IEc0MB4XDTI1MDUwNzAwMDAwMFoXDTM4MDExNDIzNTk1OVowaTELMAkG
# A1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdp
# Q2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1
# IENBMTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBALR4MdMKmEFyvjxG
# wBysddujRmh0tFEXnU2tjQ2UtZmWgyxU7UNqEY81FzJsQqr5G7A6c+Gh/qm8Xi4a
# PCOo2N8S9SLrC6Kbltqn7SWCWgzbNfiR+2fkHUiljNOqnIVD/gG3SYDEAd4dg2dD
# GpeZGKe+42DFUF0mR/vtLa4+gKPsYfwEu7EEbkC9+0F2w4QJLVSTEG8yAR2CQWIM
# 1iI5PHg62IVwxKSpO0XaF9DPfNBKS7Zazch8NF5vp7eaZ2CVNxpqumzTCNSOxm+S
# AWSuIr21Qomb+zzQWKhxKTVVgtmUPAW35xUUFREmDrMxSNlr/NsJyUXzdtFUUt4a
# S4CEeIY8y9IaaGBpPNXKFifinT7zL2gdFpBP9qh8SdLnEut/GcalNeJQ55IuwnKC
# gs+nrpuQNfVmUB5KlCX3ZA4x5HHKS+rqBvKWxdCyQEEGcbLe1b8Aw4wJkhU1JrPs
# FfxW1gaou30yZ46t4Y9F20HHfIY4/6vHespYMQmUiote8ladjS/nJ0+k6Mvqzfpz
# PDOy5y6gqztiT96Fv/9bH7mQyogxG9QEPHrPV6/7umw052AkyiLA6tQbZl1KhBtT
# asySkuJDpsZGKdlsjg4u70EwgWbVRSX1Wd4+zoFpp4Ra+MlKM2baoD6x0VR4RjSp
# WM8o5a6D8bpfm4CLKczsG7ZrIGNTAgMBAAGjggFdMIIBWTASBgNVHRMBAf8ECDAG
# AQH/AgEAMB0GA1UdDgQWBBTvb1NK6eQGfHrK4pBW9i/USezLTjAfBgNVHSMEGDAW
# gBTs1+OC0nFdZEzfLmc/57qYrhwPTzAOBgNVHQ8BAf8EBAMCAYYwEwYDVR0lBAww
# CgYIKwYBBQUHAwgwdwYIKwYBBQUHAQEEazBpMCQGCCsGAQUFBzABhhhodHRwOi8v
# b2NzcC5kaWdpY2VydC5jb20wQQYIKwYBBQUHMAKGNWh0dHA6Ly9jYWNlcnRzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRSb290RzQuY3J0MEMGA1UdHwQ8MDow
# OKA2oDSGMmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRS
# b290RzQuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkq
# hkiG9w0BAQsFAAOCAgEAF877FoAc/gc9EXZxML2+C8i1NKZ/zdCHxYgaMH9Pw5tc
# BnPw6O6FTGNpoV2V4wzSUGvI9NAzaoQk97frPBtIj+ZLzdp+yXdhOP4hCFATuNT+
# ReOPK0mCefSG+tXqGpYZ3essBS3q8nL2UwM+NMvEuBd/2vmdYxDCvwzJv2sRUoKE
# fJ+nN57mQfQXwcAEGCvRR2qKtntujB71WPYAgwPyWLKu6RnaID/B0ba2H3LUiwDR
# AXx1Neq9ydOal95CHfmTnM4I+ZI2rVQfjXQA1WSjjf4J2a7jLzWGNqNX+DF0SQzH
# U0pTi4dBwp9nEC8EAqoxW6q17r0z0noDjs6+BFo+z7bKSBwZXTRNivYuve3L2oiK
# NqetRHdqfMTCW/NmKLJ9M+MtucVGyOxiDf06VXxyKkOirv6o02OoXN4bFzK0vlNM
# svhlqgF2puE6FndlENSmE+9JGYxOGLS/D284NHNboDGcmWXfwXRy4kbu4QFhOm0x
# JuF2EZAOk5eCkhSxZON3rGlHqhpB/8MluDezooIs8CVnrpHMiD2wL40mm53+/j7t
# FaxYKIqL0Q4ssd8xHZnIn/7GELH3IdvG2XlM9q7WP/UwgOkw/HQtyRN62JK4S1C8
# uw3PdBunvAZapsiI5YKdvlarEvf8EA+8hcpSM9LHJmyrxaFtoza2zNaQ9k+5t1ww
# ggbtMIIE1aADAgECAhAKgO8YS43xBYLRxHanlXRoMA0GCSqGSIb3DQEBCwUAMGkx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4
# RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYg
# MjAyNSBDQTEwHhcNMjUwNjA0MDAwMDAwWhcNMzYwOTAzMjM1OTU5WjBjMQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMTMkRpZ2lD
# ZXJ0IFNIQTI1NiBSU0E0MDk2IFRpbWVzdGFtcCBSZXNwb25kZXIgMjAyNSAxMIIC
# IjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA0EasLRLGntDqrmBWsytXum9R
# /4ZwCgHfyjfMGUIwYzKomd8U1nH7C8Dr0cVMF3BsfAFI54um8+dnxk36+jx0Tb+k
# +87H9WPxNyFPJIDZHhAqlUPt281mHrBbZHqRK71Em3/hCGC5KyyneqiZ7syvFXJ9
# A72wzHpkBaMUNg7MOLxI6E9RaUueHTQKWXymOtRwJXcrcTTPPT2V1D/+cFllESvi
# H8YjoPFvZSjKs3SKO1QNUdFd2adw44wDcKgH+JRJE5Qg0NP3yiSyi5MxgU6cehGH
# r7zou1znOM8odbkqoK+lJ25LCHBSai25CFyD23DZgPfDrJJJK77epTwMP6eKA0kW
# a3osAe8fcpK40uhktzUd/Yk0xUvhDU6lvJukx7jphx40DQt82yepyekl4i0r8OEp
# s/FNO4ahfvAk12hE5FVs9HVVWcO5J4dVmVzix4A77p3awLbr89A90/nWGjXMGn7F
# QhmSlIUDy9Z2hSgctaepZTd0ILIUbWuhKuAeNIeWrzHKYueMJtItnj2Q+aTyLLKL
# M0MheP/9w6CtjuuVHJOVoIJ/DtpJRE7Ce7vMRHoRon4CWIvuiNN1Lk9Y+xZ66laz
# s2kKFSTnnkrT3pXWETTJkhd76CIDBbTRofOsNyEhzZtCGmnQigpFHti58CSmvEyJ
# cAlDVcKacJ+A9/z7eacCAwEAAaOCAZUwggGRMAwGA1UdEwEB/wQCMAAwHQYDVR0O
# BBYEFOQ7/PIx7f391/ORcWMZUEPPYYzoMB8GA1UdIwQYMBaAFO9vU0rp5AZ8esri
# kFb2L9RJ7MtOMA4GA1UdDwEB/wQEAwIHgDAWBgNVHSUBAf8EDDAKBggrBgEFBQcD
# CDCBlQYIKwYBBQUHAQEEgYgwgYUwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRp
# Z2ljZXJ0LmNvbTBdBggrBgEFBQcwAoZRaHR0cDovL2NhY2VydHMuZGlnaWNlcnQu
# Y29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIw
# MjVDQTEuY3J0MF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly9jcmwzLmRpZ2ljZXJ0
# LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQwOTZTSEEyNTYy
# MDI1Q0ExLmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJ
# KoZIhvcNAQELBQADggIBAGUqrfEcJwS5rmBB7NEIRJ5jQHIh+OT2Ik/bNYulCrVv
# hREafBYF0RkP2AGr181o2YWPoSHz9iZEN/FPsLSTwVQWo2H62yGBvg7ouCODwrx6
# ULj6hYKqdT8wv2UV+Kbz/3ImZlJ7YXwBD9R0oU62PtgxOao872bOySCILdBghQ/Z
# LcdC8cbUUO75ZSpbh1oipOhcUT8lD8QAGB9lctZTTOJM3pHfKBAEcxQFoHlt2s9s
# XoxFizTeHihsQyfFg5fxUFEp7W42fNBVN4ueLaceRf9Cq9ec1v5iQMWTFQa0xNqI
# tH3CPFTG7aEQJmmrJTV3Qhtfparz+BW60OiMEgV5GWoBy4RVPRwqxv7Mk0Sy4QHs
# 7v9y69NBqycz0BZwhB9WOfOu/CIJnzkQTwtSSpGGhLdjnQ4eBpjtP+XB3pQCtv4E
# 5UCSDag6+iX8MmB10nfldPF9SVD7weCC3yXZi/uuhqdwkgVxuiMFzGVFwYbQsiGn
# oa9F5AaAyBjFBtXVLcKtapnMG3VH3EmAp/jsJ3FVF3+d1SVDTmjFjLbNFZUWMXuZ
# yvgLfgyPehwJVxwC+UpX2MSey2ueIu9THFVkT+um1vshETaWyQo8gmBto/m3acaP
# 9QsuLj3FNwFlTxq25+T4QwX9xa6ILs84ZPvmpovq90K8eWyG2N01c4IhSOxqt81n
# MYIE/TCCBPkCAQEwMjAeMRwwGgYDVQQDDBNIeXBlclYtRFIgTG9jYWwgRGV2AhBb
# KA4OkBsfsURedcQCGSLEMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKAC
# gAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsx
# DjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBR5MP1ywKulGzEmxLIospVp
# p0xOujANBgkqhkiG9w0BAQEFAASCAQDPQr1Qw5L0QmnLXCbKA5oj2hM9bNo5DOMa
# jEAuHQfv0B3sjK4J8+gIcKva7dSqwpMj8aowUIJlxD+qoBnU85MYgKxc27blsPoY
# mvHuVYGE1SGkj/G0s3EbBsJq228rHdqRx0Np+kFtxA4aw29HtmlUjBVj903hEFWn
# vCiE1I1vNmQlYSr/8wU+6WEa5BrThqR00c2O/5gEtcxQTH+BX+h/HBzTplH+FarR
# fS/a2rYEtx5HROT5sJSYYWRmL+rtvH8zIuD9hH/WZBo5Sux9bslRtDutY5WNilzT
# sDn97ZRxOkPkHX6ZoqGEZbts8tO477KlxLpp9VQqAOPm2yb3KvJooYIDJjCCAyIG
# CSqGSIb3DQEJBjGCAxMwggMPAgEBMH0waTELMAkGA1UEBhMCVVMxFzAVBgNVBAoT
# DkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRp
# bWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMQIQCoDvGEuN8QWC0cR2
# p5V0aDANBglghkgBZQMEAgEFAKBpMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTI1MTAxNTIzMDYwMlowLwYJKoZIhvcNAQkEMSIEIBK1
# dU9OHNqJgZmQ9A1kM2OaCQRwcEqld567VTQ+kgLeMA0GCSqGSIb3DQEBAQUABIIC
# ABEAV+wX1amIH9P89GvOX+LFn0LX99T8GAKRhlzcQGfntw+Ldt+vRwiaI5JQl57o
# YhmZEemZ/JWvfW27QKluEtunhv0jYPpffc8kkcLy2VBWQwhURApTAnGy6qbIjQqw
# 39KZJddm1VdJItXWZ8io2W0m1xXks03CUFtg8FQugWNue29nbbG9ZFwSozDoj5NL
# OZEN4tSI8JbM+CTLww1DyHG9tpvugQoHKzz9BJU9U8D02iU1g+U81Yy9o2IoKCqM
# VKV8BGsJc+PNbJa3zeElwS7uePRhoPYyuwVZHQfvJtZXtDJmKhum5xVjnlJWBBss
# uST6aL3Sv7TZd1+5cVo9Y4uw9YlVX6hmqWLYaGt5o4Tz5Q6X1XLwekz1v6IOM7MV
# tPddevtQfy4d2KsCBtHcxGubzgBRG/Po22ErJDPRWaHlFsmspB1fHa1YpCnB9IAV
# LRWvs7CpFeuqF7HF7n/PnLjIsw7oT3+pxJsrrCFM/FP7zPM5FyuaGII2NgtEjwhe
# ALS18QyfxRQemn4bkckceAQrDYV4dZZXoL4bf2CXLXR+pDnpJlH0N3Y6TSBBOTZ3
# V9y3MIhHTw1x1aPQxrIvy9XTCxYsrpCjW0iruAEOwPjdzxx/EuvLfvE37cVVuPzT
# pgR9v7iKnr0R+blzolyRUVFbBVcGaGWn/BVewRaMhFu9
# SIG # End signature block
