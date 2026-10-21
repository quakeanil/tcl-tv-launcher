# Launcher swap: FLauncher to a tiny native launcher (plan and build notes)

Status: **adopted.** The native launcher is now Home and FLauncher has been removed, chosen for looks and the Inputs
menu, not for speed (see the measurement just below: no RAM benefit).

## Final setup

| Item | Value |
|---|---|
| Home | `com.gathin.tvhome` (pinned with `cmd package set-home-activity`) |
| Dock (7 slots, `columns` = 7) | YouTube, Netflix, Disney+, TVer, Prime Video, ABEMA, TV (`com.tcl.tv`) |
| Hidden tiles | `com.tcl.settings`, `com.tcl.suspension` (Quick panel: TCL's input switcher, hidden but **not** disabled) |
| Disabled | `com.tcl.browser` (BrowseHere), `com.tcl.t_solo`, `com.tcl.gallery` |
| Removed | FLauncher (`me.efesser.flauncher`) |
| Wi-Fi name on the pill | `pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION` |
| Config | [`launcher/config.xml`](../launcher/config.xml): replaces the upstream `config.xml` before building |
| Wallpaper theme | [`theme/`](../theme): `config.json` plus `wallpaper.jpg` |

### Wallpaper

The TV's only display mode is 1920x1080, so a 4K wallpaper cannot look sharper, and the launcher downsamples to screen
size and decodes at 16-bit (about 4 MB) anyway. A better result comes from scaling the full-size original once:

- Source: Shinjuku Station South Entrance at night by calvision (Pixabay 617590), **CC0**, via Wikimedia Commons.
- Cropped 16:9 from the lower part of the frame, scaled to 1920x1080, dimmed, with darker bands behind the clock and dock.
  JPEG quality 93, about 360 KB. File size does not affect RAM.
- Push to the TV (the launcher reads it from its own external files folder):

```powershell
$dir = '/sdcard/Android/data/com.gathin.tvhome/files'
adb shell mkdir -p $dir
adb push theme\config.json  $dir/config.json
adb push theme\wallpaper.jpg $dir/wallpaper.jpg
adb shell am force-stop com.gathin.tvhome
```

`adb push` into that folder worked on this Android 11 TV, so the upstream base64 helper was not needed.

### Measured: no RAM benefit

| Launcher | Total PSS (`dumpsys meminfo`) |
|---|---|
| `com.gathin.tvhome` (native, 266 KB APK) | 49,833 KB |
| `me.efesser.flauncher` | 49,852 KB |

The original motivation below was based on RSS from `ps`, which includes shared memory and made FLauncher look
like about 190 MB. PSS shows they are the same size, so the swap is a cosmetic choice, not a speed one.

## Why (original reasoning, superseded by the measurement above)

FLauncher (a Flutter app) looked like about 190 MB of RAM on this 2 GB TV. The upstream
[`Gathin23/tv-vibehack`](https://github.com/Gathin23/tv-vibehack) launcher (`com.gathin.tvhome`) is plain Java,
about 266 KB as built, and has no INTERNET permission.

## What other people did (public repos, read only)

| Repo | Approach |
|---|---|
| `Gathin23/tv-vibehack` | A prompt plus ADB tooling: back up, `pm disable-user` the maker's bloat, build and install a small launcher as Home. No prebuilt APK is published. |
| `iamshalabh/Android_TV_Debloater` | The same recipe on a TCL G13 (Android 14): 24 packages plus the stock launcher disabled, custom launcher, restore script. |
| `seun-novodev/android-tv-debloat-toolkit` | Python GUI: debloat TCL/Google apps, install FLauncher, disable the Google launcher. Not actively maintained. |

None of them shortens the Android boot itself. They give a cleaner, lighter home screen.

### Their package lists compared with this TV

| List | Packages | Already disabled here | Still on (at the time) | Not on this TV |
|---|---|---|---|---|
| TCL G13 | 23 + launcher | 7 | 3 | 13 |
| TCL BeyondTV | 12 | 5 | 2 | 5 |

Still on at the time: `com.tcl.partnercustomizer`, `com.tcl.keyhelp`, `com.tcl.tv.tclhome_passive`,
`android.autoinstalls.config.google.gtvpai` (now disabled), `com.google.android.youtube.tvmusic` (now uninstalled).

Packages their lists say to **keep**: `com.tcl.suspension` (quick panel and input switcher),
`com.tcl.useragreement`, `com.tcl.factory.view` (fallback Home), `com.tcl.tv`, `com.tcl.tvinput`.

## Build (done on the PC, not the TV)

Tools, all in their own folders, nothing from the downloaded repo is run except the Gradle build itself:

1. JDK 17: `winget install --id Microsoft.OpenJDK.17 -e`
2. Android command-line tools zip from `dl.google.com` (SHA-256 checked), unpacked to `...\Android\Sdk\cmdline-tools\latest`.
   Then `sdkmanager --sdk_root=<sdk> "platforms;android-34" "build-tools;34.0.0"` after accepting the SDK licences.
   (Piping `y` into `sdkmanager.bat` did not work; redirecting a file of `y` lines with `<` did.)
3. Official Gradle 8.9 from `services.gradle.org`, **SHA-256 checked** against `gradle-8.9-bin.zip.sha256`.
   The repo's own `gradle-wrapper.jar` is also checked (matches Gradle's official hash) but is not used.
4. Clone the repo into a fresh empty folder, then edit
   `launcher/app/src/main/res/values/config.xml` (dock apps, `live_tv_package`, `module_cards`).
5. Write `launcher/local.properties` with `sdk.dir=...`, then:

```powershell
$env:JAVA_HOME = '<jdk-17 folder>'; $env:ANDROID_HOME = '<sdk folder>'
& '<gradle-8.9>\bin\gradle.bat' -p '<clone>\launcher' --no-daemon assembleRelease
```

Output: `launcher/app/build/outputs/apk/release/app-release.apk` (266 KB, signed with the debug key).

### Config used for this TV

| Key | Value |
|---|---|
| Dock | Netflix, Prime Video, YouTube, TVer |
| `live_tv_package` | `com.tcl.tv` |
| `hidden_apps` | `com.tcl.settings` |
| `module_cards` | `false` (no scanning of other apps' card declarations, no prompts) |

### What was reviewed before building

- All Gradle files: only `google()`, `mavenCentral()` and the plugin portal; Android Gradle Plugin 8.5.2;
  `recyclerview`, `dynamicanimation`; JUnit for tests only. No custom tasks, `exec`, `buildSrc` or init scripts.
- Source grep for `Runtime.exec`, `ProcessBuilder`, class loaders, sockets, `URL`, `HttpURLConnection`: nothing.
  The only `startService` call opens the TV's own source-selection panel.
- Built APK (`aapt2 dump badging`): permissions are `ACCESS_NETWORK_STATE`, `ACCESS_WIFI_STATE`,
  `ACCESS_FINE_LOCATION` (only to show the Wi-Fi name). No INTERNET. `minSdk 26`, `targetSdk 34`.
- Build output SHA-256: `acdda765a04d9b561dbc69db59648524bd71bafe4054b4f63cce7a7d8e86b283`.

Not done: a line-by-line audit of all roughly 3,000 lines of Java.

## Install plan (when the TV is free)

1. `adb install -r app-release.apk`. FLauncher stays installed and enabled.
2. Start it once (`am start -n com.gathin.tvhome/.MainActivity`) and check layout, dock and Live TV with a screenshot.
3. Measure RAM: `ps -A -o RSS,NAME | grep tvhome` against FLauncher's about 190 MB.
4. If it is better, make it the default Home. Skip the upstream installer's "disable the stock launcher" step, because
   the Google TV launcher is already disabled here.
5. Rollback is one command: `adb shell pm uninstall --user 0 com.gathin.tvhome`.

## Debloat that was queued

`com.tcl.partnercustomizer`, `com.tcl.tv.tclhome_passive`, `com.tcl.keyhelp`: **done** (disabled while Netflix was playing).

## Gotcha

Installing a second HOME launcher makes Android show a "choose a launcher" chooser on the Home button.
Pin the one you want straight after installing:
`adb shell cmd package set-home-activity me.efesser.flauncher/.MainActivity`

## Local patch: no ambient glow

The upstream launcher tints the screen with a glow taken from the focused app's artwork (red for Netflix, blue for
Disney+). It has no config key to turn that off, so a one-line patch hides the view:
[`launcher/no-ambient.patch`](../launcher/no-ambient.patch) (`ambient.setVisibility(View.GONE)` in `MainActivity.java`).
Apply it to the clone before `assembleRelease`: `git apply launcher/no-ambient.patch`.
