# QR Scanner

A Haylen plugin that reads the text of a QR code with the camera of the device. iPhones, iPads and Macs read the code through AVFoundation, and Android devices through the code scanner of Google Play services, which brings its own screen and needs no camera permission of the app. TVs, desktops and browsers have no scanner, so `available()` returns `false` there. The plugin owns the permission `camera`, which the app reads and asks for with `system.permission('camera')` and `system.requestPermission('camera')`.

## Platforms

| Platform | Native part | Setup |
| --- | --- | --- |
| iOS, iPadOS, Mac Catalyst | `apple/QrScannerPlugin.swift` | None. The completed `Info.plist` takes the camera usage description from the parameter `cameraUsage`, which the prompt of the permission `camera` shows. |
| Android | The library module in `android/` | None. The module depends on `com.google.android.gms:play-services-code-scanner`, and a device without Google Play services fails the scan with the code `unsupported`. The scanner needs no permission of the app, so the permission `camera` is `granted`. |

## Parameters

| Parameter | Type | Default | Meaning |
| --- | --- | --- | --- |
| `cameraUsage` | string | `"Haylen Runner reads the address of an app from a QR code."` | Text of the camera permission prompt on Apple platforms. |

## Lua API

```lua
local scanner = require('qr-scanner')
```

### scanner.available()

Returns whether a native part reads codes on this device.

### scanner.scan()

Shows the camera until it reads a QR code. Returns a platform call, whose `await` gives `{text}`, or `nil` and the error of the call, with the code `cancelled` when the person closes the scanner, `denied` when the person refused the camera and `unsupported` on a device that cannot scan. A scan asks for the permission `camera` first while its state is `prompt`, with the prompt of the system.

```lua
local async = require('async')
local scanner = require('qr-scanner')

async.spawn(function()
    if scanner.available() then
        local result, err = scanner.scan():await()
        print(result and result.text or err.message)
    end
end)
```

## Permissions

| Platform | `camera` |
| --- | --- |
| iOS, iPadOS, Mac Catalyst | The authorization of AVFoundation: `prompt` until the person answers, then `granted` or `denied`. |
| Android | `granted`, since the scanner of Google Play services reads codes in its own screen. |
| tvOS, visionOS, macOS, web, Windows, Linux | `unsupported`, since the plugin reads no codes there. |

## Native API

| Method | Params | Answer |
| --- | --- | --- |
| `qr-scanner.scan` | `{}` | `{text}` |
