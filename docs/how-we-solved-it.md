# How we solved it: the problems and the fixes

The README lists what was changed. This page tells the story behind it: what broke, how we found the cause, and what
fixed it. Everything was done over ADB, with no root, on a TCL `BeyondTV4` (Android TV 11, 2 GB RAM, Japan market).

| # | Problem | Fix |
|---|---|---|
| 1 | The TV was slow and swapping | [Debloat](#1-debloat-free-the-memory) |
| 2 | The Google TV home screen was heavy and noisy | [A tiny custom launcher](#2-replace-the-home-screen) |
| 3 | Remote app buttons died with the stock launcher | [A key service in the launcher](#3-remote-app-buttons) |
| 4 | Which button sends which code? | [Read it from the log](#4-assigning-buttons-find-the-keycode) |
| 5 | The home screen needed a wallpaper | [Pick, crop, push](#5-wallpaper) |
| 6 | Volume went 2, 4, 6, 8 | [Swallow the volume keys](#6-volume-went-up-in-steps-of-2) |
| 7 | The buttons stopped working again | [Allow auto-start](#7-the-buttons-stopped-working-again) |

## 1. Debloat: free the memory

**Symptom.** Load average sat at 25-30 while idle. The CPU was mostly idle, so this was memory pressure: about 110 MB
free and 410 MB in swap.

**Cause.** The Google TV launcher auto-played banners and loaded recommendations, the Play Store updated apps in the
background, and many TCL services (analytics, promo, retail demo, update checker, "guard") ran for nothing.

**Fix.** About 30 TCL and Google packages were disabled with `pm disable-user --user 0 <pkg>`, which is reversible.
Four unused apps were uninstalled for the current user. The streaming apps stayed, but were blocked from running in
the background (`appops ... RUN_IN_BACKGROUND ignore`, restricted standby bucket).

**Things that did not work.**

- U-NEXT's boot receivers cannot be disabled from the ADB shell (`Shell cannot change component state`), so the app
  was removed instead.
- Re-enabling `com.tcl.keyhelp`, `com.tcl.partnercustomizer` and `com.tcl.tv.tclhome_passive` did not bring the remote
  buttons back, so they were disabled again (see problem 3).

**Lesson.** Measure with the system-wide numbers (free, available, swap). Per-process RSS includes shared memory and
overstates everything. Boot time did not improve (34 s); the real gains are more free memory, less swapping and Quick
Start, which avoids full boots.

## 2. Replace the home screen

**Symptom.** The Google TV launcher was about 290 MB over two processes and pulled content from preinstalled apps.

**Fix.** Replace it with a small native launcher, [`Gathin23/tv-vibehack`](https://github.com/Gathin23/tv-vibehack)
(`com.gathin.tvhome`, 266 KB, no INTERNET permission), built locally. It has a seven-slot dock: YouTube, Netflix,
Disney+, TVer, Prime Video, ABEMA and live TV. Then the Google TV launcher was disabled and the new one pinned as Home
with `cmd package set-home-activity`. A second Home app makes Android show a chooser, so pin it right away.

**Honest note.** We measured it: FLauncher and the native launcher both use about 50 MB (PSS). The swap was for looks
and for the Inputs menu, not for speed.

## 3. Remote app buttons

**Symptom.** After the Google TV launcher was disabled, only the ABEMA button still worked. Netflix, YouTube, Prime
Video, TVer and Disney+ did nothing.

**Cause.** The TV's window manager (`TclPhoneWindowManager`) handles the remote's special keys. ABEMA is started
directly. The others only send a broadcast that the Google TV launcher answers. With it disabled, nobody listens.
Re-enabling it brings the buttons back but also takes over the Home key, and no ADB setting stops that.

**Fix.** Put the listener in our own launcher. `InputKeyService` is an accessibility service with key filtering, and
those filters run before the window manager. It reads a list from `launcher/config.xml` (`keycode:package`) and starts
the app itself.

**Pitfalls.**

- The first APK predated the feature and silently ignored `app_keys`. We rebuilt from current upstream.
- The service can show as enabled but be unbound. Clear the list first, then set it
  (see [remote-app-buttons.md](remote-app-buttons.md)).
- `adb shell input keyevent` skips accessibility filters, so only the real remote proves it works.

## 4. Assigning buttons: find the keycode

The codes are not the Linux scancodes. To find a button's Android code, press it while watching the log:

```powershell
adb logcat | Select-String "handleKeyBeforeDispatching, key ="
```

`TclPhoneWindowManager: handleKeyBeforeDispatching, key = 4062` is the Netflix button. Then add it to `app_keys`:

| Button | Code | Does |
|---|---|---|
| Netflix | 4062 | opens Netflix |
| YouTube | 4065 | opens YouTube |
| Prime Video | 4099 | opens Prime Video |
| TVer | 4161 | opens TVer |
| ABEMA | 4134 | opens ABEMA |
| Disney+ | 4141 | opens Disney+ |
| Hulu | 4066 | opens Disney+ (Hulu is uninstalled) |
| TCL | 4020 | live TV |
| Apps | 4082 | Disney+ |
| U-NEXT, FOD | 4133, 4146 | nothing |

Any button can be remapped to any app. To disable a button, map it to a package that does not exist
(`4133:none.unused`); the key is swallowed and nothing starts.

## 5. Wallpaper

The TV's only display mode is 1920x1080, so a 4K wallpaper cannot look sharper, and the launcher downsamples to screen
size anyway. So instead of feeding it a huge image, scale the original once to exactly 1920x1080:

- Source: Shinjuku Station South Entrance at night (Pixabay 617590), CC0.
- Crop to 16:9 from the lower part of the frame, scale to 1920x1080, dim it, and add darker bands behind the clock
  and the dock so text stays readable. JPEG quality 93, about 360 KB.
- Push it to the launcher's own folder over ADB. No document picker is needed (this TV has none):

```powershell
$dir = '/sdcard/Android/data/com.gathin.tvhome/files'
adb shell mkdir -p $dir
adb push theme\config.json  $dir/config.json
adb push theme\wallpaper.jpg $dir/wallpaper.jpg
adb shell am force-stop com.gathin.tvhome
```

File size does not affect RAM, so quality was the only thing to tune.

## 6. Volume went up in steps of 2

**Symptom.** After the key service was running, every press of volume up changed the volume by 2 (2, 4, 6, 8).

**How we found it.** Logs showed two `handleKeyBeforeDispatching` calls and two volume changes for each press.
Turning the service off made volume step by 1, so the service was involved. Turning off HDMI-CEC volume control did
nothing.

**Cause.** On this TV the window manager changes the volume before key filtering and again when the filter hands
the key back.

**Fix.** The service consumes the volume keys (up, down, mute). That drops the second pass. The first one still
changes the volume, so the service must not adjust the volume itself: our first attempt did, and doubled it again.
The change is [`launcher/volume-double-step.patch`](../launcher/volume-double-step.patch).

## 7. The buttons stopped working again

**Symptom.** The app buttons worked in the morning and did nothing in the evening.

**Cause.** Android had unbound the key service. On this TV, TCL's `TclAppBoot` also blocked it from starting
(`forbid bind service ... callee_does't_have_OP_AUTO_START_permission`) because the launcher's `APP_AUTO_START`
app-op was `ignore`.

**Fix.**

```powershell
adb shell "appops set com.gathin.tvhome APP_AUTO_START allow"
adb shell "settings put secure enabled_accessibility_services ''; sleep 1; settings put secure enabled_accessibility_services com.gathin.tvhome/com.gathin.tvhome.InputKeyService; settings put secure accessibility_enabled 1"
```

Then check that `adb shell dumpsys accessibility` lists the service under `Bound services`.

## What we would tell someone starting out

1. Measure before you change anything, and measure the right number.
2. Everything here is reversible; keep `undo.ps1` and a backup of the original launcher APK.
3. Read the log first. Every real cause above was found in `logcat`, not by guessing.
4. Test with the real remote, not `adb shell input keyevent`.
