-- The home screen of Haylen Runner: the logo, a field for the address of the zip file of an app, a button that scans the address from a QR code, the apps opened before with their names and logos, and the versions of the runner, of Haylen and of the system. Opening an address, or a link of the runner, downloads the zip file and launches the app in place of the runner, in development when its server names a development server, and the runner comes back when that app quits.
local fs = require('fs')
local graphics = require('haylen.graphics')
local haylen = require('haylen')
local scene = require('haylen.scene')
local system = require('haylen.system')
local ui = require('haylen.ui')

local address = require('address')
local download = require('download')
local history = require('history')
local scanner = require('qr-scanner')
local urlScheme = require('url-scheme')

local Home = {}
Home.__index = Home

Home.systems = {macos = 'macOS', windows = 'Windows', linux = 'Linux', ios = 'iOS', tvos = 'tvOS', android = 'Android', web = 'Web'}

-- How the person comes back to the runner from a running app on each kind of device, as the engine offers it to every launched app.
Home.ways = {
    tv = 'Hold play and pause on the remote to come back here from a running app.',
    android = 'Hold back, or three fingers on the screen, to come back here from a running app.',
    ios = 'Hold three fingers on the screen, or Escape on a keyboard, to come back here from a running app.',
}
Home.way = 'Hold Escape to come back here from a running app.'
-- A TV starts with the focus on the Open button, under the address that the remote moves up to.
Home.tv = system.info().deviceKind == 'tv'

-- Returns the line of versions at the bottom of the screen.
function Home.versions()
    local info = system.info()
    local name = Home.systems[haylen.platform] or haylen.platform
    return string.format('Runner %s, Haylen %s, %s %s', haylen.config.version, haylen.version, name, info.osVersion or '')
end

-- Returns when an app was opened, the way the list shows it.
function Home.ago(time)
    local seconds = math.max(0, os.time() - (time or os.time()))
    if seconds < 60 then
        return 'Opened just now'
    end
    for _, unit in ipairs({{86400, 'day'}, {3600, 'hour'}, {60, 'minute'}}) do
        local count = seconds // unit[1]
        if count >= 1 and (unit[2] ~= 'day' or count < 30) then
            return string.format('Opened %d %s%s ago', count, unit[2], count == 1 and '' or 's')
        end
    end
    return os.date('Opened on %Y-%m-%d', time)
end

-- Returns the name of an app for its address before a download read the name of its package.
function Home.fileName(url)
    return url:match('([^/?#]+)[?#]?[^/]*$') or url
end

