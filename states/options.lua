local state = {}
local self = state

local function save()
    print("Saving player data")

    local savedData = {}
    for _,opt in ipairs(self.options) do
        if type(opt.value) ~= "function" then
            savedData[opt.name] = opt.value
        end
    end

    local dataString = json.encode(savedData)

    love.filesystem.write("settings.json", dataString)
    if love.filesystem.getInfo("settings.json") then
        print("Settings saved succesfully")
    else
        love.system.setClipboardText(dataString)
        print("Error! Could not save  data!")
        print("Settings copied to clipboard")
    end
end

local function load()
    if love.filesystem.getInfo("settings.json") then
        print("Loading settings data")

        local dataString = love.filesystem.read("settings.json")
        self.loadedSettings = json.decode(dataString)

        print("Loaded settings data")
    else
        print("settings not found")
    end
end

function self:checkPersistentOptions()
    if self.options then
        for _,opt in ipairs(self.options) do
            if opt.name == "Vsync" then
                if opt.value == 1 then
                    love.window.setMode(love.graphics:getWidth(),love.graphics:getHeight(),{vsync = 0})
                elseif opt.value == 2 then
                    love.window.setMode(love.graphics:getWidth(),love.graphics:getHeight(),{vsync = 1})
                else
                    love.window.setMode(love.graphics:getWidth(),love.graphics:getHeight(),{vsync = -1})
                end
            end
        end
    end
end

function self:checkOptions()
    if self.options then
        for _,opt in ipairs(self.options) do
            if opt.name == "Fullscreen" then
                love.window.setFullscreen(opt.value)
            elseif opt.name == "Master Volume" then
                love.audio.setVolume(opt.value)
            elseif opt.name == "Antialiasing" then
                if opt.value == true then
                    love.graphics.setDefaultFilter("linear","linear")
                else
                    love.graphics.setDefaultFilter("nearest", "nearest")
                end
            end
        end
        loadSettings(self.options)
    end
end

function self:load()
    load()

    -- Font
    self.font = love.graphics.newFont(24)
    love.graphics.setFont(self.font)

    -- Menu options
    self.options = self.options or {
        { name = "Master Volume", value = 1.0 },
        { name = "Antialiasing", value = false },
        { name = "Fullscreen", value = false },
        { name = "Show FPS", value = false },
        { name = "Vsync", value = 1.0 },
        { name = "Keybinds", action = function() print("Open keybinds menu") end },
        { name = "Back", action = function() Utils:goBack("menu") end },
    }

    if self.loadedSettings then
        for index,val in ipairs(self.options) do
            if self.loadedSettings[val.name] then
                self.options[index] = {name = val.name, value = self.loadedSettings[val.name]}
            end
        end
    end

    self:checkOptions()
    if not settingsLoaded then
        self:checkPersistentOptions()
        settingsLoaded = true
    end

    self.selected = 1
end

function self:update(dt)
    -- Nothing animated for now, but you could add sliders, etc.
end

function self:draw()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.printf("OPTIONS", 0, 60, love.graphics.getWidth(), "center")

    for i, opt in ipairs(self.options) do
        local y = 150 + (i - 1) * 40
        if i == self.selected then
            love.graphics.setColor(1, 1, 0) -- Highlight color
        else
            love.graphics.setColor(1, 1, 1)
        end

        -- Format value display
        local valueText = ""
        if opt.value ~= nil then
            if type(opt.value) == "boolean" then
                valueText = opt.value and "ON" or "OFF"
            else
                valueText = tostring(opt.value)
            end
        end

        love.graphics.printf(opt.name .. "  " .. valueText, 0, y, love.graphics.getWidth(), "center")
    end
end

function self:keypressed(key)
    if key == "escape" then
        save()
        Utils:goBack("menu")
    elseif key == "up" then
        self.selected = self.selected - 1
        if self.selected < 1 then
            self.selected = #self.options
        end
    elseif key == "down" then
        self.selected = self.selected + 1
        if self.selected > #self.options then
            self.selected = 1
        end
    elseif key == "return" or key == "space" then
        local opt = self.options[self.selected]
        if opt.value ~= nil then
            if type(opt.value) == "boolean" then
                opt.value = not opt.value
                self:checkOptions()

            elseif type(opt.value) == "number" then
                if opt.name == "Master Volume" then
                    -- Example: toggle between 0.0, 0.5, 1.0
                    if opt.value == 1 then opt.value = 0
                    elseif opt.value == 0 then opt.value = 0.5
                    else opt.value = 1 end
                elseif opt.name == "Vsync" then
                    opt.value = opt.value + 1
                    if opt.value > 3 then
                        opt.value = 1
                    end
                    self:checkPersistentOptions()
                    return
                end
                self:checkOptions()

            end
            save()
        elseif opt.action then
            save()
            opt.action()
        end
    end
end

return self