<p align="center">
    <a href="https://github.com/haylen-org/haylen-runner" target="_blank" rel="noopener noreferrer"><img width="120" src="extras/images/symbol.svg" alt=""></a>
</p>

<h1 align="center">Haylen Runner</h1>

<p align="center">
    <a href="https://github.com/haylen-org/haylen-runner/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
    <a href="https://github.com/haylen-org/haylen"><img src="https://img.shields.io/badge/made%20with-Haylen-07112F.svg" alt="Made with Haylen"></a>
    <a href="https://github.com/varn-org/varn"><img src="https://img.shields.io/badge/Lua-Varn-000080.svg" alt="Lua through Varn"></a>
</p>

<p align="center">
The app that runs other Haylen apps on your phone, tablet, TV or desktop, from an address, a QR code or a link, with hot reload while you make them.
</p>

<br>

## What it is

Haylen Runner runs [Haylen](https://github.com/haylen-org/haylen) apps from the address of their zip file. You build it once for each device you use and install it there. Then you open an app by typing or pasting its address, by scanning a QR code or by tapping a link of the runner. The app runs in place of the runner, and you can always come back. The runner keeps the apps you opened, each with its name, its logo and when you last opened it, so a tap opens one again.

The runner is itself a Haylen app written in Lua. Opening an address downloads the zip file and plays the app in place of the runner with `haylen.launch`. The runner comes back when the app quits, or when you hold the way back of the device, which no app can take:

| Device | Hold for a moment |
| --- | --- |
| Keyboard, on desktops, the web and tablets | Escape |
| Apple TV and Android TV remote | Play and pause, since the Apple TV takes a hold of Menu to its Home screen |
| Android phones and tablets | The back button, or the back gesture kept before you let go |
| Gamepad | The back button, such as View or Select |
| Touch screen | Three fingers that stay still |

A panel at the top of the screen fills its bar while you hold, and the app hears a short press as always.

While you make an app, `tools/serve.py` serves it from your computer and prints a QR code. The runner then plays it with hot reload: every file you save reloads on the device, without building anything for that device.

Publishing the runner in a store is optional. Anyone builds it from this repository and installs it on their own devices, as [build and install](#build-and-install) explains.

## Features

- 🕘 The apps opened before, each with its name and logo from its package and when it was last opened, which you open again with a tap, remove one by one or clear all at once.
- ↩️ A way back to the runner from any app on every device, which the app cannot block.
- 🔁 Hot reload of the apps that `tools/serve.py` serves, with the keys of the run that reload, restart and reach the developer console of the app on the device.
- 🔗 The link `haylen-runner://open?url=<address>`, which opens the runner from the QR code that the camera of the device reads, from a browser, from another app, from a terminal or from the page address on the web, and opens the next app while one plays.
- 📷 A button that reads the address or the link from a QR code with the camera, where the device has one.
- ⌨️ A field to type or paste the address of a zip file, which opens it with the Open button or the Go key of the keyboard.
- 📥 A download with its progress, which keeps each address in a file of its own.
- ℹ️ The versions of the runner, of Haylen and of the system.
- 📱 Every orientation, on phones, tablets, foldables, TVs and desktops, with the keyboard, touch, gamepads and TV remotes.

## Serve an app while you make it

The tool `tools/serve.py` of this repository needs Python 3 and the command `haylen` of a checkout of Haylen on `PATH`, or named with `--haylen`:

```sh
python3 tools/serve.py ~/apps/my-game
python3 tools/serve.py ~/apps/my-game --port 8100 --haylen ~/haylen/haylen
```

It runs `haylen serve <app>`, which serves the zip of the app and its development server on one port of your computer, both behind a token of the run, and passes on every option it does not know, such as `--port` and `--host`. It prints the QR code of the link of the runner, the link, the address of the zip and the keys of the run:

```text
  App         My Game ("com.example.mygame")
  Address     http://192.168.1.20:8000/haylen/3f9a1c2b7d4e/app.zip
  Hot reload  Every file saved in the app reloads in the players that play it
```

Then open the app on the device in one of these ways:

- Point the camera of the system at the QR code on iPhones, iPads and Android devices, and tap the link it shows, which opens the runner.
- Tap "Scan a QR code" in the runner.
- Type or paste the address into the runner, which suits TVs and desktops.

The device and the computer must share a network. The first download from your computer asks for the access to the local network where the system asks for it, on iOS, iPadOS, tvOS, visionOS, macOS and Android 17. Save a file of the app, and it reloads on the device. The keys `r`, `R` and `d` of the terminal reload what changed, restart the app and run a line of the developer console of the app on the device. Quit the app, or hold the way back of the device, to go back to the runner. The key `q` stops the server.

A zip that you serve yourself opens too, such as one that `haylen package <app>` writes, served with `python3 -m http.server` in its folder at `http://192.168.1.20:8000/app.zip`. Such an app plays as it is, without hot reload.

The runner plays an app without native access, so the app has no `ffi`, `process` or `haylen.native` and reaches the system only through the Haylen API and the plugins of the runner. The runner carries the native parts of its own plugins only, so a plugin of the app whose native part the runner lacks answers its calls with `unsupported`. The runner plays the package of a Lua app, so C++ apps run with `haylen run` on each platform.

## Platforms

| | Platform | QR scanner | Link of the runner |
| --- | --- | --- | --- |
| 📱 | iOS and iPadOS | Yes | Yes, also from the camera of the system |
| 💻 | Mac Catalyst | Yes | Yes |
| 📺 | tvOS | No | Yes, from another app or `xcrun simctl openurl` |
| 🥽 | visionOS | No | Yes |
| 🖥️ | macOS | No | Yes |
| 🤖 | Android phones, tablets and TVs from one APK | Phones and tablets | Yes, from the camera app of the device when it opens links |
| 🌐 | Web | No | The hash of the page address, such as `#url=http%3A%2F%2F...` |
| 🪟 | Windows | No | Yes, once the installer or `haylen run` registered the scheme |
| 🐧 | Linux | No | Yes, once the package or `haylen run` registered the scheme |

TVs, desktops and browsers have no QR scanner, so the button shows only where the device reads codes. The camera app of an Android device decides whether it opens links of other schemes, so where it only shows the text, read the code with the scanner of the runner.

The runner opens by its scheme alone. A universal link of Apple platforms or an App Link of Android needs a web domain that vouches for the signature of the build, and every person signs their own build, so whoever owns a domain can add one to their own build of the runner.

On Windows and Linux a link starts a new process of the runner, which hands the link to the runner that runs already and ends, so one runner takes every link. The installer of Windows and the package of Linux register the scheme, and so does `haylen run . --platform windows` or `--platform linux` for the runner of its build folder. The desktop player of `haylen run .` has no scheme of its own, so a link opens an installed runner: the app that the installer, the package or `haylen run` with a platform puts on the computer, and on macOS the app of the Apple project.

## Build and install

The runner builds with the command `haylen` of a checkout of the [Haylen repository](https://github.com/haylen-org/haylen), whose root is on `PATH`:

```sh
git clone https://github.com/haylen-org/haylen-runner.git
cd haylen-runner
```

The first build of each platform builds the engine artifacts it needs, which takes a while once. The Release configuration ships the runner as its protected release, with keys that Haylen creates for the runner in your configuration folder the first time.

### iPhone and iPad

1. Connect the device, turn on its developer mode, and list it with `haylen devices`.
2. Name your Apple team, a free personal team works, with `export HAYLEN_APPLE_TEAM=<team id>`.
3. Build, install and start the runner:

```sh
haylen run . --platform ios --device <device id> --config Release
```

A free personal team signs builds that the device trusts for seven days, after which you run the command again. The first launch asks you to trust the developer in the settings of the device.

### Apple TV

Pair the Apple TV with Xcode, then build it the same way with its id:

```sh
haylen run . --platform tvos --device <device id> --config Release
```

On the TV, type the address that `tools/serve.py` prints into the runner with the remote.

### Android phones, tablets and TVs

1. Turn on the developer options and USB or wireless debugging of the device, and list it with `haylen devices`.
2. Create the upload key that signs the release builds once, which stays in `platform/android/keystore/`, outside git:

```sh
haylen distribution android-key .
```

3. Build, install and start the runner:

```sh
haylen run . --platform android --device <serial> --config Release
```

One APK serves phones, tablets and Android TV.

### Desktops

```sh
haylen run . --platform macos --config Release
haylen run . --platform windows --config Release
haylen run . --platform linux --config Release
```

The command installs the app into the build folder of the runner under `build/apps/`, from where you copy it, and `haylen distribution installer . --platform windows` or `--platform linux` makes its installer.

### Web

```sh
haylen run . --platform web --open
```

The page serves on your computer, so it reaches the server of `tools/serve.py` on the same network. Open an address with the field, or with the hash of the page address, such as `http://127.0.0.1:8000/#url=http%3A%2F%2F192.168.1.20%3A8100%2Fhaylen%2F3f9a1c2b7d4e%2Fapp.zip`.

### The Apple project

The Apple project is an XcodeGen spec, `platform/apple/project.yml`, with the generated `App.xcodeproj` committed next to it. After you change `project.yml`, or the plugins or the Apple keys of `app.json`, generate the project again with the XcodeGen that Haylen pins, and commit both:

```sh
haylen platform xcodegen .
```

### Development builds

`haylen run .` plays the runner itself in the desktop player with hot reload, and `haylen run . --platform ios-simulator`, `tvos-simulator`, `visionos-simulator`, `android` or `web` builds it in the Debug configuration. Check a release build of a platform with `haylen check . --platform <platform> --config Release`.

The UI tests in `ui-tests/` drive the runner on an Apple simulator with the probe app of `ui-tests/probe`. They open it by its link and by its typed address, check that it plays without native access, change its source to check the hot reload, come back to the runner and find it in the history. The tool `tools/ui-tests.py` serves the probe and runs them with `haylen test --ui`:

```sh
python3 tools/ui-tests.py --platform ios-simulator --device "iPhone 17"
python3 tools/ui-tests.py --platform tvos-simulator --device "Apple TV 4K (3rd generation)"
```

## Layout

| Path | What it holds |
| --- | --- |
| `app.json` | The identity `com.haylen.runner`, the window, the design size, the splash and the plugins of the runner. |
| `source/` | The home screen in `main.lua`, the addresses and links in `address.lua`, the apps opened before in `history.lua` and the download in `download.lua`. |
| `tools/` | `serve.py`, which serves an app with hot reload and prints the QR code of its link, with its tests in `test_serve.py`, and `ui-tests.py`, which runs the UI tests. |
| `ui-tests/` | The UI tests of the runner and the probe app they open. |
| `content/` | The logo of the splash and the logo and icons of the home screen. |
| `plugins/qr-scanner/` | The plugin that reads QR codes with the camera on iPhones, iPads, Macs and Android devices. |
| `plugins/url-scheme/` | The plugin that registers the scheme of the links of the runner on every platform and hands the runner its links. |
| `platform/apple/` | The Xcode project of iOS, iPadOS, Mac Catalyst, tvOS, visionOS and macOS, with its icons. |
| `platform/android/` | The Gradle project of Android phones, tablets and TVs, with its icons. |

The file [`AGENTS.md`](AGENTS.md) describes how the runner works and the rules that every change follows.

## License

Haylen Runner is free for personal and commercial work, forever, under the [MIT License](LICENSE). Every contribution becomes part of it under the same license.
