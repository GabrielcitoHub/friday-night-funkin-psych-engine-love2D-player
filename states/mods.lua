local state = {}
local self = state
self.imagesFolder = Utils:getPath("images")

function self:load()
    sprm:makeLuaSprite("bg", self.imagesFolder .. "menuDesat")
    sprm:centerObject("bg")

    self.mods = Utils:loadMods()
    self.selectedIndex = 1
    self.scrollOffset = 0

    self.font = love.graphics.newFont(20)
end

function self:keypressed(key)
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")

    if key == "escape" then
        Utils:saveModsOrder(self.mods)
        love.graphics.setColor(1, 1, 1, 1)
        Utils:goBack("menu")

    elseif (key == "down" or key == "s") and not ctrl then
        -- normal scrolling
        self.selectedIndex = (self.selectedIndex % #self.mods) + 1

    elseif (key == "up" or key == "w") and not ctrl then
        -- normal scrolling
        self.selectedIndex = (self.selectedIndex - 2) % #self.mods + 1

    elseif ctrl and (key == "down" or key == "s") then
        -- reorder: move selected mod down
        if self.selectedIndex < #self.mods then
            local i = self.selectedIndex
            self.mods[i], self.mods[i + 1] = self.mods[i + 1], self.mods[i]
            self.selectedIndex = i + 1
            Utils:saveModsOrder(self.mods)
        end

    elseif ctrl and (key == "up" or key == "w") then
        -- reorder: move selected mod up
        if self.selectedIndex > 1 then
            local i = self.selectedIndex
            self.mods[i], self.mods[i - 1] = self.mods[i - 1], self.mods[i]
            self.selectedIndex = i - 1
            Utils:saveModsOrder(self.mods)
        end

    elseif key == "return" or key == "space" then
        -- toggle active/inactive
        local mod = self.mods[self.selectedIndex]
        mod.active = not mod.active
        soundManager:playSound("clickText",nil,{new = true})
        Utils:saveModsOrder(self.mods)
        
    end

    if key == "up" or key == "down" or key == "w" or key == "s" then
        if ctrl then
            soundManager:playSound("Metronome_Tick",nil,{new = true})
        else
            soundManager:playSound("scrollMenu",nil,{new = true})
        end
    end
end

function self:draw()
    love.graphics.setFont(self.font)

    local startY = 200
    local spacing = 60

    -- Draw mod info panel (for selected mod)
    local selected = self.mods[self.selectedIndex]
    if selected then
        local meta = selected.meta or {}
        local color = selected.meta.color

        if color then
            love.graphics.setColor(color[1] / 255, color[2] / 255, color[3] / 255, 1)
            sprm:draw("bg")
        end

        love.graphics.setColor(1, 1, 1, 0.6)
        love.graphics.print("/\\ \\/: Select  |  Enter: Toggle  |  Ctrl+/\\ \\/: Reorder  |  Esc: Exit",50, love.graphics.getHeight() - 40)

        -- Panel background
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 600, 150, 500, 300, 10, 10)

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(meta.name or "Unnamed Mod", 620, 170, 460, "left")
        love.graphics.printf("Author: " .. (meta.author or "Unknown"), 620, 210, 460, "left")
        love.graphics.printf("Version: " .. (meta.version or "N/A"), 620, 240, 460, "left")

        love.graphics.setColor(0.9, 0.9, 0.9, 1)
        love.graphics.printf("Description:", 620, 280, 460, "left")

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.printf(meta.description or "No description available.", 620, 310, 460, "left")
    end

        -- Draw the list of mods
    for i, mod in ipairs(self.mods) do
        local y = startY + (i - self.selectedIndex) * spacing + self.scrollOffset
        local alpha = 1.0 - math.min(math.abs(i - self.selectedIndex) * 0.2, 0.8)

        -- Draw mod image (small icon)
        if mod.image then
            love.graphics.setColor(1, 1, 1, alpha)
            local imgW, imgH = mod.image:getDimensions()
            love.graphics.draw(mod.image, 200 - imgW / 4, y - imgH / 4, 0, 0.5, 0.5)
        end

        if i == self.selectedIndex then
            love.graphics.setColor(1, 1, 0, 1)
        else
            love.graphics.setColor(1, 1, 1, alpha)
        end

        local statusText = mod.active and "[ON]" or "[OFF]"
        love.graphics.print(string.format("%s  %s", mod.name or "Unnamed", statusText), 300, y)
    end
end

return self