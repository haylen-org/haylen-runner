-- Downloads the zip file of an app into the storage of the runner, reporting how much of it arrived, and returns the path of the file. It runs inside a coroutine of `async`, whose awaits it makes.
local crypto = require('crypto')
local fs = require('fs')
local http = require('http')
local storage = require('haylen.storage')

local download = {}

download.folder = 'apps'
download.limit = 512 * 1024 * 1024

-- Each address lands in a file of its own, named after the hash of the address, which the next download of the same address replaces.
function download.path(url)
    return storage.root() .. '/' .. download.folder .. '/' .. crypto.digest('SHA256', url, 'hex'):sub(1, 16) .. '.zip'
end

-- Deletes every downloaded zip file. It runs inside a coroutine of `async`, whose await it makes.
function download.clear()
    local folder = storage.root() .. '/' .. download.folder
    if fs.exists(folder) then
        fs.removeRecursive(folder):await()
    end
end

-- Writes the file as its pieces arrive, calling `progress(received, total)` with `total` nil when the server does not tell the length, and raises the reason when the download fails. The file of the address changes only once the new one is whole, and a download that fails or whose task ends leaves no piece of a file behind.
function download.fetch(url, progress)
    local scope <close> = http.client.controller()
    local done, failure = http.client.download({
        url = url,
        path = download.path(url),
        timeoutSeconds = 600,
        maxResponseBytes = download.limit,
        controller = scope,
        onProgress = progress,
    }):await()
    if not done then
        error(string.format('The download of "%s" failed: %s', url, tostring(failure)), 0)
    end
    return done.path
end

return download
