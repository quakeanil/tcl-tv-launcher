# Settings guide: what to do on the TV and the PC

Step by step, in order. Everything here is reversible. Times are for a 2 GB TCL Android TV 11 set; yours may differ.

## 0. Before you start

- A Windows PC on the same Wi-Fi/LAN as the TV, with PowerShell.
- Do this when nobody is watching: the TV restarts and the launcher is swapped.
- A factory reset undoes the debloat (not the repo), see [After a factory reset](#after-a-factory-reset).

## 1. Turn on ADB on the TV

1. Settings > System > About, select **Android TV OS build** 7 times ("You are now a developer").
2. Settings > System > Developer options > **USB debugging: on**.
3. Find the TV's IP: Settings > Network & Internet > your network. Optionally give it a fixed IP (DHCP reservation)
   in your router so the address does not change.
4. On the PC:

```powershell
winget install --id Google.PlatformTools -e
adb connect <TV-IP>:5555
```

5. Accept **Allow USB debugging?** on the TV and tick **Always allow**. `adb devices` should list the TV as `device`.

## 2. Build and install the launcher

Follow [launcher-swap.md](launcher-swap.md) to build `app-release.apk` (JDK 17, Android SDK, Gradle, about 10 minutes
the first time). Edit `launcher/config.xml` first:

- `dock_apps`: the seven dock slots, as package names. List yours with `adb shell pm list packages`.
- `hidden_apps`: tiles you never want shown.
- `live_tv_package`: your TV's tuner app (`com.tcl.tv` here).
- `app_keys`: your remote buttons. See [remote-app-buttons.md](remote-app-buttons.md) to find each button's keycode.

## 3. Apply the debloat

```powershell
.\scripts\apply.ps1 -Ip <TV-IP> -LauncherApk .\app-release.apk
```

It installs the launcher first and only disables the Google TV launcher if the custom one is installed, so the TV
always keeps a home screen. **Check the package lists in `scripts/common.ps1` against your own TV first**; they are
for this firmware. Remove anything you want to keep.

Then restart the TV (unplug it for 30 seconds).

## 4. Settings to change on the TV itself

These cannot be set over ADB, so do them by hand:

| Where | Setting | Why |
|---|---|---|
| Play Store > Settings | **Auto-update apps: Don't auto-update** | Stops background updates eating RAM after boot |
| Settings > Power & Energy | **Quick Start: on** | Standby becomes a light sleep, so the TV wakes in seconds instead of doing a full boot |
| Settings > Power & Energy | Sleep timer and Auto standby: off | Your call; this setup left them off |
| Home screen chooser | Pick the custom launcher if Android shows one | Or pin it: `adb shell cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity` |

The launcher's Wi-Fi name on its status pill needs one permission:

```powershell
adb shell pm grant com.gathin.tvhome android.permission.ACCESS_FINE_LOCATION
```

## 5. Make the remote's app buttons work

Needed after you disable the Google TV launcher. Enable the launcher's key service (the clear-then-set order matters):

```powershell
adb shell "settings put secure enabled_accessibility_services ''; sleep 1; settings put secure enabled_accessibility_services com.gathin.tvhome/com.gathin.tvhome.InputKeyService; settings put secure accessibility_enabled 1"
adb shell dumpsys accessibility | Select-String "Bound services"      # should show one service, not {}
```

Press each button on the real remote to test. `adb shell input keyevent` skips this service, so it cannot test it.

## 6. Wallpaper (optional)

```powershell
$dir = '/sdcard/Android/data/com.gathin.tvhome/files'
adb shell mkdir -p $dir
adb push theme\config.json  $dir/config.json
adb push theme\wallpaper.jpg $dir/wallpaper.jpg
adb shell am force-stop com.gathin.tvhome
```

`force-stop` switches the key service off. Run the command from step 5 again afterwards.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `adb connect` times out | Same network? USB debugging still on? Some TVs turn it off after a reboot or update. |
| `unauthorized` | Accept the prompt on the TV (tick Always allow), then `adb kill-server` and reconnect. |
| Home key shows a "choose launcher" popup | Pin the launcher: `adb shell cmd package set-home-activity --user 0 com.gathin.tvhome/.MainActivity` |
| Remote app buttons do nothing | Key service not bound: redo step 5. It is dropped when the launcher is reinstalled or force-stopped. |
| A button opens the Google TV launcher again | `com.google.android.apps.tv.launcherx` got re-enabled (a system update can do that). Disable it again: `adb shell pm disable-user --user 0 com.google.android.apps.tv.launcherx` |
| `Shell cannot change component state` | That component cannot be changed from ADB. Disable the whole package instead, or leave it. |
| Something broke and you cannot tell what | `.\scripts\undo.ps1 -Ip <TV-IP>` restores everything, including the Google TV launcher. |

## After a factory reset

Disabled system packages come back. Redo steps 1, 3, 4 and 5 (reinstall the launcher with `-LauncherApk`).

## Do not share

Your TV's IP, serial numbers and Wi-Fi name are not secrets, but there is no reason to publish them. This repo uses
`192.168.0.40` only as an example. Never commit passwords, Wi-Fi keys, ADB keys (`~/.android/adb`* files) or signing
keystores.
