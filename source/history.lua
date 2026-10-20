-- The apps the runner opened, each once, from the most recent to the oldest, kept in the preferences of the app between runs. Each entry holds the address of its zip file, the name of the app and the file of its logo once a download read them, and when it was last opened.
local preferences = require('haylen.preferences')

local history = {}

history.key = 'opened'
history.limit = 30

function history.list()
    return preferences.get(history.key, {})
end

function history.find(url)
    for _, entry in ipairs(history.list()) do
        if entry.url == url then
            return entry
        end
    end
    return nil
end

-- Moves the entry of the address to the top of the list with the fields given, keeping the ones it had, or puts a new one there, and forgets the oldest past the limit.
function history.add(url, fields)
    local entry = history.find(url) or {url = url}
    for key, value in pairs(fields or {}) do
        entry[key] = value
    end
    entry.opened = os.time()
    local list = {entry}
    for _, other in ipairs(history.list()) do
        if other.url ~= url and #list < history.limit then
            list[#list + 1] = other
        end
    end
    preferences.set(history.key, list)
    preferences.save()
    return entry
end

-- Updates the fields of the entry of an address where it stands in the list.
function history.update(url, fields)
    local list = history.list()
    for _, entry in ipairs(list) do
        if entry.url == url then
            for key, value in pairs(fields) do
                entry[key] = value
            end
        end
    end
    preferences.set(history.key, list)
    preferences.save()
end

function history.remove(url)
    local list = {}
    for _, entry in ipairs(history.list()) do
        if entry.url ~= url then
            list[#list + 1] = entry
        end
    end
    preferences.set(history.key, list)
    preferences.save()
end

function history.clear()
    preferences.set(history.key, {})
    preferences.save()
end

return history
