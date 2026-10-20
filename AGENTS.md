# 🧭 Haylen Runner — project guide

Haylen Runner is an app that runs other [Haylen](https://github.com/haylen-org/haylen) apps from the address of their zip file, and with hot reload the apps that `tools/serve.py` serves on the local network while they are made. It is itself a Haylen app written in Lua, with a native plugin that reads QR codes and one that registers the scheme of the links of the runner. Anyone builds it and installs it on their own phone, tablet, TV or desktop, as `README.md` explains, and publishing it in the stores is optional. Its home screen takes the address of a zip file, typed, pasted, scanned from a QR code, opened by a link or picked from the apps opened before, downloads it and plays the app in place of the runner until that app quits or the person holds the way back of the device.

This file is binding for every change. It describes the project as it is and the rules every change follows, so read it before working and follow it exactly. When a rule or a design decision changes, update this file in the same change and describe the new state in the present tense. The runner is a Haylen app, so the rules that the `AGENTS.md` of the Haylen repository gives apps and samples hold here too: the Lua API, the naming, the writing standard and the platform projects.

## Core principles

- No shortcuts, hacks, silent fallbacks, dead or obsolete code or compatibility paths. Fix root causes and remove what a change supersedes.
- A flaw of the engine is fixed in the engine, never worked around here. When the runner needs something Haylen lacks, Haylen gains the capability first and the runner uses it.
- The runner uses only the documented Lua API of Haylen and the modules of Varn that Haylen documents, such as `http`, `fs`, `crypto` and `async`.
- Only change what makes sense to change. Do not add code, comments or files just to show work.
- Code, comments and documentation are written in English. Never mention other engines, third-party games, apps or companies, except the platforms and stores the runner ships to and the SDKs its plugin names in its setup.
- The repository never records its own history. Code, comments and docs describe what exists now. Git holds the history.
- The runner is free for personal and commercial work, forever, under the MIT License of `LICENSE`, and every contribution becomes part of it under the same license.

## What it does

- **Home screen.** `source/main.lua` mounts one GUI in a scene: the Haylen logo, a sentence that says what the runner does, a card with the address field (`keyboard = 'url'`, `returnKey = 'go'`, without autocorrection or capitals), the Open button, the Scan button where a scanner exists, the progress bar and the status line, the sentence that says how to come back from a running app on the device, the apps opened before with the button that clears them, and the line of versions of the runner, of Haylen and of the system. The screen updates its components with `gui:set` and the rows of the history with `gui:replaceChildren` instead of mounting the GUI again. On tvOS it raises the UI scale for a screen seen from across a room.
- **Links.** `source/address.lua` turns a text into the address of a zip file: an `http://` or `https://` address as it is, or the parameter `url` of a link `haylen-runner://open?url=<address>`, which the QR code of `tools/serve.py` holds, also with the slash before the query that the shell of Windows adds, `haylen-runner://open/?url=<address>`. The plugin `plugins/url-scheme/` declares the scheme of its parameter `scheme` to every system, in `CFBundleURLTypes` on Apple platforms, in an intent filter on `HaylenLinkActivity` of `haylen-links` on Android and in `desktop.urlSchemes` for the registry of Windows and the desktop entry of Linux, so the camera of the system, a browser or another app opens the runner from a link. The engine publishes each link as the event `linkOpened`, and on the web the plugin hands the hash of the page address over as a link with `context.openLink`. A link that arrives while a launched app plays ends that app, and the runner hears it once it starts again, so the camera of the system opens the next app while one plays. Its Lua API, `require('url-scheme')`, has `scheme()` and `onOpened(listener, options)`, which `source/main.lua` connects while it runs, since the link that launched the runner arrives once that script ran and before the home screen enters, so the screen keeps it until it shows. The scanner and the field take the same links. A universal link or an App Link needs a domain that vouches for the signature of each build, so the runner opens by its scheme alone.
- **History.** `source/history.lua` keeps the apps the runner opened in `haylen.preferences` under the key `opened`, each once, the most recent first, up to a bounded count that the module declares: the address, the name of the app and the file of its logo once a download read them, and when it was last opened. The home screen shows each one as a row with its logo, its name, when it was opened and its address, which opens it again, next to a button that removes it, and a button under the list clears it.
- **Download.** `source/download.lua` writes the zip file to disk as it arrives with `http.client.download`, so a large app never sits in memory, reports how much arrived, refuses a body past the limit that the module declares and a status that is not a success, and keeps the file under `haylen.storage` in the folder `apps/`, named after the first characters of the SHA-256 of its address. The file of an address changes only once the next download of it is whole, and a download that fails, or whose task ends with the screen, leaves no partial file, since a controller closed with the task cancels it. It returns the path with the value of the header `Haylen-Development-Server`, which `haylen serve <app>` sends. Next to the zip file it keeps the logo that the package names in `splash.logo`, which `haylen.packageInfo` reads with the name of the app. Removing an app deletes its files, and clearing the list deletes that folder.
- **Local network.** Before it downloads from an address of the local network, the screen asks for the access with `system.requestPermission('localNetwork')` while `system.permission('localNetwork')` is `'prompt'`, as Android 17 needs, and says how to grant it when the person refuses. Apple platforms ask the person on the first connection with the text of `NSLocalNetworkUsageDescription`.
- **Launch.** Once the file is saved, `haylen.launch(path, {developmentServer = server, nativeAccess = false})` plays it with a new engine and a new Lua state, in development with hot reload when the server of the zip names its development server in the header `Haylen-Development-Server`, as `haylen serve <app>` does. The app plays without native access, so it has no `ffi`, `process`, `haylen.native`, `package.loadlib`, `io.popen` or `os.execute` and reaches the system only through the Haylen API and the plugins of the runner, as the stores ask of an app that runs code it downloads, and the probe of the UI tests shows it. The launched app returns to the runner with `haylen.quit()`, the Close button of its error screen, the back button at its root on Android and Apple TV, or the hold that the engine offers every launched app and the app cannot take: Escape, play and pause of a TV remote, the back button of Android or of a gamepad, or three still fingers. The home screen says which hold the device has, and the runner starts again from its own package.
- **QR codes.** The plugin `plugins/qr-scanner/` reads the text of a QR code with the camera through AVFoundation on iPhones, iPads and Mac Catalyst, and through the code scanner of Google Play services on Android phones and tablets. It owns the permission `camera`, which it asks for through `requirePermission` of its context before a scan. Its Lua API, `require('qr-scanner')`, has `available()`, which is `false` on TVs, desktops and the web, and `scan()`, which returns a platform call that gives `{text}` or fails with `cancelled`, `denied` or `unsupported`. Its `README.md` documents the whole API, the permission and the setup of each platform.

## Repository layout

```text
app.json                  The identity com.haylen.runner, the version, the description, the window, the design size, the UI scale mode, the splash and the plugins with their parameters.
source/main.lua           The home screen and the flow from an address to a launched app.
source/address.lua        The addresses and links that the runner opens.
source/history.lua        The apps opened before.
source/download.lua       The download of a zip file into the storage of the runner.
content/                  The logo of the splash (logo.png) and the logo and icons of the home screen (images/).
plugins/qr-scanner/       The QR scanner plugin: plugin.json, README.md, the Lua API in source/, the Swift part in apple/ and the Kotlin library module in android/.
plugins/url-scheme/       The plugin of the scheme of the links of the runner: plugin.json, README.md, the Lua API in source/, the Android library module of its manifest in android/ and the ES module in web/.
tools/serve.py            The tool that serves an app with hot reload through "haylen serve" and prints the QR code of the link of the runner, with its tests in tools/test_serve.py.
tools/ui-tests.py         The tool that serves the probe of ui-tests/probe and runs the UI tests of the runner on an Apple simulator with "haylen test --ui".
ui-tests/                 The UI tests of the runner in Swift, RunnerTests.swift, and the probe app they open, which they change while it runs to check the hot reload.
platform/apple/           The Xcode project of iOS, iPadOS, Mac Catalyst, tvOS, visionOS and macOS, generated by XcodeGen from project.yml, with its icons.
platform/android/         The Gradle project of Android phones, tablets and TVs, with its icons.
extras/images/            The Haylen symbol that the README shows.
```

The folders `platform/*/haylen/`, which `haylen.py` writes on every build, and the signing keys of `platform/android/keystore/` are gitignored and never committed.

## Platform projects

- The projects of `platform/` belong to the runner and follow the templates of Haylen: `templates/lua/platform/apple` and `templates/common/platform/android`. The command `haylen platform diff . apple` (or `android`) compares them, and a change of a template reaches them by bringing its files over, keeping only what the runner changes on purpose.
- The runner reaches development servers on the local network, which often serve plain HTTP, so its projects differ from the templates on purpose there: the Android manifest allows cleartext traffic, and the `Info.plist` of iOS and tvOS allows local networking through App Transport Security and explains the access in `NSLocalNetworkUsageDescription`.
- The Apple project is the XcodeGen spec `platform/apple/project.yml` with the generated `App.xcodeproj` committed next to it. After editing `project.yml`, or the plugins or the Apple keys of `app.json`, run `haylen platform xcodegen .` and commit `project.yml` with the generated `App.xcodeproj`.
- The runner has no project for the web, Windows or Linux, so `haylen.py` builds those from copies of the templates.

## Code standard

- Lua files use `dash-case` names, modules are required by the same name, and `source/main.lua` is the entry point. Functions, variables and option keys use `camelCase`, and every string the runner passes to the engine uses the names of the Haylen API.
- Everything the runner creates belongs to an owner: the GUI and the tasks belong to the scene of the home screen, so nothing outlives it.
- Every text the runner shows is a sentence or a label that starts with a capital letter, and reserved expressions in messages, such as `"http://"`, are in double quotes.
- Comments explain intent or context, each one a complete sentence on one line, never what the code says.
- The Swift and Kotlin parts of the plugin follow the plugin template of Haylen (`templates/plugin`), with the `.clang-format` and `.editorconfig` of the repository.

## Commands

The runner builds with the command `haylen` of a checkout of the Haylen repository:

```sh
haylen run .
haylen run . --platform ios-simulator --device <simulator>
haylen run . --platform android --device <serial>
haylen run . --platform web
haylen run . --platform ios --config Release
haylen check . --platform ios --config Release
python3 tools/serve.py <app>
python3 -m unittest discover -s tools -p "test_*.py"
python3 tools/ui-tests.py --platform ios-simulator --device <simulator>
python3 tools/ui-tests.py --platform tvos-simulator --device <simulator>
haylen package <app>
```

The first runs the runner in the desktop player with hot reload. The tool `tools/serve.py` serves another app to the runners of the local network with hot reload through `haylen serve <app>` and prints the QR code of its link, and its tests run with `unittest`. A package to try without hot reload is a Haylen app zipped with its `app.json`, `source/` and `content/` at the root, as `haylen package` writes it, served at an address the device reaches.

## Shipping

- Anyone builds the runner in the Release configuration, which ships it as its protected release, signed with their own Apple team, a free personal team included, and with the upload key of `haylen distribution android-key`, and installs it on their own devices, as `README.md` explains. Publishing it in the App Store and Google Play is optional.
- The apps it plays come from addresses the person gives, so they run with the permissions of the runner, without native access, and nothing of them is bundled.

## Working rules

- A commit message is one short lowercase sentence after a type prefix, `feature: ...`, `fix: ...`, `refactor: ...`, `perf: ...`, `test: ...`, `docs: ...`, `build: ...` or `chore: ...`, with no body and no trailer.
- Before every commit, run the runner on the platforms the change affects and stage nothing private or temporary: build outputs, the `haylen/` folders of the projects, keystores, `local.properties`, logs, screenshots or secrets.
- The repository keeps exactly one commit on `main`, `feature: add haylen runner`, and the version `0.0.1` in `app.json` and in every `plugin.json` until the owner releases `1.0.0`. Every finished change amends that commit and force-pushes `main`. The repository has no tag and no GitHub release.
