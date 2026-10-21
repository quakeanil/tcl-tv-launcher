# Shared helpers for apply.ps1 / undo.ps1. Dot-sourced, not run directly.

function Resolve-Adb {
    $cmd = Get-Command adb -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $pkg = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages" -Recurse -Filter adb.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($pkg) { return $pkg.FullName }
    throw "adb not found. Install it with: winget install --id Google.PlatformTools -e"
}

function Connect-Tv([string]$Ip) {
    $script:Adb = Resolve-Adb
    $script:Target = "${Ip}:5555"
    & $script:Adb connect $script:Target | Out-Host
    $state = (& $script:Adb devices) -match [regex]::Escape($script:Target)
    if (-not ($state -match 'device$')) {
        throw "TV not authorised. Accept the 'Allow USB debugging?' prompt on the TV (tick 'Always allow') and re-run."
    }
}

function Invoke-Tv { & $script:Adb -s $script:Target shell @args }

# Packages that were disabled with `pm disable-user --user 0` (reversible).
$script:DisabledPackages = @(
    # TCL analytics / promo / retail-demo
    'com.tcl.bi', 'com.tcl.waterfall.overseas', 'com.tcl.overseasappshow',
    'com.tcl.esticker', 'com.tcl.MultiScreenInteraction_TV', 'com.tcl.messagebox',
    'com.tcl.versionUpdateApp', 'com.tcl.guard', 'com.tcl.miracast',
    'com.tcl.externaldevice.update', 'com.tcl.partnercustomizer',
    'com.tcl.tv.tclhome_passive', 'com.tcl.keyhelp',
    'com.tcl.browser', 'com.tcl.t_solo', 'com.tcl.gallery',
    # Google extras
    'com.google.android.play.games', 'com.google.android.videos',
    'com.google.android.feedback', 'com.google.android.tungsten.setupwraith',
    'com.google.android.apps.nbu.smartconnect.tv', 'com.google.android.tts',
    'com.google.android.apps.tv.dreamx', 'com.google.android.tv.remote.service',
    # Voice assistant
    'com.google.android.katniss', 'com.google.android.tv.assistant',
    # Google TV launcher (replaced by com.gathin.tvhome; its remote app buttons are handled by InputKeyService)
    'com.google.android.apps.tv.launcherx',
    # Fuji TV On Demand
    'air.jp.co.fujitv.fodviewer.tv',
    # Silent partner-app installer (config only)
    'android.autoinstalls.config.google.gtvpai'
)

# Removed for user 0 (`pm uninstall --user 0`); restored with `install-existing`.
$script:UninstalledPackages = @(
    'jp.unext.tv.player',                 # U-NEXT
    'jp.happyon.android',                 # Hulu Japan
    'com.dmm.app.androidtv',              # DMM TV
    'com.google.android.youtube.tvmusic'  # YouTube Music (not the main YouTube app)
)

# Still installed, but blocked from running in the background.
$script:BackgroundRestricted = @(
    'tv.abema', 'jp.co.tver.tvapp', 'com.disney.disneyplus',
    'com.netflix.ninja', 'com.amazon.amazonvideo.livingroom'
)
