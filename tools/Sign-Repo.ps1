param(
  [string]$BasePath,
  [int]$ChangedHours = 0,
  [switch]$Prompt,
  [string]$Subject = 'CN=HyperV-DR Local Dev',
  [string]$TimestampServer = 'http://timestamp.digicert.com',
  [switch]$ResignDifferentThumbprint,
  [switch]$RequireTimestamp,
  [switch]$IncludePsd1,
  [switch]$PreserveTimestamps,
  [string]$OutDir,
  [switch]$ListOnly 
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

# Default for PreserveTimestamps
if (-not $PSBoundParameters.ContainsKey('PreserveTimestamps')) {
  $PreserveTimestamps = $true
}

function Get-SignatureStatus {
  [CmdletBinding()]
  param([Parameter(Mandatory)][string]$Path)
  try { Get-AuthenticodeSignature -FilePath $Path } catch { $null }
}

function Get-ReSignReason {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$DesiredThumb,
    [switch]$ResignDifferentThumbprint,
    [switch]$RequireTimestamp
  )

  $sig = Get-SignatureStatus -Path $Path
  if (-not $sig)                               { return 'Unreadable' }
  if ($sig.Status -eq 'NotSigned')             { return 'NotSigned' }
  if ($sig.Status -ne 'Valid')                 { return "Invalid($($sig.Status))" }
  if ($ResignDifferentThumbprint -and
      ($sig.SignerCertificate.Thumbprint -ne $DesiredThumb)) { return 'DifferentThumbprint' }
  if ($RequireTimestamp -and -not $sig.TimeStamperCertificate) { return 'MissingTimestamp' }
  return ''  # empty => no action needed
}


function Resolve-RepoRoot {
  # Prefer PSCommandPath, then PSScriptRoot
  $scriptPath = $PSCommandPath
  if ([string]::IsNullOrWhiteSpace($scriptPath) -and $PSScriptRoot) {
    $scriptPath = (Join-Path -Path $PSScriptRoot -ChildPath 'Sign-Repo.ps1')
  }
  if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    throw "Could not resolve script path (PSCommandPath and PSScriptRoot both null)."
  }

  Write-Information ("[resolve] ScriptPath = {0}" -f $scriptPath)

  try {
    $scriptDir = [System.IO.Path]::GetDirectoryName($scriptPath)
    Write-Information ("[resolve] ScriptDir  = {0}" -f $scriptDir)
  } catch {
    throw ("Failed to get directory from '{0}': {1}" -f $scriptPath, $_.Exception.Message)
  }

  $repoRoot = Join-Path -Path $scriptDir -ChildPath '..'
  ([System.IO.Path]::GetFullPath($repoRoot))
}

function Get-OrCreate-CodeSigningCert {
  param([Parameter(Mandatory)][string]$Subject)
  $my='Cert:\CurrentUser\My'; $pub='Cert:\CurrentUser\TrustedPublisher'; $root='Cert:\CurrentUser\Root'
  $cert = Get-ChildItem $my -CodeSigningCert -ErrorAction SilentlyContinue |
          Where-Object { $_.Subject -eq $Subject } |
          Sort-Object NotAfter -Desc | Select-Object -First 1
  if (-not $cert) {
    Write-Information "[cert] Creating self-signed: $Subject"
    $cert = New-SelfSignedCertificate -Type CodeSigningCert -Subject $Subject -CertStoreLocation $my
  } else {
    Write-Information ("[cert] Reusing {0} (exp {1:u})" -f $cert.Thumbprint,$cert.NotAfter)
  }
  $tmp = Join-Path $env:TEMP 'hypervdr.codesign.cer'
  Export-Certificate -Cert $cert -FilePath $tmp | Out-Null
  if (-not (Get-ChildItem $pub -ErrorAction SilentlyContinue | Where-Object Thumbprint -eq $cert.Thumbprint)) {
    Write-Information "[cert] Trust -> TrustedPublisher"
    Import-Certificate -FilePath $tmp -CertStoreLocation $pub | Out-Null
  }
  if (-not (Get-ChildItem $root -ErrorAction SilentlyContinue | Where-Object Thumbprint -eq $cert.Thumbprint)) {
    Write-Information "[cert] Trust -> Root"
    Import-Certificate -FilePath $tmp -CertStoreLocation $root | Out-Null
  }
  $cert
}