function Home:enter()
    -- Apple TV lays the screen out in the points of a screen seen from across a room, so it draws larger there, while Android TVs already pick a density for that distance.
    if haylen.platform == 'tvos' then
        ui.setScale(1.6)
    end
    self.logos = {}
    local last = history.list()[1]
    self.url = last and last.url or ''
    -- Devices without a camera, such as TVs and desktops, leave the scanner out.
    local actions = {gap = 12, wrap = true, ui.button{id = 'open', text = 'Open', variant = 'primary', grow = 1, minWidth = 200, autofocus = Home.tv, onClick = function() self:open(self.url) end}}
    if scanner.available() then
        actions[#actions + 1] = ui.button{id = 'scan', text = 'Scan a QR code', icon = 'images/qr.svg', grow = 1, minWidth = 200, onClick = function() self:scan() end}
    end
    self.gui = ui.mount(ui.scroll{
        ui.column{maxWidth = 820, align = 'center', padding = 32, gap = 20,
            ui.image{image = 'images/logo.svg', height = 96, align = 'center'},
            ui.label{text = 'Run a Haylen app from the address of its zip file, from a QR code or from a link of the runner.', color = 'textMuted', align = 'stretch', textAlign = 'center'},
            ui.card{
                ui.column{gap = 14,
                    ui.textField{id = 'url', value = self.url, placeholder = 'https://example.com/app.zip', accessibilityLabel = 'Address of the app', keyboard = 'url', returnKey = 'go', autocorrect = false, autocapitalize = 'none',
                        onChange = function(event) self.url = event.value end,
                        onSubmit = function(event) self:open(event.value) end},
                    ui.row(actions),
                    ui.progress{id = 'progress', value = 0, visible = false},
                    ui.label{id = 'status', text = '', color = 'textMuted', visible = false},
                },
            },
            ui.label{text = Home.ways[Home.tv and 'tv' or haylen.platform] or Home.way, font = 'caption', color = 'textMuted', align = 'stretch', textAlign = 'center'},
            ui.sectionTitle{id = 'recentTitle', text = 'Opened before', visible = false},
            ui.column{id = 'history', gap = 8, align = 'stretch'},
            ui.button{id = 'clear', text = 'Clear the list', variant = 'link', visible = false, onClick = function() self:clear() end},
            ui.label{id = 'versions', text = Home.versions(), font = 'caption', color = 'textMuted', align = 'stretch', textAlign = 'center'},
        },
    }, {owner = self})
    self:refresh()
    scene.spawn(self, function()
        for _, entry in ipairs(history.list()) do
            self:loadLogo(entry)
        end
        self:refresh()
    end)
    local link = self.link
    self.link = nil
    if link then
        self:choose(link)
    end
end

-- Gives the logo file of an entry a name of the UI, so its row shows it. A file that is gone or not an image leaves the row with the picture of any app. It runs inside the task of the screen.
function Home:loadLogo(entry)
    if not entry.logo or not fs.exists(entry.logo) then
        return
    end
    local bytes = fs.readFile(entry.logo):await()
    local ok, image = pcall(function()
        return entry.logo:match('%.svg$') and graphics.newVectorImage(bytes) or graphics.newTexture(bytes, {filter = 'linear'})
    end)
    if ok then
        local name = '@app-' .. download.name(entry.url)
        ui.setImage(name, image)
        self.logos[entry.url] = name
    end
end

-- Builds the rows of the apps opened before, newest first: the logo, the name, the address and when it was opened, and a button that removes the row.
function Home:refresh()
    local entries = history.list()
    local rows = {}
    for index, entry in ipairs(entries) do
        local name = entry.name or Home.fileName(entry.url)
        rows[#rows + 1] = ui.row{gap = 8, align = 'stretch',
            ui.list{id = 'entry' .. index, grow = 1,
                items = {{id = entry.url, text = name, caption = Home.ago(entry.opened) .. ', ' .. entry.url, image = self.logos[entry.url] or 'images/app.svg'}},
                onSelect = function() self:choose(entry.url) end},
            ui.button{id = 'remove' .. index, icon = 'images/remove.svg', variant = 'icon', tooltip = 'Remove', accessibilityLabel = 'Remove ' .. name, onClick = function() self:remove(entry) end},
        }
    end
    self.gui:replaceChildren('history', rows)
    self.gui:set('recentTitle', {visible = #entries > 0})
    self.gui:set('clear', {visible = #entries > 0})
end

function Home:say(text, tone)
    self.gui:set('status', {text = text, color = tone == 'error' and 'dangerText' or 'textMuted', visible = text ~= ''})
end

-- An address from the list or a link goes into the field and opens. A link that arrives before the screen shows waits for it.
function Home:choose(url)
    if not self.gui then
        self.link = url
        return
    end
    self.url = url
    self.gui:set('url', {value = url})
    self:open(url)
end

-- Forgets one app and deletes its files.
function Home:remove(entry)
    history.remove(entry.url)
    self:refresh()
    local name = self.logos[entry.url]
    if name then
        self.logos[entry.url] = nil
        ui.removeImage(name)
    end
    scene.spawn(self, function()
        download.remove(entry)
    end)
end

-- Forgets every app and deletes the files they downloaded.
function Home:clear()
    history.clear()
    self:refresh()
    for _, name in pairs(self.logos) do
        ui.removeImage(name)
    end
    self.logos = {}
    scene.spawn(self, download.clear)
end

-- Downloads the zip file that a text names with its progress, keeps the app in the list with its name and logo and launches it.
function Home:open(text)
    local url, problem = address.parse(text)
    if not url then
        self:say(problem, 'error')
        return
    end
    if self.busy then
        return
    end
    self.busy = true
    self.url = url
    self.gui:set('url', {value = url})
    history.add(url)
    self:refresh()
    self.gui:set('open', {enabled = false})
    self.gui:set('progress', {visible = true, value = 0})
    scene.spawn(self, function()
        local ok, path, server = pcall(self.fetch, self, url)
        self.busy = false
        self.gui:set('open', {enabled = true})
        self.gui:set('progress', {visible = false})
        if not ok then
            self:say(tostring(path), 'error')
            return
        end
        self:say('Starting the app.')
        haylen.launch(path, {developmentServer = server, nativeAccess = false})
    end)
end

-- Asks for the local network when the server is on it, downloads the zip file, reads the name and the logo of its app and returns its path with the development server that the server names. It runs inside the task of the screen, and raises the reason when it fails.
function Home:fetch(url)
    if address.isLocal(url) then
        self:say('Asking for the access to the local network.')
        local state, failure = system.requestPermission('localNetwork'):await()
        if failure then
            error(failure.message, 0)
        end
        if state == 'denied' then
            error('The runner reaches the server of this address only with the access to the local network, which the settings of the system grant.', 0)
        end
    end
    self:say('Downloading the app.')
    local path, server = download.fetch(url, function(received, total)
        self.gui:set('progress', {value = total and total > 0 and received / total or 0})
        self:say(total and string.format('Downloading the app, %.1f of %.1f MB.', received / 1048576, total / 1048576) or string.format('Downloading the app, %.1f MB.', received / 1048576))
    end)
    local info, failure = haylen.packageInfo(path):await()
    if not info then
        error(tostring(failure), 0)
    end
    history.update(url, {name = info.name, logo = download.saveLogo(url, info)})
    return path, server
end

-- Reads the address from a QR code with the camera and opens it.
function Home:scan()
    scene.spawn(self, function()
        local result, failure = scanner.scan():await()
        if result then
            self:choose(result.text)
        elseif failure and failure.code ~= 'cancelled' then
            self:say(failure.message, 'error')
        end
    end)
end

local home = setmetatable({}, Home)
-- A link of the runner, such as the one of a QR code that the camera of the device read, opens like a typed address. The link that launched the runner arrives once this script ran, before the home screen enters.
urlScheme.onOpened(function(url)
    home:choose(url)
end, {owner = home})
scene.push(home)
