# Remote app buttons with the custom launcher

Status: **working** on the TCL BeyondTV4 remote (`BT_RC843_J1`). All app buttons open their app with the Google TV
launcher disabled and `com.gathin.tvhome` as Home.

## Problem

After replacing the Google TV launcher (`com.google.android.apps.tv.launcherx`), only the ABEMA button on the remote
still worked. Netflix, YouTube, Prime Video, TVer and Disney+ did nothing, and Hulu (uninstalled) had no target.

## Cause

The remote sends TCL key codes. `TclPhoneWindowManager` (in `services.jar`) handles them before any app sees them:

- ABEMA is started directly (`startAbema` calls `startActivity`), so it kept working.
- The other buttons only send a broadcast (`startNetflix`, `startTVER`, ...) that the Google TV launcher answers.
  With `launcherx` disabled nothing listens.

Re-enabling `launcherx` brings the buttons back but also takes over the Home key: the TV starts it explicitly, and
`cmd package set-home-activity` and the Home role (`com.gathin.tvhome` held it) do not stop that. ADB cannot disable
only its Home activity (`Shell cannot change component state`). Re-enabling `com.tcl.keyhelp`,
`com.tcl.partnercustomizer` and `com.tcl.tv.tclhome_passive` did not help either.

## Fix

The launcher ships `InputKeyService`, an accessibility service with `flagRequestFilterKeyEvents`. Accessibility key
filters run before the window manager's key handling, so the service can catch the codes and start the app itself.
It reads the `app_keys` list from `launcher/config.xml` ("keycode:package").

| Button | Keycode | Opens |
|---|---|---|
| Netflix | 4062 | `com.netflix.ninja` |
| YouTube | 4065 | `com.google.android.youtube.tv` |
| Prime Video | 4099 | `com.amazon.amazonvideo.livingroom` |
| TVer | 4161 | `jp.co.tver.tvapp` |
| ABEMA | 4134 | `tv.abema` |
| Disney+ | 4141 | `com.disney.disneyplus` |
| Hulu | 4066 | `com.disney.disneyplus` (Hulu is uninstalled, so the button opens Disney+) |
| TCL | 4020 | `com.tcl.tv` (live TV; the stock action started `com.tcl.partnercustomizer`, now disabled) |
| Apps (アプリ) | 4082 | `com.disney.disneyplus` (the stock action opened Settings' app list) |
| U-NEXT | 4133 | nothing: mapped to the non-existent package `none.unused`, which swallows the key |
| FOD | 4146 | nothing: same trick (FOD is disabled, the stock action tried to start it) |

## How the codes were found

They are not the Linux scancodes in `Generic.kl` (Netflix 242, YouTube 245, TVer 351, ABEMA 441, Prime Video 752,
Disney+ 762, Hulu 570). Android codes come from the system log. With `logcat`, press a button and read
`TclPhoneWindowManager: handleKeyBeforeDispatching, key = N`. `adb shell input keyevent KEYCODE_TCL_NETFLIX` (also
`_YOUTUBE`, `_PRIMEVIDEO`, `_TVER`, `_ABEMA`, `_DISNEY`, `_HULU`) injects the same codes and logs the number.

## Needs a rebuilt launcher

The first APK installed here predated the `app_keys` feature and silently ignored it. Check with:

```powershell
adb pull $(adb shell pm path com.gathin.tvhome).Replace('package:','') tv.apk   # look for the string app_keys in the dex
```

Rebuild as in [launcher-swap.md](launcher-swap.md) from current `Gathin23/tv-vibehack` (upstream commit `fd1ee0a`),
using [`launcher/config.xml`](../launcher/config.xml). `launcher/no-ambient.patch` was regenerated against that
commit. Because upstream's own `config.xml` has gained keys, edit the cloned one (dock, hidden apps,
`live_tv_package` `com.tcl.tv`, `columns` 7, `module_cards` false, `app_keys`) instead of overwriting it
blindly.

After installing:

```powershell
adb shell "appops set com.gathin.tvhome APP_AUTO_START allow"
adb shell "pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION"
adb shell "cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity"
adb shell "settings put secure enabled_accessibility_services ''; sleep 1; settings put secure enabled_accessibility_services com.gathin.tvhome/com.gathin.tvhome.InputKeyService; settings put secure accessibility_enabled 1"
```

Clearing the list first is needed: without it the service shows as enabled but is not bound (`dumpsys accessibility`
`Bound services:{}`).

## Volume went up in steps of 2

With the key service on, every press of volume up/down changed the volume twice (2, 4, 6, 8). On this TV
`TclPhoneWindowManager` handles the volume key before accessibility filtering and again when the filter passes the key
back. With the service off, volume steps by 1. Consuming the volume keys in `InputKeyService` drops the second pass:
apply [`launcher/volume-double-step.patch`](../launcher/volume-double-step.patch) to the clone before building
(`git apply`). The service must not adjust the volume itself, or the steps double again.

## Service stays unbound: `APP_AUTO_START`

Symptom: `settings get secure enabled_accessibility_services` lists the service but `dumpsys accessibility` shows
`Bound services:{}`, and logcat has `forbid bind service ... InputKeyService` from `TclAppBoot` with
`callee_does't_have_OP_AUTO_START_permission`. TCL's auto-start app-op blocks the bind after a reinstall or when the
process died. Fix once per install, then re-enable the service as above:

```powershell
adb shell "appops set com.gathin.tvhome APP_AUTO_START allow"
```

## Caveats

- Android drops the service from the enabled list when the launcher is force-stopped or reinstalled; run the last
  command again.
- `adb shell input keyevent` skips accessibility filters, so test with the real remote.
- To make a button do nothing, map its keycode to a package that does not exist; the service consumes the key and
  `RemoteKeys.launch` finds no app to start. To give U-NEXT or FOD a job later, replace `none.unused`.
- `com.tcl.keyhelp`, `com.tcl.partnercustomizer` and `com.tcl.tv.tclhome_passive` were re-enabled while debugging.
  They are not needed: with them disabled again (as `scripts/apply.ps1` does), every button still works on the real
  remote.
- The remote has no Disney+ button, only Hulu, so 4066 is the one that matters; 4141 is a spare.
- `scripts/apply.ps1` now enables the key service after installing the launcher; `undo.ps1` switches it off.