function Get-CandidateFiles {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory)][string]$BasePath,
    [int]$ChangedHours,
    [switch]$IncludePsd1
  )

  if (-not (Test-Path -LiteralPath $BasePath)) {
    throw "BasePath not found: $BasePath"
  }

  # Build an extension whitelist (case-insensitive)
  $exts = @('PS1','PSM1')
  if ($IncludePsd1) { $exts += 'PSD1' }
  $extSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
  $exts | ForEach-Object { [void]$extSet.Add($_) }

  # Recurse everything, then filter by extension — no -Include / no globs
  $allFiles = Get-ChildItem -Path $BasePath -Recurse -File -Force -ErrorAction SilentlyContinue
  Write-Information ("[debug] total files found: {0}" -f $allFiles.Count)
  
  $files = @($allFiles | Where-Object {
    $ext = $_.Extension
    if ([string]::IsNullOrEmpty($ext)) { return $false }
    $extSet.Contains($ext.TrimStart('.'))
  })
  Write-Information ("[debug] after extension filter: {0}" -f $files.Count)

  # Changed-hours scope (if any)
  if ($ChangedHours -gt 0) {
    $cutoff = (Get-Date).AddHours(-$ChangedHours)
    $recent = @($files | Where-Object { $_.LastWriteTime -ge $cutoff })
    Write-Information ("[debug] after time filter ({0}h): {1}" -f $ChangedHours, $recent.Count)
    if ($recent.Count -gt 0) { $files = $recent }
  }

  # Exclude noise
  $excludePatterns = @('\.git\\','\\docs\\gov\\evidence\\','\.bak-')
  $files = @($files | Where-Object {
    $path = $_.FullName
    $shouldExclude = $false
    foreach ($pattern in $excludePatterns) {
      if ($path -match $pattern) {
        $shouldExclude = $true
        break
      }
    }
    return -not $shouldExclude
  })
  Write-Information ("[debug] after exclusion filter: {0}" -f $files.Count)

  # Optional: debug counts
  Write-Information ("[debug] matched={0}" -f ($files | Measure-Object | Select-Object -ExpandProperty Count))

  @($files | Sort-Object FullName -Unique)
}


function Test-SignatureNeedsUpdate {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$DesiredThumb,
    [switch]$ResignDifferentThumbprint,
    [switch]$RequireTimestamp
  )
  try { $sig = Get-AuthenticodeSignature -FilePath $Path } catch { return $true }
  if     ($sig.Status -eq 'NotSigned') { return $true }
  elseif ($sig.Status -ne 'Valid')     { return $true }
  elseif ($ResignDifferentThumbprint -and ($sig.SignerCertificate.Thumbprint -ne $DesiredThumb)) { return $true }
  elseif ($RequireTimestamp -and -not $sig.TimeStamperCertificate) { return $true }
  else { return $false }
}

