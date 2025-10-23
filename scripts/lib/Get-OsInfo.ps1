<#
.SYNOPSIS
  Returns normalized operating-system and host information for PMDocu-DR evidence scripts.

.DESCRIPTION
  Detects the current platform in a way that is compatible with both Windows PowerShell 5.1
  and PowerShell 7+.  Avoids assigning to the built-in $IsWindows variable (read-only in PS 7).
  Provides a structured object consumed by scripts such as sign-gpg.ps1 and Build-GovDocs.ps1.

.OUTPUTS
  PSCustomObject with properties:
    OsName, HostName, PsVersion, Platform
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --- Safe platform detection ----------------------------------------------
$PlatformIsWindows = $false
$PlatformIsLinux = $false
$PlatformIsMacOS = $false

try {
  switch -Wildcard ($PSVersionTable.Platform) {
    'Win32NT' { $PlatformIsWindows = $true }
    'Unix' { $PlatformIsLinux = $true }
    'MacOSX' { $PlatformIsMacOS = $true }
    default { }
  }
} catch {
  # Fallback for legacy PS 5.1 that may not expose Platform
  if ($env:OS -like '*Windows*') { $PlatformIsWindows = $true }
}

# --- Determine readable OS name ------------------------------------------
$OsName = if ($env:RUNNER_OS) {
  $env:RUNNER_OS
} elseif ($PlatformIsWindows) {
  'Windows'
} elseif ($PlatformIsLinux) {
  'Linux'
} elseif ($PlatformIsMacOS) {
  'macOS'
} else {
  'Unknown'
}

# --- Safe hostname for cross-platform -------------------------------------
$HostName = if ($env:COMPUTERNAME) {
  $env:COMPUTERNAME
} elseif (Get-Command hostname -ErrorAction SilentlyContinue) {
  (hostname)
} else {
  'UnknownHost'
}

# --- Safe platform property for PS 5.1 -----------------------------------
$PlatformValue = if ($PSVersionTable.ContainsKey('Platform')) {
  $PSVersionTable.Platform
} elseif ($PlatformIsWindows) {
  'Win32NT'
} elseif ($PlatformIsLinux) {
  'Unix'
} elseif ($PlatformIsMacOS) {
  'MacOSX'
} else {
  'Unknown'
}

# --- Build result object --------------------------------------------------
[PSCustomObject]@{
  OsName = $OsName
  HostName = $HostName
  PsVersion = $PSVersionTable.PSVersion.ToString()
  Platform = $PlatformValue
}
