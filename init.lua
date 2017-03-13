
JIS_LEFT_BRACKET_CODE = 30
JIS_RIGHT_BRACKET_CODE = 42

local function info(message)
    -- hs.alert.show(message)
end

local function getTableLength(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

local function isEqualTable(t1, t2)
    if getTableLength(t1) ~= getTableLength(t2) then return false end
    for k, v in pairs(t1) do
        if t2[k] ~= v then
            return false
        end
    end
    return true
end

local function disableAll(keySet)
    for k, v in pairs(keySet) do v:disable() end
end

local function enableAll(keySet)
    for k, v in pairs(keySet) do v:enable() end
end

local function pressKey(modifiers, key)
    modifiers = modifiers or {}
    hs.eventtap.keyStroke(modifiers, key, 20 * 1000)
end

local function pressKeyFunc(modifiers, key)
    return function() pressKey(modifiers, key) end
end

local function createKeyRemap(srcModifiers, srcKey, dstModifiers, dstKey)
    dstFunc = function() pressKey(dstModifiers, dstKey) end
    return hs.hotkey.new(srcModifiers, srcKey, dstFunc, nil, dstFunc)
end

SubMode = {}
SubMode.new = function(name, commandTable, othersFunc)
    local obj = {}
    obj.name = name
    obj.commandTable = commandTable
    obj.othersFunc = othersFunc
    obj.commandWatcher = {}
    obj.enable = function(self)
        info(self.name.." start")
        self.commandWatcher:start()
    end

    obj.disable = function(self)
        info(self.name.." end")
        self.commandWatcher:stop()
    end

    obj.commandWatcher = hs.eventtap.new( {hs.eventtap.event.types.keyDown},
        function(tapEvent)
            for k,v in pairs(obj.commandTable) do
                if v.key == hs.keycodes.map[tapEvent:getKeyCode()] and isEqualTable(v.modifiers, tapEvent:getFlags()) then
                    info(obj.name.." end")
                    obj.commandWatcher:stop()
                    if v.func then
                        v.func()
                    end
                    return true
                end
            end

            if obj.othersFunc then
                return othersFunc(tapEvent)
            end
        end)
    return obj
end


markMode = SubMode.new(
    "Mark Mode",
    {
        {modifiers = {ctrl = true}, key = 'space'}, -- only disables mark mode
        {modifiers = {ctrl = true}, key = 'g'}, -- only disables mark mode
        {modifiers = {ctrl = true}, key = 'w', func = pressKeyFunc({'cmd'}, 'x')},
        {modifiers = {alt = true},  key = 'w', func = pressKeyFunc({'cmd'}, 'c')}
    },

    function(tapEvent) -- force shift on
        flags = tapEvent:getFlags()
        flags.shift = true
        tapEvent:setFlags(flags)
        return false
    end
)

xcodeBindings = {
    -- mark mode
    hs.hotkey.new({'ctrl'}, 'space', function() markMode:enable() end),

    -- etc
    -- jump to beginning/end of document
    createKeyRemap({'alt', 'shift'}, ',', {'cmd'}, 'up'),
    createKeyRemap({'alt', 'shift'}, '.', {'cmd'}, 'down'),

    -- move to up/down of line. for popup window
    createKeyRemap({'ctrl'}, 'p', {}, 'up'),
    createKeyRemap({'ctrl'}, 'n', {}, 'down'),

    -- undo
    createKeyRemap({'ctrl'}, '/', {'cmd'}, 'z'),

    -- search
    createKeyRemap({'ctrl'}, 's', {'cmd'}, 'f'),

    -- paste
    createKeyRemap({'ctrl'}, 'y', {'cmd'}, 'v'),

    -- cut
    createKeyRemap({'ctrl'}, 'w', {'cmd'}, 'x'),

    -- newline
    createKeyRemap({'ctrl'}, 'm', {}, 'return'),

    -- kill line
    hs.hotkey.new({'ctrl'}, 'k', function()
        markMode:enable()
        pressKey({'ctrl'}, 'e')
        pressKey({'ctrl'}, 'w')
    end),
}

local function handleGlobalAppEvent(name, event, app)
   if event == hs.application.watcher.activated then
      -- hs.alert.show(name)
      if name ~= "iTerm2" and name ~="PyCharm" and name ~="MacVim" then
         enableAll(xcodeBindings)
      else
        disableAll(xcodeBindings)
        markMode:disable()
        commandMode:disable()
      end
   end
end    

-- for debug

local function showKeyPress(tapEvent)
    local code = tapEvent:getKeyCode()
    local charactor = hs.keycodes.map[tapEvent:getKeyCode()]
    hs.alert.show(tostring(code)..":"..charactor, 1.5)
end

local keyTap = hs.eventtap.new( {hs.eventtap.event.types.keyDown}, showKeyPress)

k = hs.hotkey.modal.new({"cmd", "shift", "ctrl"}, 'P')

function k:entered()
    hs.alert.show("Enabling Keypress Show Mode", 1.5)
    keyTap:start()
end

function k:exited()
    hs.alert.show("Disabling Keypress Show Mode", 1.5)
end

k:bind({"cmd", "shift", "ctrl"}, 'P', function()
    keyTap:stop()
    k:exit()
end)

appsWatcher = hs.application.watcher.new(handleGlobalAppEvent)
appsWatcher:start()
