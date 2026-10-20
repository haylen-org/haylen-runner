# URL Scheme

A Haylen plugin that registers the URL scheme of the app on every platform and hands the app the links of that scheme, such as `haylen-runner://open?url=...`, including the one that launched it. So the camera of the system opens the app from a QR code that holds such a link, and so does a link of another app, of a browser or of a terminal. The engine publishes every link that opens the app as the event `linkOpened`, so the plugin needs no native code: it only declares the scheme to each system. A page is the link that opened it, so on the web the plugin hands the hash of the page address over as a link.

## Platforms

| Platform | Part | Setup |
| --- | --- | --- |
| iOS, iPadOS, Mac Catalyst, tvOS, visionOS, macOS | The `infoPlist` of `plugin.json` | None. The completed `Info.plist` declares the scheme of the parameter `scheme` in `CFBundleURLTypes`. |
| Android | The library module in `android/` | None. Its manifest declares the scheme on `dev.haylen.HaylenLinkActivity` of `dev.haylen:haylen-links`, which hands the link to the running app or to the one that it launches. |
| Windows | The `desktop` section of `plugin.json` | None. The installer registers the scheme for the app under `Software\Classes`, and `haylen run` registers it for the installed app of the build folder. A link starts a new process, which hands it to the app that runs already through its named pipe. |
| Linux | The `desktop` section of `plugin.json` | None. The desktop entry lists the scheme as `x-scheme-handler/<scheme>`, and `haylen run` makes the installed app of the build folder its handler. A link starts a new process, which hands it to the app that runs already through `org.freedesktop.Application` on the session bus. |
| Web | `web/url-scheme.js` | None. The hash of the page address is the query of a link, such as `#url=https%3A%2F%2Fexample.com%2Fapp.zip`, which the module hands to the app with `context.openLink` when the page loads and whenever the hash changes. |

The desktop player that `haylen run` starts with hot reload has no bundle, no registered scheme and no desktop entry, so no link opens it. The apps that `haylen run --platform macos`, `windows` or `linux` builds receive links.

## Parameters

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `scheme` | string | `"haylen-runner"` | The URL scheme of the links that open the app. |

## Lua API

```lua
local urlScheme = require('url-scheme')
```

### urlScheme.scheme()

Returns the scheme of the links that open the app, the value of the parameter `scheme`.

### urlScheme.onOpened(listener, options)

Calls `listener(url)` with the whole text of every link of the scheme that opens the app, and returns the connection of `events.on`. The table `options` takes the options of that function, such as `owner`, which ends the connection with its owner.

The engine publishes the link that launched the app once `source/main.lua` ran, and every later link at the start of the next frame, so the listener that hears the first link connects while `source/main.lua` runs. A link that arrives while an app that this app launched plays ends that app, and this app hears the link once it starts again.

```lua
local scene = require('haylen.scene')
local urlScheme = require('url-scheme')

local home = {}

function home:enter()
    if self.link then
        print('Opened with ' .. self.link)
    end
end

urlScheme.onOpened(function(url)
    home.link = url
end, {owner = home})
scene.push(home)
```
