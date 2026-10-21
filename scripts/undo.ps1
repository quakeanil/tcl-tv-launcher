<#
.SYNOPSIS
  Restore everything apply.ps1 changed on the TCL TV.
.EXAMPLE
  .\undo.ps1 -Ip 192.168.0.40
  .\undo.ps1 -Ip 192.168.0.40 -KeepLauncher   # restore apps but keep the custom launcher installed
#>
param(
    [Parameter(Mandatory)][string]$Ip,
    [switch]$KeepLauncher
)
. "$PSScriptRoot\common.ps1"
Connect-Tv $Ip

# Bring the Google TV launcher back first so there is always a home screen.
Write-Host "Re-enabling Google TV launcher..."
Invoke-Tv pm enable com.google.android.apps.tv.launcherx

foreach ($p in $DisabledPackages) {
    Write-Host "enable $p"
    Invoke-Tv pm enable $p
}

foreach ($p in $UninstalledPackages) {
    Write-Host "restore $p"
    Invoke-Tv cmd package install-existing $p
}

foreach ($p in $BackgroundRestricted + $UninstalledPackages) {
    Write-Host "allow background: $p"
    Invoke-Tv cmd appops set $p RUN_IN_BACKGROUND allow
    Invoke-Tv cmd appops set $p RUN_ANY_IN_BACKGROUND allow
    Invoke-Tv am set-standby-bucket $p active
}

Write-Host "Switching off launcher key service..."
Invoke-Tv "settings put secure enabled_accessibility_services ''"

if (-not $KeepLauncher) {
    Write-Host "Removing custom launcher (com.gathin.tvhome); Google TV home takes over..."
    Invoke-Tv pm uninstall --user 0 com.gathin.tvhome
} else {
    Write-Host "Custom launcher kept. If Home shows a chooser, pin one: cmd package set-home-activity <component>"
}

Write-Host "`nDone. Restart the TV (unplug 30 s) so everything reloads."
Write-Host "Manual items not covered here: Play Store auto-update and Quick Start (see README)."
