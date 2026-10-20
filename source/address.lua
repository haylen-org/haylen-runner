-- The addresses the runner opens: the address of a zip file, typed or pasted, or a link of the runner that carries it in its parameter `url`, which the camera of the device, the scanner of the runner and the page of the web hand over.
local urlScheme = require('url-scheme')

local address = {}

-- Returns the address of the zip file that a text names, or nil and the sentence that says what is wrong.
function address.parse(text)
    local trimmed = (text or ''):match('^%s*(.-)%s*$')
    if trimmed:match('^https?://.+') then
        return trimmed
    end
    -- The shell of Windows hands a link over with a slash before its query, as `haylen-runner://open/?url=...`, which names the same link.
    local origin = (urlScheme.scheme() .. '://open'):gsub('%p', '%%%0')
    local query = trimmed:match('^' .. origin .. '/?%?(.*)$')
    if not query then
        return nil, 'Type the address of a zip file, starting with "http://" or "https://".'
    end
    for key, value in query:gmatch('([^&=]+)=([^&]*)') do
        local decoded = value:gsub('%+', ' '):gsub('%%(%x%x)', function(hex)
            return string.char(tonumber(hex, 16))
        end)
        if key == 'url' and decoded:match('^https?://.+') then
            return decoded
        end
    end
    return nil, 'The link names no address of a zip file in its parameter "url".'
end

-- Returns whether the server of an address is on the local network, such as the computer of a developer, which Android 17 lets the runner reach only once the person grants it.
function address.isLocal(url)
    local bracketed = url:match('^https?://%[([^%]]+)%]')
    if bracketed then
        local lower = bracketed:lower()
        return lower:match('^f[cd]') ~= nil or lower:match('^fe[89ab]') ~= nil
    end
    local host = (url:match('^https?://([^/:?#]+)') or ''):lower()
    local first, second = host:match('^(%d+)%.(%d+)%.%d+%.%d+$')
    if not first then
        return host:match('%.local$') ~= nil
    end
    first, second = tonumber(first), tonumber(second)
    return first == 10 or (first == 172 and second >= 16 and second <= 31) or (first == 192 and second == 168) or (first == 169 and second == 254)
end

return address
