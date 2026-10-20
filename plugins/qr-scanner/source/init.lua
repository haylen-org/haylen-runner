-- Lua API of the QR Scanner plugin, which an app loads with `require('qr-scanner')`. The camera of iPhones, iPads and Macs reads the code through AVFoundation, and Android devices through the code scanner of Google Play services.
local platform = require('haylen.platform')
local system = require('haylen.system')

local handle = platform.plugin('qr-scanner')
local scanner = {}

-- Returns whether a native part reads codes on this device, which TVs, desktops and browsers lack, Android TVs included, where the native part loads without a camera to read with.
function scanner.available()
    return handle.native and system.info().deviceKind ~= 'tv'
end

-- Shows the camera until it reads a QR code. Returns a platform call, whose `await` gives `{text}`, or fails with the code `cancelled` when the person closes the scanner, `denied` when the person refused the camera and `unsupported` on a device that cannot scan.
function scanner.scan()
    return handle:call('scan', {})
end

return scanner