function Get-RelativePath {
  param([string]$Base,[string]$Full)
  $b=(Resolve-Path -LiteralPath $Base).Path.TrimEnd('\')
  $f=(Resolve-Path -LiteralPath $Full).Path
  $f.Substring($b.Length).TrimStart('\')
}

# ---- main logic

if (-not $BasePath) {
  $BasePath = Resolve-RepoRoot
}

Write-Information "[scope] BasePath: $BasePath"
Write-Information "[scope] ChangedHours: $ChangedHours (0=all)"
if ($OutDir) { Write-Information "[scope] OutDir: $OutDir" }

$cert = Get-OrCreate-CodeSigningCert -Subject $Subject

$all = @( Get-CandidateFiles -BasePath $BasePath -ChangedHours $ChangedHours -IncludePsd1:$IncludePsd1 )
if ($all.Count -eq 0){ Write-Information "[sign] No candidate files."; return }

# mirror if requested
$targets = @()
if ($OutDir) {
  foreach($f in $all){
    $rel = Get-RelativePath -Base $BasePath -Full $f.FullName
    $dest = Join-Path $OutDir $rel
    New-Item -ItemType Directory -Force -Path (Split-Path -LiteralPath $dest) | Out-Null
    Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
    $targets += (Get-Item -LiteralPath $dest)
  }
  Write-Information ("[mirror] Mirrored {0} file(s) to {1}" -f $targets.Count,$OutDir)
} else {
  $targets = $all
}

# Build a decision table (with reason)
$decisions = foreach ($f in $targets) {
  $reason = Get-ReSignReason -Path $f.FullName -DesiredThumb $cert.Thumbprint `
             -ResignDifferentThumbprint:$ResignDifferentThumbprint -RequireTimestamp:$RequireTimestamp
  [pscustomobject]@{
    Path   = $f.FullName
    Reason = $reason  # empty string means "no action"
  }
}

$toSign = @($decisions | Where-Object { $_.Reason } | ForEach-Object { Get-Item -LiteralPath $_.Path })
Write-Information ("[scope] Candidates: {0} | Will sign: {1}" -f $targets.Count, $toSign.Count)

# List-only preview
if ($ListOnly) {
  if ($toSign.Count -eq 0) {
    Write-Information "[sign] Nothing to do (preview)."
  } else {
    $decisions | Where-Object Reason |
      Sort-Object Reason, Path |
      Format-Table -Auto Path, Reason
  }
  return
}

if ($toSign.Count -eq 0) {
  Write-Information "[sign] Nothing to do."
  return
}


# unblock & sign
Write-Information "[sign] Unblocking..."
foreach($f in $toSign){ try{ Unblock-File -LiteralPath $f.FullName -ErrorAction SilentlyContinue }catch{} }

Write-Information ("[sign] Signing {0} file(s) with {1} ..." -f $toSign.Count,$cert.Thumbprint)
$actuallySigned=@()
foreach($f in $toSign){
  $ts=$null
  if ($PreserveTimestamps -and -not $OutDir){
    $orig = Get-Item -LiteralPath $f.FullName
    $ts = @{
      CreationTime=$orig.CreationTime; CreationTimeUtc=$orig.CreationTimeUtc
      LastWriteTime=$orig.LastWriteTime; LastWriteTimeUtc=$orig.LastWriteTimeUtc
      LastAccessTime=$orig.LastAccessTime; LastAccessTimeUtc=$orig.LastAccessTimeUtc
    }
  }
  try{
    $sig = if ([string]::IsNullOrWhiteSpace($TimestampServer)) {
      Set-AuthenticodeSignature -FilePath $f.FullName -Certificate $cert
    } else {
      Set-AuthenticodeSignature -FilePath $f.FullName -Certificate $cert -TimestampServer $TimestampServer
    }
    if ($ts){
      $fi = Get-Item -LiteralPath $f.FullName
      $fi.CreationTime=$ts.CreationTime; $fi.CreationTimeUtc=$ts.CreationTimeUtc
      $fi.LastWriteTime=$ts.LastWriteTime; $fi.LastWriteTimeUtc=$ts.LastWriteTimeUtc
      $fi.LastAccessTime=$ts.LastAccessTime; $fi.LastAccessTimeUtc=$ts.LastAccessTimeUtc
    }
    $actuallySigned += [pscustomobject]@{ Path=$f.FullName; Status=[string]$sig.Status; Thumbprint=$cert.Thumbprint }
  } catch {
    $actuallySigned += [pscustomobject]@{ Path=$f.FullName; Status='Error'; Thumbprint=$cert.Thumbprint; Message=$_.Exception.Message }
  }
}

$ok = @($actuallySigned | Where-Object { $_.Status -eq 'Valid' }).Count
$err= @($actuallySigned | Where-Object { $_.Status -eq 'Error' }).Count
$oth= $actuallySigned.Count - $ok - $err
Write-Information ("[sign] Completed. Valid:{0} Errors:{1} Other:{2} TotalSigned:{3}" -f $ok,$err,$oth,$actuallySigned.Count)
Write-Information "[sign] Files actually signed:"

$byReason = $decisions | Where-Object Reason | Group-Object Reason | Sort-Object Count -Desc
if ($byReason) {
  Write-Information "[sign] Reasons (signed files):"
  $byReason | Select-Object Count, Name | Format-Table -Auto
}
$actuallySigned | Sort-Object Path | Format-Table -Auto Path, Status, Thumbprint

# SIG # Begin signature block
# MIIdhQYJKoZIhvcNAQcCoIIddjCCHXICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB61tRqUvSW1cWC
# W4FEDZIRuavfeh892NLcNF+2ztd0TKCCF0wwggQOMIICdqADAgECAhAp7QGUFN7X
# oU8j2FBamu6eMA0GCSqGSIb3DQEBCwUAMB8xHTAbBgNVBAMMFEVNQ1NMTEMgQ29k
# ZSBTaWduaW5nMB4XDTI1MTAwMTEyMzAyOVoXDTI3MTAwMTEyNDAyOVowHzEdMBsG
# A1UEAwwURU1DU0xMQyBDb2RlIFNpZ25pbmcwggGiMA0GCSqGSIb3DQEBAQUAA4IB
# jwAwggGKAoIBgQDSNUQBFq15bnTz+TkyJwnpIUalQZ6dHSM0WW1ATtAKU1gbWwVN
# HwlVyD8hF+vRbfAC7Jxf/tcrpWgEJZ8OAAnf+6bJNWQXbpuW5/m4jr1LBdniHGOm
# J75nsU40YDchIlaXj3M6mPx+xNTCy1y6x598d+jjsYhY81GzU+efXN4/YEMKr9w9
# f5zc46tLvEw8XsGICyCiokPG/sIt6dS49VTeKGWjLKX4H63xJP4uHPd9u024CRLG
# 0C6i8jGPO5CMhoq5Ff6+rSWT8OE2F7B7fuAaCxfmJa8eLXrUpbDYmBRlaDmrtMDz
# ZnAwWmoM8Kqhmj63ppPwZAHCtNHPqWURpChU1j6VaW4Y4AErD9qtbp+0OwkeDM90
# RaMksgJwZyUtiHiFMMH3NL9izRzr+wbpnfAHwdeWmMCysKUlXAg5fyqwwRQHpvog
# teAvU9V2cRCDY1s8vQQzTWfG/YDOvWhIDcnndLARcCmEoVJ/zuQdnrgwy81bod9+
# 1KRbwJ6G2JRpDu0CAwEAAaNGMEQwDgYDVR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMB0GA1UdDgQWBBSVAAgwvWdyeDCQsm6g+OkJmMA5pTANBgkqhkiG
# 9w0BAQsFAAOCAYEAKCOQzewAo6GX3rxaElMb3O5SlA1p4435HdtydVc86Nx50xCF
# 8nXPO9LEYj4VN1qwzgz5Ks79g+fE32MIQaLWDlr9Xcdv3ynnSQyfjzax8Ubi7YmT
# Rkhla977jGVys0bOwvsjfoOxTMqczO5lRKBZSHgZYlowE9NUOoWMonmaxwX1fLwH
# Dl/ql0wxNhuQtizDrJmUslDjCO9tGff+sT8GuS4N1NfIj+RK373zESy1BP8H9BNc
# PMh1lFRBljB4RQayXQPTuatCfHk/TZjyj39qrDMt08xj7SsBJrqTQKXBw0qF0l/1
# QIofuflWc0uB6zpA7ZX6mwzqZN8GrWTEu3dcrYFon1VZIC2qu7ByCPB7/f/7x7tS
# ewFsv2dVlqHr0+xi9cDj+DFWZqYW5Hw6YoL6dL7ir7KRWDMeQPdRj1exsdwqvmsa
# KT/DysNpIrTR6E3mmvqcsDzovvUlIAdpvYIcjHw//joRKTg+LfIUEDqsnwSJHI98
# 6XGWSi/YgvdxA9aPMIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkq
# hkiG9w0BAQwFADBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5j
# MRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBB
# c3N1cmVkIElEIFJvb3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5
# WjBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQL
# ExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJv
# b3QgRzQwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1K
# PDAiMGkz7MKnJS7JIT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2r
# snnyyhHS5F/WBTxSD1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C
# 8weE5nQ7bXHiLQwb7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBf
# sXpm7nfISKhmV1efVFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGY
# QJB5w3jHtrHEtWoYOAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8
# rhsDdV14Ztk6MUSaM0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaY
# dj1ZXUJ2h4mXaXpI8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+
# wJS00mFt6zPZxd9LBADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw
# ++hkpjPRiQfhvbfmQ6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+N
# P8m800ERElvlEFDrMcXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7F
# wI+isX4KJpn15GkvmB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUw
# AwEB/zAdBgNVHQ4EFgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAU
# Reuir/SSy4IxLVGLp6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEB
# BG0wazAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsG
# AQUFBzAChjdodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1
# cmVkSURSb290Q0EuY3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAow
# CDAGBgRVHSAAMA0GCSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/
# Vwe9mqyhhyzshV6pGrsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLe
# JLxSA8hO0Cre+i1Wz/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE
# 1Od/6Fmo8L8vC6bp8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9Hda
# XFSMb++hUD38dglohJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbO
# byMt9H5xaiNrIv8SuFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMIIG
# tDCCBJygAwIBAgIQDcesVwX/IZkuQEMiDDpJhjANBgkqhkiG9w0BAQsFADBiMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQw
# HhcNMjUwNTA3MDAwMDAwWhcNMzgwMTE0MjM1OTU5WjBpMQswCQYDVQQGEwJVUzEX
# MBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lDZXJ0IFRydXN0
# ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUgQ0ExMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtHgx0wqYQXK+PEbAHKx126NGaHS0
# URedTa2NDZS1mZaDLFTtQ2oRjzUXMmxCqvkbsDpz4aH+qbxeLho8I6jY3xL1IusL
# opuW2qftJYJaDNs1+JH7Z+QdSKWM06qchUP+AbdJgMQB3h2DZ0Mal5kYp77jYMVQ
# XSZH++0trj6Ao+xh/AS7sQRuQL37QXbDhAktVJMQbzIBHYJBYgzWIjk8eDrYhXDE
# pKk7RdoX0M980EpLtlrNyHw0Xm+nt5pnYJU3Gmq6bNMI1I7Gb5IBZK4ivbVCiZv7
# PNBYqHEpNVWC2ZQ8BbfnFRQVESYOszFI2Wv82wnJRfN20VRS3hpLgIR4hjzL0hpo
# YGk81coWJ+KdPvMvaB0WkE/2qHxJ0ucS638ZxqU14lDnki7CcoKCz6eum5A19WZQ
# HkqUJfdkDjHkccpL6uoG8pbF0LJAQQZxst7VvwDDjAmSFTUms+wV/FbWBqi7fTJn
# jq3hj0XbQcd8hjj/q8d6ylgxCZSKi17yVp2NL+cnT6Toy+rN+nM8M7LnLqCrO2JP
# 3oW//1sfuZDKiDEb1AQ8es9Xr/u6bDTnYCTKIsDq1BtmXUqEG1NqzJKS4kOmxkYp
# 2WyODi7vQTCBZtVFJfVZ3j7OgWmnhFr4yUozZtqgPrHRVHhGNKlYzyjlroPxul+b
# gIspzOwbtmsgY1MCAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYBAf8CAQAwHQYD
# VR0OBBYEFO9vU0rp5AZ8esrikFb2L9RJ7MtOMB8GA1UdIwQYMBaAFOzX44LScV1k
# TN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcD
# CDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2lj
# ZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29t
# L0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4oDagNIYyaHR0
# cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcmww
# IAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqGSIb3DQEBCwUA
# A4ICAQAXzvsWgBz+Bz0RdnEwvb4LyLU0pn/N0IfFiBowf0/Dm1wGc/Do7oVMY2mh
# XZXjDNJQa8j00DNqhCT3t+s8G0iP5kvN2n7Jd2E4/iEIUBO41P5F448rSYJ59Ib6
# 1eoalhnd6ywFLerycvZTAz40y8S4F3/a+Z1jEMK/DMm/axFSgoR8n6c3nuZB9BfB
# wAQYK9FHaoq2e26MHvVY9gCDA/JYsq7pGdogP8HRtrYfctSLANEBfHU16r3J05qX
# 3kId+ZOczgj5kjatVB+NdADVZKON/gnZruMvNYY2o1f4MXRJDMdTSlOLh0HCn2cQ
# LwQCqjFbqrXuvTPSegOOzr4EWj7PtspIHBldNE2K9i697cvaiIo2p61Ed2p8xMJb
# 82Yosn0z4y25xUbI7GIN/TpVfHIqQ6Ku/qjTY6hc3hsXMrS+U0yy+GWqAXam4ToW
# d2UQ1KYT70kZjE4YtL8Pbzg0c1ugMZyZZd/BdHLiRu7hAWE6bTEm4XYRkA6Tl4KS
# FLFk43esaUeqGkH/wyW4N7OigizwJWeukcyIPbAvjSabnf7+Pu0VrFgoiovRDiyx
# 3zEdmcif/sYQsfch28bZeUz2rtY/9TCA6TD8dC3JE3rYkrhLULy7Dc90G6e8Blqm
# yIjlgp2+VqsS9/wQD7yFylIz0scmbKvFoW2jNrbM1pD2T7m3XDCCBu0wggTVoAMC
# AQICEAqA7xhLjfEFgtHEdqeVdGgwDQYJKoZIhvcNAQELBQAwaTELMAkGA1UEBhMC
# VVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhEaWdpQ2VydCBU
# cnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAyMDI1IENBMTAe
# Fw0yNTA2MDQwMDAwMDBaFw0zNjA5MDMyMzU5NTlaMGMxCzAJBgNVBAYTAlVTMRcw
# FQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMyRGlnaUNlcnQgU0hBMjU2
# IFJTQTQwOTYgVGltZXN0YW1wIFJlc3BvbmRlciAyMDI1IDEwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQDQRqwtEsae0OquYFazK1e6b1H/hnAKAd/KN8wZ
# QjBjMqiZ3xTWcfsLwOvRxUwXcGx8AUjni6bz52fGTfr6PHRNv6T7zsf1Y/E3IU8k
# gNkeECqVQ+3bzWYesFtkepErvUSbf+EIYLkrLKd6qJnuzK8Vcn0DvbDMemQFoxQ2
# Dsw4vEjoT1FpS54dNApZfKY61HAldytxNM89PZXUP/5wWWURK+IfxiOg8W9lKMqz
# dIo7VA1R0V3Zp3DjjANwqAf4lEkTlCDQ0/fKJLKLkzGBTpx6EYevvOi7XOc4zyh1
# uSqgr6UnbksIcFJqLbkIXIPbcNmA98Oskkkrvt6lPAw/p4oDSRZreiwB7x9ykrjS
# 6GS3NR39iTTFS+ENTqW8m6THuOmHHjQNC3zbJ6nJ6SXiLSvw4Smz8U07hqF+8CTX
# aETkVWz0dVVZw7knh1WZXOLHgDvundrAtuvz0D3T+dYaNcwafsVCGZKUhQPL1naF
# KBy1p6llN3QgshRta6Eq4B40h5avMcpi54wm0i2ePZD5pPIssoszQyF4//3DoK2O
# 65Uck5Wggn8O2klETsJ7u8xEehGifgJYi+6I03UuT1j7FnrqVrOzaQoVJOeeStPe
# ldYRNMmSF3voIgMFtNGh86w3ISHNm0IaadCKCkUe2LnwJKa8TIlwCUNVwppwn4D3
# /Pt5pwIDAQABo4IBlTCCAZEwDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQU5Dv88jHt
# /f3X85FxYxlQQ89hjOgwHwYDVR0jBBgwFoAU729TSunkBnx6yuKQVvYv1Ensy04w
# DgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMIGVBggrBgEF
# BQcBAQSBiDCBhTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MF0GCCsGAQUFBzAChlFodHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2U0hBMjU2MjAyNUNBMS5jcnQw
# XwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lD
# ZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNIQTI1NjIwMjVDQTEuY3Js
# MCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwHATANBgkqhkiG9w0BAQsF
# AAOCAgEAZSqt8RwnBLmuYEHs0QhEnmNAciH45PYiT9s1i6UKtW+FERp8FgXRGQ/Y
# AavXzWjZhY+hIfP2JkQ38U+wtJPBVBajYfrbIYG+Dui4I4PCvHpQuPqFgqp1PzC/
# ZRX4pvP/ciZmUnthfAEP1HShTrY+2DE5qjzvZs7JIIgt0GCFD9ktx0LxxtRQ7vll
# KluHWiKk6FxRPyUPxAAYH2Vy1lNM4kzekd8oEARzFAWgeW3az2xejEWLNN4eKGxD
# J8WDl/FQUSntbjZ80FU3i54tpx5F/0Kr15zW/mJAxZMVBrTE2oi0fcI8VMbtoRAm
# aaslNXdCG1+lqvP4FbrQ6IwSBXkZagHLhFU9HCrG/syTRLLhAezu/3Lr00GrJzPQ
# FnCEH1Y58678IgmfORBPC1JKkYaEt2OdDh4GmO0/5cHelAK2/gTlQJINqDr6Jfwy
# YHXSd+V08X1JUPvB4ILfJdmL+66Gp3CSBXG6IwXMZUXBhtCyIaehr0XkBoDIGMUG
# 1dUtwq1qmcwbdUfcSYCn+OwncVUXf53VJUNOaMWMts0VlRYxe5nK+At+DI96HAlX
# HAL5SlfYxJ7La54i71McVWRP66bW+yERNpbJCjyCYG2j+bdpxo/1Cy4uPcU3AWVP
# Grbn5PhDBf3Froguzzhk++ami+r3Qrx5bIbY3TVzgiFI7Gq3zWcxggWPMIIFiwIB
# ATAzMB8xHTAbBgNVBAMMFEVNQ1NMTEMgQ29kZSBTaWduaW5nAhAp7QGUFN7XoU8j
# 2FBamu6eMA0GCWCGSAFlAwQCAQUAoIGEMBgGCisGAQQBgjcCAQwxCjAIoAKAAKEC
# gAAwGQYJKoZIhvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwG
# CisGAQQBgjcCARUwLwYJKoZIhvcNAQkEMSIEILHESWq6HVONBgGR7ZLSPeWluKi6
# RZ7yaEiAS+FPezsgMA0GCSqGSIb3DQEBAQUABIIBgD+5rvg+UWb+OwXBgIRz/7Rg
# KMQiHwoi8iXgeel9eIpCcXyGN3iayS3pOZzDgltoODTYM6sJMWym0J3oXZqqibXW
# cSpHObZxIcAFiFH3MGyf9uyh6+DQ3ICBP6rXctgqI6mGQn2znQ3InYuR6a37NyJG
# MNELpaKnS4zOmNBPoFvF+BuD0J1x7NJ8xh0xH9fAOPtt3tPNTgzMTxU1KvmDYgnZ
# IfqFGlqcoDm2/KSMlKwcHgKpxrGO5pik4Ggdib5NN/t9kFyw/GwxF18DkkTUuTE7
# gRMQa7yjT7E5xQzWwE1Av+WTaE/IqcwVuE2y7e0emDpWGJl2m2REXp/6g6OPfENW
# gAW9V67aGhZewhRAHPzQsY/qaDs28YPOMnF8GkXuPj87/hmQWLUCsV948oRsGzoU
# BXlU1lVnnz6qt5EgZWDsXA7u7FXVZkBZB8gAbD4fh17BqyDZVX9IIHdGmVtpnb3Q
# 1uhYfXsS4BGqwWI3XR/ycqNJMF/LXwGq/y7jfuxRWKGCAyYwggMiBgkqhkiG9w0B
# CQYxggMTMIIDDwIBATB9MGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2Vy
# dCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBp
# bmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBDQTECEAqA7xhLjfEFgtHEdqeVdGgwDQYJ
# YIZIAWUDBAIBBQCgaTAYBgkqhkiG9w0BCQMxCwYJKoZIhvcNAQcBMBwGCSqGSIb3
# DQEJBTEPFw0yNTEwMTIyMDU2MjZaMC8GCSqGSIb3DQEJBDEiBCB1fFBXdgTpSs1z
# Zzlq52t10t4YZrPYC1jeHj8srVZPFzANBgkqhkiG9w0BAQEFAASCAgCa17BwMZ8e
# dIqkD4JzTyKaC3B5j5Vwr4NCgqEu3WeDtuHrOTPEZS/VRUEBKQg06wuAo5PtfKKC
# g2TqQPrvrcetgAPWt7Qt63bAAr65reIUz+thBcE2a2j5lKCFPv6ROaGoQB2VPaNc
# n2BPqkrS6pT0tkbu200RDNu5c5BveYyxsT+TWdiTeMwFhDyWB83k1auER3K0J3gV
# m731j4sA3fPE0yA4U1FKHSVrYzgPltlYYUc8HBAFEcz3qnuBs3Rs1WNA5IJd1i6s
# mpCATQnVcEfq6sjg1jV7w/xi1mS4oymuciSHbbb9tWAECNLdiuSX2oA/Z58/vqLJ
# csn+zWD3gca8oCiO3cdzaHlRTh+0MPfxwNJFNHTM9FgNpQwuketECSInkX1AKG1U
# vkULKLpsdwC5Ciihp1Afaz7CGANzyHV8dvMriLAH7shqXYCEF1OeoR3XO9Q3rbE0
# obX6CkZCBrL3YrHRk9Prr+FC8o93HNdOJuDAuhKOXV5S4zwomOuPcoh9kOGvDpY8
# YY9TAFMTIcBb1/uhjYXHgKxmrtG3/qfWWTJjk/SeOaHnljmh27CVlD5igp2as3Sk
# bQfRDVkF5Pzfw81Di2bqL4Jw+UAIMJjF/uPLFjn/6HSrYP039VyE6LS2FMPgbiQC
# 6BjMgJSLQHJKbiK/dH3ctdA6TsntKhBBjQ==
# SIG # End signature block
