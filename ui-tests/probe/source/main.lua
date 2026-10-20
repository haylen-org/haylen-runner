-- The app that the UI tests of the runner open: it shows the text of the module "message", which the tests change while it runs to check the hot reload, whether it reaches native code, which the runner withholds, and a button that quits to the runner.
local haylen = require('haylen')
local log = require('haylen.log')
local scene = require('haylen.scene')
local ui = require('haylen.ui')

local message = require('message')

-- Every way to native code and other programs that an app with native access has.
local function hasNativeAccess()
    return pcall(require, 'ffi') or pcall(require, 'process') or pcall(require, 'haylen.native') or rawget(_G, 'ffi') ~= nil or rawget(_G, 'process') ~= nil or package.loadlib ~= nil or io.popen ~= nil or os.execute ~= nil
end

local access = hasNativeAccess() and 'Native access' or 'No native access'

scene.push({
    enter = function(self)
        self.shown = message.text
        self.gui = ui.mount(ui.column{align = 'center', padding = 32, gap = 16,
            ui.label{id = 'text', text = message.text, font = 'title'},
            ui.label{text = access},
            ui.button{text = 'Quit to the runner', onClick = function() haylen.quit() end},
        }, {owner = self})
        log.info('Probe shows "' .. message.text .. '", launched ' .. tostring(haylen.launched()) .. ', ' .. access:lower() .. '.')
    end,
    update = function(self)
        if message.text ~= self.shown then
            self.shown = message.text
            self.gui:set('text', {text = message.text})
            log.info('Probe shows "' .. message.text .. '".')
        end
    end,
})
