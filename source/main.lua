-- The home screen of Haylen Runner: the logo, a field for the address of the zip file of an app, a button that scans the address from a QR code, the addresses opened before and the versions of the runner, of Haylen and of the system. Opening an address downloads the zip file and launches the app in place of the runner, and the runner comes back when that app quits.
local haylen = require('haylen')
local scene = require('haylen.scene')
local system = require('haylen.system')
local ui = require('haylen.ui')

local download = require('download')
local history = require('history')
local scanner = require('qr-scanner')

local Home = {}
Home.__index = Home

Home.systems = {macos = 'macOS', windows = 'Windows', linux = 'Linux', ios = 'iOS', tvos = 'tvOS', android = 'Android', web = 'Web'}

-- Returns the line of versions at the bottom of the screen.
function Home.versions()
    local info = system.info()
    local name = Home.systems[haylen.platform] or haylen.platform
    return string.format('Runner %s, Haylen %s, %s %s', haylen.config.version, haylen.version, name, info.osVersion or '')
end

-- Returns the rows of the addresses opened before, newest first, each named after its file with the whole address under the name.
function Home.rows()
    local rows = {}
    for _, url in ipairs(history.list()) do
        rows[#rows + 1] = {id = url, text = url:match('([^/?#]+)[?#]?[^/]*$') or url, caption = url, image = 'images/clock.svg'}
    end
    return rows
end

function Home:enter()
    -- Apple TV lays the screen out in the points of a screen seen from across a room, so it draws larger there, while Android TVs already pick a density for that distance.
    if haylen.platform == 'tvos' then
        ui.setScale(1.6)
    end
    self.url = history.list()[1] or ''
    -- Devices without a camera, such as TVs and desktops, leave the scanner out.
    local actions = {gap = 12, wrap = true, ui.button{id = 'open', text = 'Open', variant = 'primary', grow = 1, minWidth = 200, onClick = function() self:open(self.url) end}}
    if scanner.available() then
        actions[#actions + 1] = ui.button{id = 'scan', text = 'Scan a QR code', icon = 'images/qr.svg', grow = 1, minWidth = 200, onClick = function() self:scan() end}
    end
    self.gui = ui.mount(ui.scroll{
        ui.column{maxWidth = 820, align = 'center', padding = 32, gap = 20,
            ui.image{image = 'images/logo.svg', height = 96, align = 'center'},
            ui.label{text = 'Run a Haylen app from the address of its zip file.', color = 'textMuted', align = 'stretch', textAlign = 'center'},
            ui.card{
                ui.column{gap = 14,
                    ui.textField{id = 'url', value = self.url, placeholder = 'https://example.com/app.zip', keyboard = 'url', returnKey = 'go', autocorrect = false, autocapitalize = 'none',
                        onChange = function(event) self.url = event.value end,
                        onSubmit = function(event) self:open(event.value) end},
                    ui.row(actions),
                    ui.progress{id = 'progress', value = 0, visible = false},
                    ui.label{id = 'status', text = '', color = 'textMuted', visible = false},
                },
            },
            ui.sectionTitle{id = 'recentTitle', text = 'Opened before', visible = #history.list() > 0},
            ui.list{id = 'history', items = Home.rows(), onSelect = function(event) self:choose(event.item) end},
            ui.button{id = 'clear', text = 'Forget the addresses', variant = 'link', visible = #history.list() > 0, onClick = function() self:forget() end},
            ui.label{id = 'versions', text = Home.versions(), font = 'caption', color = 'textMuted', align = 'stretch', textAlign = 'center'},
        },
    }, {owner = self})
end

function Home:refresh()
    local opened = #history.list() > 0
    self.gui:set('history', {items = Home.rows()})
    self.gui:set('recentTitle', {visible = opened})
    self.gui:set('clear', {visible = opened})
end

function Home:say(text, tone)
    self.gui:set('status', {text = text, color = tone == 'error' and 'dangerText' or 'textMuted', visible = text ~= ''})
end

-- An address from the list goes into the field and opens.
function Home:choose(url)
    self.url = url
    self.gui:set('url', {value = url})
    self:open(url)
end

-- Forgets the addresses and deletes the zip files they downloaded.
function Home:forget()
    for _, url in ipairs(history.list()) do
        history.remove(url)
    end
    self:refresh()
    scene.spawn(self, download.clear)
end

-- Downloads the zip file of the address with its progress, keeps the address in the list and launches the app.
function Home:open(text)
    local url = (text or ''):match('^%s*(.-)%s*$')
    if not url:match('^https?://.+') then
        self:say('Type the address of a zip file, starting with "http://" or "https://".', 'error')
        return
    end
    if self.busy then
        return
    end
    self.busy = true
    history.add(url)
    self:refresh()
    self.gui:set('open', {enabled = false})
    self.gui:set('progress', {visible = true, value = 0})
    self:say('Downloading the app.')
    scene.spawn(self, function()
        local ok, result = pcall(download.fetch, url, function(received, total)
            self.gui:set('progress', {value = total and total > 0 and received / total or 0})
            self:say(total and string.format('Downloading the app, %.1f of %.1f MB.', received / 1048576, total / 1048576) or string.format('Downloading the app, %.1f MB.', received / 1048576))
        end)
        self.busy = false
        self.gui:set('open', {enabled = true})
        self.gui:set('progress', {visible = false})
        if not ok then
            self:say(tostring(result), 'error')
            return
        end
        self:say('Starting the app.')
        haylen.launch(result)
    end)
end

-- Reads the address from a QR code with the camera and opens it.
function Home:scan()
    scene.spawn(self, function()
        local result, failure = scanner.scan():await()
        if result then
            self.url = result.text
            self.gui:set('url', {value = result.text})
            self:open(result.text)
        elseif failure and failure.code ~= 'cancelled' then
            self:say(failure.message, 'error')
        end
    end)
end

scene.push(setmetatable({}, Home))
