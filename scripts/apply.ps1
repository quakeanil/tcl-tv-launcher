<#
.SYNOPSIS
  Re-apply the speed tweaks to the TCL TV (useful after a factory reset).
  Installs nothing except the custom launcher, and only when -LauncherApk is given
  (see docs/launcher-swap.md for how it is built).
.EXAMPLE
  .\apply.ps1 -Ip 192.168.0.40
  .\apply.ps1 -Ip 192.168.0.40 -LauncherApk .\app-release.apk
#>
param(
    [Parameter(Mandatory)][string]$Ip,
    [string]$LauncherApk
)
. "$PSScriptRoot\common.ps1"
Connect-Tv $Ip

# 1. Launcher first, so there is always a working home screen.
if ($LauncherApk) {
    Write-Host "Installing custom launcher..."
    & $script:Adb -s $script:Target install -r $LauncherApk
    Invoke-Tv pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION
    Invoke-Tv cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity
}
$hasLauncher = (Invoke-Tv pm list packages com.gathin.tvhome) -match 'tvhome'
if (-not $hasLauncher) {
    Write-Warning "Custom launcher is not installed. Skipping the Google TV launcher disable so the TV keeps a home screen."
    $skip = 'com.google.android.apps.tv.launcherx'
} else { $skip = '' }

# 2. Disable bloat (reversible).
foreach ($p in $DisabledPackages) {
    if ($p -eq $skip) { continue }
    Write-Host "disable $p"
    Invoke-Tv pm disable-user --user 0 $p
}

# 3. Remove preinstalled streaming apps for this user.
foreach ($p in $UninstalledPackages) {
    Write-Host "uninstall $p"
    Invoke-Tv pm uninstall --user 0 $p
}

# 4. Keep remaining streaming apps launchable but quiet in the background.
foreach ($p in $BackgroundRestricted) {
    Write-Host "restrict background: $p"
    Invoke-Tv cmd appops set $p RUN_IN_BACKGROUND ignore
    Invoke-Tv cmd appops set $p RUN_ANY_IN_BACKGROUND ignore
    Invoke-Tv am set-standby-bucket $p restricted
    Invoke-Tv am force-stop $p
}

# 5. Remote app buttons (Netflix, YouTube, ...) need the launcher's key service; see docs/remote-app-buttons.md.
#    Clearing the list first is what makes Android bind the service.
if ($hasLauncher) {
    Write-Host "enable launcher key service"
    Invoke-Tv "settings put secure enabled_accessibility_services ''; sleep 1; settings put secure enabled_accessibility_services com.gathin.tvhome/com.gathin.tvhome.InputKeyService; settings put secure accessibility_enabled 1"
}

Write-Host "`nDone. Restart the TV. Then do the manual steps in the README (Quick Start, Play Store auto-update)."
