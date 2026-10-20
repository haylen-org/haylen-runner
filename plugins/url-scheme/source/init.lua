-- Lua API of the URL Scheme plugin, which an app loads with `require('url-scheme')`. The engine publishes the links that open the app as `linkOpened`, which on the web the web part of the plugin hands over from the hash of the page address.
local events = require('haylen.events')
local platform = require('haylen.platform')

local handle = platform.plugin('url-scheme')
local urlScheme = {}

-- Returns the scheme of the links that open the app.
function urlScheme.scheme()
    return handle.config.scheme
end

-- Calls `listener(url)` with every link of the scheme that opens the app, and returns the connection, which ends with the owner of `options`. The engine publishes the link that launched the app once `source/main.lua` ran, so the listener that hears it connects while that script runs.
function urlScheme.onOpened(listener, options)
    local prefix = handle.config.scheme:lower() .. ':'
    return events.on('linkOpened', function(event)
        if event.url:sub(1, #prefix):lower() == prefix then
            listener(event.url)
        end
    end, options)
end

return urlScheme
