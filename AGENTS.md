# 🧭 Haylen Runner — project guide

Haylen Runner is the player of any [Haylen](https://github.com/haylen-org/haylen) app from the address of its zip file. It is itself a Haylen app written in Lua, with one native plugin that reads QR codes, and it ships in the App Store and Google Play so that anyone tries a Haylen project on a phone, a tablet or a TV without building it for that device. Its home screen takes the address of a zip file, typed, pasted, scanned from a QR code or picked from the addresses opened before, downloads it and plays the app in place of the runner until that app quits.

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

- **Home screen.** `source/main.lua` mounts one GUI in a scene: the Haylen logo, a sentence that says what the runner does, a card with the address field (`keyboard = 'url'`, `returnKey = 'go'`, without autocorrection or capitals), the Open button, the Scan button where a scanner exists, the progress bar and the status line, the list of the addresses opened before with the button that forgets them, and the line of versions of the runner, of Haylen and of the system. The screen updates its components with `gui:set` instead of mounting the GUI again. On tvOS it raises the UI scale for a screen seen from across a room.
- **Addresses.** `source/history.lua` keeps the addresses opened before in `haylen.preferences` under the key `history`, each once, the most recent first, up to a bounded count that the module declares.
- **Download.** `source/download.lua` streams the zip file with `http.client.stream`, reports how much arrived, refuses a body past the limit that the module declares and a status of 400 or more, and saves the file under `haylen.storage` in the folder `apps/`, named after the first characters of the SHA-256 of its address, so the next download of the same address replaces it. Forgetting the addresses deletes that folder too.
- **Launch.** Once the file is saved, `haylen.launch(path)` plays it with a new engine and a new Lua state. The launched app returns to the runner with `haylen.quit()`, the Close button of its error screen, or the back button at its root on Android and Apple TV, and the runner starts again from its own package.
- **QR codes.** The plugin `plugins/qr-scanner/` reads the text of a QR code with the camera through AVFoundation on iPhones, iPads and Mac Catalyst, and through the code scanner of Google Play services on Android phones and tablets. Its Lua API, `require('qr-scanner')`, has `available()`, which is `false` on TVs, desktops and the web, and `scan()`, which returns a platform call that gives `{text}` or fails with `cancelled`, `permissionDenied` or `unsupported`. Its `README.md` documents the whole API and the setup of each platform.

## Repository layout

```text
app.json                  The identity com.haylen.runner, the version, the window, the design size, the UI scale mode, the splash and the plugin with its camera text.
source/main.lua           The home screen and the flow from an address to a launched app.
source/history.lua        The addresses opened before.
source/download.lua       The download of a zip file into the storage of the runner.
content/                  The logo of the splash (logo.png) and the logo and icons of the home screen (images/).
plugins/qr-scanner/       The QR scanner plugin: plugin.json, README.md, the Lua API in source/, the Swift part in apple/ and the Kotlin library module in android/.
platform/apple/           The Xcode project of iOS, iPadOS, Mac Catalyst, tvOS, visionOS and macOS, generated by XcodeGen from project.yml, with its icons.
platform/android/         The Gradle project of Android phones, tablets and TVs, with its icons.
extras/images/            The Haylen symbol that the README shows.
```

The folders `platform/*/haylen/`, which `haylen.py` writes on every build, and the signing keys of `platform/android/keystore/` are gitignored and never committed.

## Platform projects

- The projects of `platform/` belong to the runner and follow the templates of Haylen: `templates/lua/platform/apple` and `templates/common/platform/android`. The command `haylen platform diff . apple` (or `android`) compares them, and a change of a template reaches them by bringing its files over, keeping only what the runner changes on purpose.
- The runner reaches development servers on the local network, which often serve plain HTTP, so its projects differ from the templates on purpose there: the Android manifest allows cleartext traffic and declares `ACCESS_LOCAL_NETWORK`, which Android 17 and later require for addresses of the local network, and the `Info.plist` of iOS and tvOS allows local networking through App Transport Security and explains the access in `NSLocalNetworkUsageDescription`.
- After editing `platform/apple/project.yml`, run `haylen platform xcodegen .` and commit `project.yml` with the generated `App.xcodeproj`.
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
haylen package <app>
```

The first runs the runner in the desktop player with hot reload. A package to try is a Haylen app zipped with its `app.json`, `source/` and `content/` at the root, as `haylen package` writes it, served at an address the device reaches.

## Shipping

- The runner ships to the App Store for iPhone, iPad and Apple TV and to Google Play for Android phones, tablets and TVs, built in the Release configuration, which ships the runner as its protected release.
- The apps it plays come from addresses the person gives, so they run with the permissions of the runner and nothing of them is bundled.

## Working rules

- A commit message is one short lowercase sentence after a type prefix, `feature: ...`, `fix: ...`, `refactor: ...`, `perf: ...`, `test: ...`, `docs: ...`, `build: ...` or `chore: ...`, with no body and no trailer.
- Before every commit, run the runner on the platforms the change affects and stage nothing private or temporary: build outputs, the `haylen/` folders of the projects, keystores, `local.properties`, logs, screenshots or secrets.
- Commit and push to `main` after each finished block of work.
