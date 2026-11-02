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

-- Calls `progress(received, total)` as the pieces arrive, with `total` nil when the server does not tell the length, and raises the reason when the download fails.
function download.fetch(url, progress)
    local chunks, received, total, status = {}, 0, nil, 0
    local _, failure = http.client.stream({
        url = url,
        timeoutSeconds = 600,
        maxResponseBytes = download.limit,
        onResponse = function(code, headers)
            status = code
            total = tonumber(headers['content-length'])
        end,
    }, function(chunk)
        chunks[#chunks + 1] = chunk
        received = received + #chunk
        progress(received, total)
    end):await()
    if failure then
        error(string.format('The download of "%s" failed: %s', url, tostring(failure)), 0)
    end
    if status >= 400 then
        error(string.format('The server answered %d for "%s".', status, url), 0)
    end
    local path = download.path(url)
    fs.mkdir(storage.root() .. '/' .. download.folder):await()
    fs.writeFile(path, table.concat(chunks)):await()
    return path
end

return download
