# TCL Smart TV: debloat + custom launcher + working remote buttons

![Android TV 11](https://img.shields.io/badge/Android%20TV-11-3DDC84?logo=android&logoColor=white)
![ADB only](https://img.shields.io/badge/ADB-no%20root-blue)
![Reversible](https://img.shields.io/badge/changes-reversible-brightgreen)
![PowerShell](https://img.shields.io/badge/scripts-PowerShell-5391FE?logo=powershell&logoColor=white)
![License: MIT](https://img.shields.io/badge/license-MIT-yellow)

A slow 2 GB TCL "Smart TV" (Android TV 11, Japan market) made usable again, **over ADB, no root, fully reversible**:

- **Debloat:** about 30 TCL and Google packages disabled, 4 unused apps removed, streaming apps kept but quiet in the
  background. More free RAM, far less swapping.
- **Custom launcher:** the Google TV home screen replaced by a tiny native launcher
  ([`Gathin23/tv-vibehack`](https://github.com/Gathin23/tv-vibehack), 266 KB, no INTERNET permission) with a
  seven-slot dock and a night-city wallpaper.
- **Remote control:** the remote's app buttons (Netflix, YouTube, Prime Video, TVer, ABEMA, Hulu and more) normally
  stop working once the Google TV launcher is gone. This repo brings them back and lets you **remap or disable any
  button**. See [Remote control options](#remote-control-options).

**New here?** Read **[docs/how-we-solved-it.md](docs/how-we-solved-it.md)**: the problems we hit (slow TV, dead remote
buttons, volume going up by 2, a service that kept unbinding), how we found each cause and how we fixed it.

> Package names and key codes are for this firmware (`TCL/G03_4K_GB_NF/BeyondTV4:11`, Realtek RTD2851M). Other TCL
> models differ; check `pm list packages` and your own key codes before reusing the lists. Use at your own risk, not
> affiliated with TCL. `scripts/undo.ps1` restores everything.

## Remote control options

The launcher ships an accessibility service (`InputKeyService`) that sees the remote's keys before the TV's own
handler. In `launcher/config.xml` you can:

| Option | What it does |
|---|---|
| `app_keys` | Map a keycode to an app: `4062:com.netflix.ninja`. Names work too: `KEYCODE_TCL_NETFLIX:...` |
| Remap a button | Point any key at any app, e.g. the Hulu button opens Disney+ and the TCL button opens live TV |
| Disable a button | Map the key to a package that does not exist (`4133:none.unused`); the key is swallowed |
| `input_key_keycodes` | Extra buttons that open the input (HDMI) switcher |
| `settings_key_keycodes` | Buttons that open Settings (needs `HomeKeyService`) |

Find a button's keycode by pressing it while watching `adb logcat` for
`TclPhoneWindowManager: handleKeyBeforeDispatching, key = N`. The full story, the table of codes for this remote and
the pitfalls are in **[docs/remote-app-buttons.md](docs/remote-app-buttons.md)**. The launcher build and wallpaper are
in [docs/launcher-swap.md](docs/launcher-swap.md).

## Quick start

Full walkthrough, including the settings to change on the TV itself: **[docs/settings-guide.md](docs/settings-guide.md)**.

```powershell
winget install --id Google.PlatformTools -e
adb connect <TV-IP>:5555                      # after enabling USB debugging on the TV, see below
.\scripts\apply.ps1 -Ip <TV-IP> -LauncherApk .\app-release.apk   # build the APK first: docs/launcher-swap.md
.\scripts\undo.ps1  -Ip <TV-IP>               # restore everything
```

## Credits and license

- Launcher: [`Gathin23/tv-vibehack`](https://github.com/Gathin23/tv-vibehack) (MIT). This repo holds our config,
  patch and notes, not the launcher source.
- Wallpaper: Shinjuku Station South Entrance at night by calvision (Pixabay 617590), CC0.
- Everything else here: MIT, see [LICENSE](LICENSE).

---

## Details: the speed-up notes

## The TV

| | |
|---|---|
| Brand / model string | TCL / `Smart TV` (generic) |
| Device codename | `BeyondTV4` |
| SoC | Realtek RTD2851M (`rtd288o`), ARMv7, 4 cores |
| RAM | **2 GB** (about 110 MB free at the start) |
| OS | Android TV 11, build `RP1A.200622.001`, security patch 2022-06-05 |
| Market | Japan (TVer, U-NEXT, ABEMA, FOD, Hulu Japan, DMM TV preinstalled) |

The Settings > About page only says "Smart TV", so the real model came from
`adb shell getprop ro.product.*`.

## What was wrong

- Load average sat at **25-30** even when idle (a healthy TV is 1-4). The CPU was about 74% idle, so this
  was memory pressure, not CPU: roughly 110 MB free and **410 MB in swap**.
- The Google TV launcher (about 290 MB over two processes) auto-played video banners and pulled
  recommendation rows from the preinstalled streaming apps on every start.
- The Play Store used about 190 MB and ran app updates in the background after boot.
- Many TCL services (analytics, promo, retail demo, update checker, cast, antivirus-style "guard")
  and several Google extras were running that the owner never uses.

## Setting up ADB

1. On the TV: Settings > System > About, select **Android TV OS build** 7 times ("You are now a developer").
2. Settings > System > Developer options > turn on **USB debugging**.
3. Find the TV's IP (Settings > Network & Internet, or scan port 5555 on your LAN).
4. On the PC: `winget install --id Google.PlatformTools -e`, then `adb connect <TV-IP>:5555`.
5. Accept **Allow USB debugging?** on the TV (tick *Always allow*).

## What was changed

### Disabled (`pm disable-user --user 0 <pkg>`, reversible)

| Group | Packages |
|---|---|
| TCL analytics / promo / demo | `com.tcl.bi`, `com.tcl.waterfall.overseas`, `com.tcl.overseasappshow`, `com.tcl.esticker`, `com.tcl.MultiScreenInteraction_TV`, `com.tcl.messagebox` |
| TCL utilities | `com.tcl.versionUpdateApp` (firmware checker, disabled after confirming the TV was up to date), `com.tcl.guard`, `com.tcl.miracast`, `com.tcl.externaldevice.update` |
| Google extras | `com.google.android.play.games`, `.videos`, `.feedback`, `.tungsten.setupwraith` (setup wizard), `.apps.nbu.smartconnect.tv`, `.tts`, `.apps.tv.dreamx` (screensaver), `.tv.remote.service` |
| Voice assistant | `com.google.android.katniss`, `com.google.android.tv.assistant` (the remote's mic button no longer works) |
| Google TV launcher | `com.google.android.apps.tv.launcherx` (replaced by FLauncher) |
| Fuji TV On Demand | `air.jp.co.fujitv.fodviewer.tv` |
| Silent partner-app installer | `android.autoinstalls.config.google.gtvpai` (config only, frees no RAM) |

### Uninstalled for the current user (`pm uninstall --user 0`; restore with `cmd package install-existing`)

U-NEXT (`jp.unext.tv.player`), Hulu Japan (`jp.happyon.android`), DMM TV (`com.dmm.app.androidtv`),
YouTube Music (`com.google.android.youtube.tvmusic`; the main YouTube app is untouched).

### Kept, but blocked from background activity

ABEMA, TVer, Disney+, Netflix, Prime Video. They still open normally when clicked.

```
cmd appops set <pkg> RUN_IN_BACKGROUND ignore
cmd appops set <pkg> RUN_ANY_IN_BACKGROUND ignore
am set-standby-bucket <pkg> restricted
am force-stop <pkg>
```

### New launcher

The Google TV home was replaced in two steps. First [FLauncher](https://gitlab.com/flauncher/flauncher) 0.18.0
(open source, plain app grid, installed from the official GitLab release). Later it was replaced by the
`com.gathin.tvhome` launcher from [`Gathin23/tv-vibehack`](https://github.com/Gathin23/tv-vibehack), built locally
(266 KB, no INTERNET permission) with a seven-slot dock and a Tokyo night wallpaper. Both use the same RAM (about
50 MB PSS), so the change was for looks. FLauncher has been removed. Details, config, build steps and the wallpaper
recipe: [docs/launcher-swap.md](docs/launcher-swap.md).

### Remote app buttons

The remote's Netflix / YouTube / Prime Video / TVer / Disney+ / Hulu buttons only worked while the Google TV
launcher (`launcherx`) was enabled: `TclPhoneWindowManager` turns them into broadcasts that it answers. With it
disabled only ABEMA's button still worked, and enabling it brought its own Home screen back (Home key ignores our
launcher while it is on). Fix: the launcher's `InputKeyService` (accessibility service) catches the keycodes and
starts the app, using `app_keys` in [`launcher/config.xml`](launcher/config.xml). Keycodes on this remote:
Netflix 4062, YouTube 4065, Prime Video 4099, TVer 4161, ABEMA 4134, Disney+ 4141, Hulu 4066 (mapped to Disney+,
Hulu is uninstalled). The launcher APK first installed here predated `app_keys`, so it had to be rebuilt from
current upstream (the ambient patch was re-applied by hand, see `no-ambient.patch`). Enable the service:

```powershell
adb shell "settings put secure enabled_accessibility_services ''; sleep 1; settings put secure enabled_accessibility_services com.gathin.tvhome/com.gathin.tvhome.InputKeyService; settings put secure accessibility_enabled 1"
```

Android switches the service off when the launcher is force-stopped or reinstalled; run the line again (the
clear-then-set is needed to make it bind). `adb shell input keyevent` skips accessibility filters, so test with
the real remote. Full write-up: [docs/remote-app-buttons.md](docs/remote-app-buttons.md).

### Done on the TV itself

- Play Store > Settings > Auto-update apps > **Don't auto-update**.
- Settings > Power & Energy > **Quick Start: on** (standby is a light sleep, so wake-up takes seconds).
- Sleep timer and Auto standby left off.

## Results

All numbers are from `/proc/meminfo` and `uptime` over ADB. Values wander as the TV runs and are always
worse in the first minute after boot, so treat them as indicative.

| | Start | After changes |
|---|---|---|
| Free RAM | about 110 MB | about 215-260 MB once settled |
| Available RAM | about 440 MB | about 600-650 MB once settled |
| Swap in use | about 410 MB | about 100-140 MB |
| Android boot (`sys.boot_completed`) | not measured | **34 s** (three restarts, same each time) |
| Wake from standby | n/a | a few seconds with Quick Start (uptime kept counting, no reboot) |
| Load average | 25-30 | still about 25 (this number tracks memory pressure, not CPU) |

**While a heavy app is playing** the picture changes: with Netflix on screen it alone used about 420 MB
and swap climbed back to about 410 MB. On 2 GB of RAM that is expected, and no amount of debloating
changes it. What is left running in the background is mostly small (50-125 MB each) and largely
essential (Play Services, system UI, the TCL TV and input services), so further disabling has
diminishing returns.

**Honest read:** the Android boot itself did not get shorter (34 s). The gains are more free memory,
less swapping, a lighter home screen and, most of all, Quick Start, which avoids full boots.
A "before" boot time was never measured, so there is no before/after boot figure.

## Known gaps

- **Power On Behavior** (Settings > Power & Energy) opens an empty screen on this firmware, so starting
  on live TV is not configurable there. It may be caused by disabling the Google TV launcher (untested).
  Workaround: the red **TV** tile is the last slot in the launcher's dock.
- **No document picker:** this TV has none (only `DocumentsStub`), which is why FLauncher's *Pick image* found
  nothing. The new launcher avoids this: its wallpaper is a file pushed over ADB (see docs/launcher-swap.md).
- **U-NEXT boot receivers** cannot be disabled from the ADB shell
  (`Shell cannot change component state`), and the app was removed instead.
- After the final restart, `tv.abema` (about 148 MB) and Prime Video (about 126 MB) were running even
  with background restriction applied, so they appear to start at boot. Not resolved.
- `com.tcl.guard` is a persistent system app. Its process only stops after the next reboot.
- Firmware updates are blocked while `com.tcl.versionUpdateApp` is disabled. Re-enable it to check for updates.
- **Launcher RAM:** an earlier note called FLauncher heavy (about 190 MB). That was RSS, which includes shared
  memory. Measured as PSS, FLauncher is about 49.9 MB and the 266 KB native launcher is about 49.8 MB, so
  swapping saves nothing. See [docs/launcher-swap.md](docs/launcher-swap.md).
- **Per-process numbers in this file are RSS** unless stated, and overstate real use. Trust the system-wide
  figures (free, available, swap), which are what the before/after table reports.
- `com.tcl.partnercustomizer`, `com.tcl.tv.tclhome_passive` and `com.tcl.keyhelp` were disabled while Netflix was playing.

## Scripts

PowerShell; needs `adb` (the script finds it on `PATH` or in the WinGet package folder).

```powershell
.\scripts\apply.ps1 -Ip 192.168.0.40 [-LauncherApk .\app-release.apk]
.\scripts\undo.ps1  -Ip 192.168.0.40 [-KeepLauncher]
```

`apply.ps1` will not disable the Google TV launcher unless the custom launcher (`com.gathin.tvhome`) is installed,
so the TV always keeps a home screen. The APK is not in this repo; build it as described in
[docs/launcher-swap.md](docs/launcher-swap.md). `undo.ps1` re-enables the Google TV launcher first and then restores everything else.
Restart the TV after either script. Replace the example IP with your TV's.

## Caveats

- Disabled system packages come back after a factory reset; re-run `apply.ps1`.
- These package names are for this firmware (`TCL/G03_4K_GB_NF/BeyondTV4:11`). Other TCL models differ,
  so check `pm list packages` before reusing the lists.
- Don't disable `com.google.android.gms`, `com.tcl.tv`, `com.tcl.tvinput`, `com.android.systemui`, the
  settings apps or the launcher/input services. These are needed for live TV, input and remote.
