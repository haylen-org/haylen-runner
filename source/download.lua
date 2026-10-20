-- Downloads the zip file of an app into the storage of the runner, reporting how much of it arrived, and keeps the logo of the app next to it. It runs inside a coroutine of `async`, whose awaits it makes.
local crypto = require('crypto')
local fs = require('fs')
local http = require('http')
local storage = require('haylen.storage')

local download = {}

download.folder = 'apps'
download.limit = 512 * 1024 * 1024

-- Each address lands in files of its own, named after the hash of the address, which the next download of the same address replaces: the zip file and the logo of the app with the extension of its file.
function download.name(url)
    return crypto.digest('SHA256', url, 'hex'):sub(1, 16)
end

function download.path(url)
    return storage.root() .. '/' .. download.folder .. '/' .. download.name(url) .. '.zip'
end

function download.logoPath(url, extension)
    return storage.root() .. '/' .. download.folder .. '/' .. download.name(url) .. '-logo.' .. extension
end

-- Saves the logo that the package of a downloaded app names, and returns the path of its file, or nil for an app without one.
function download.saveLogo(url, info)
    local extension = info.logo and info.logo:match('%.(%w+)$')
    if not extension then
        return nil
    end
    local path = download.logoPath(url, extension:lower())
    fs.writeFile(path, info.logoBytes):await()
    return path
end

-- Deletes the files of one address. It runs inside a coroutine of `async`, whose awaits it makes.
function download.remove(entry)
    for _, path in ipairs({download.path(entry.url), entry.logo}) do
        if fs.exists(path) then
            fs.removeRecursive(path):await()
        end
    end
end

-- Deletes every downloaded file. It runs inside a coroutine of `async`, whose await it makes.
function download.clear()
    local folder = storage.root() .. '/' .. download.folder
    if fs.exists(folder) then
        fs.removeRecursive(folder):await()
    end
end

-- Writes the file as its pieces arrive, calling `progress(received, total)` with `total` nil when the server does not tell the length, returns its path with the development server that the server names in the header "Haylen-Development-Server", or nil, and raises the reason when the download fails. The file of the address changes only once the new one is whole, and a download that fails or whose task ends leaves no piece of a file behind.
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
    return done.path, done.headers['haylen-development-server']
end

return download
