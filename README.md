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
The player of any Haylen app from the address of its zip file, for phones, tablets, foldables and TVs.
</p>

<br>

## What it is

Haylen Runner plays [Haylen](https://github.com/haylen-org/haylen) apps from the address of their zip file, which suits trying an app on a phone, a tablet or a TV while it is being made, without building it for that device. It is itself a Haylen app written in Lua, which the App Store and Google Play carry as the player of every Haylen project.

Opening an address downloads the zip file and plays the app on its own in place of the runner, with `haylen.launch`. The runner comes back when the app quits, through `haylen.quit()`, the Close button of its error screen or the back button at its root on Android and Apple TV.

## Features

- 🔗 A field to type or paste the address of a zip file, which opens it with the Open button or the Go key of the keyboard.
- 📷 A button that reads the address from a QR code with the camera, where the device has one.
- 🕘 The addresses opened before, each once and the most recent first, kept between runs.
- 📥 A download with its progress, which keeps each address in a file of its own.
- ℹ️ The versions of the runner, of Haylen and of the system.
- 📱 Every orientation, on phones, tablets, foldables and TVs, with the keyboard, touch, gamepads and TV remotes.

## Platforms

| | Platform | QR scanner |
| --- | --- | --- |
| 📱 | iOS and iPadOS | Yes |
| 💻 | Mac Catalyst | Yes |
| 📺 | tvOS | No |
| 🤖 | Android phones, tablets and TVs from one APK | Phones and tablets |
| 🌐 | Web | No |

TVs, desktops and browsers have no QR scanner, so the button shows only where the device reads codes.

## Quick start

The runner builds with the command `haylen` of a checkout of the [Haylen repository](https://github.com/haylen-org/haylen), whose root is on `PATH`:

```sh
git clone https://github.com/haylen-org/haylen-runner.git
cd haylen-runner
haylen run .
haylen run . --platform ios-simulator
haylen run . --platform android
haylen run . --platform web
```

An app to try is the folder of a Haylen app zipped with its `app.json`, `source/` and `content/` at the root of the zip, which `haylen package <app>` writes. Serve it at an address the device reaches, such as `http://192.168.0.10:8000/app.zip` from `python3 -m http.server` in the folder of the zip.

## Layout

| Path | What it holds |
| --- | --- |
| `app.json` | The identity `com.haylen.runner`, the window, the design size, the splash and the plugin of the runner. |
| `source/` | The home screen in `main.lua`, the addresses opened before in `history.lua` and the download in `download.lua`. |
| `content/` | The logo of the splash and the logo and icons of the home screen. |
| `plugins/qr-scanner/` | The plugin that reads QR codes with the camera on iPhones, iPads, Macs and Android devices. |
| `platform/apple/` | The Xcode project of iOS, iPadOS, Mac Catalyst, tvOS, visionOS and macOS, with its icons. |
| `platform/android/` | The Gradle project of Android phones, tablets and TVs, with its icons. |

The file [`AGENTS.md`](AGENTS.md) describes how the runner works and the rules that every change follows.

## License

Haylen Runner is free for personal and commercial work, forever, under the [MIT License](LICENSE). Every contribution becomes part of it under the same license.
