local state = {}
local self = state
self.active = true
self.buttons = {"storymode", "freeplay", "mods", "options"}
self.imagesFolder = Utils:getPath("images")
_G.selected = _G.selected or 1

function self:makeButtons()
    for i = 1,#self.buttons do
        local buttonName = self.buttons[i]
        sprm:makeLuaSprite(buttonName,self.imagesFolder.."tempmenu/"..buttonName, 65, -135 + (150 * i))
        sprm:setObjectSize(buttonName, 3, 3)
        sprm:setObjectOrder(buttonName,2)
    end
    self:updateButtonSizes()
end

function self:load()
    love.graphics.setColor(1, 1, 1)
    soundManager:playMusic("freakyMenu")
    sprm:makeLuaSprite("bg",self.imagesFolder.."menuBG")
    sprm:centerObject("bg")
    self:makeButtons()
end

function self:checkSelected()
    self.active = false
    local button = self.buttons[selected]
    Utils:fancyChange(button)
end

function self:updateSelection()
    if selected < 1 then
        _G.selected = #self.buttons
    elseif selected > #self.buttons then
        _G.selected = 1
    end
    soundManager:playSound("scrollMenu",nil,{new = true})
    self:updateButtonSizes()
end

function self:updateButtonSizes()
    for tag,sprite in pairs(sprm.sprites) do
        local found
        for _,buttonName in ipairs(self.buttons) do
            if tag == buttonName then
                found = tag
            end
        end
        if found then
            sprm:setObjectSize(found, 3, 3)
        end
    end 
    local selectedButton = self.buttons[selected]
    if selectedButton then
        sprm:setObjectSize(selectedButton, 4, 4)
    end
end

function self:keypressed(key)
    if not self.active then return end
    if key == "up" then
        _G.selected = selected - 1
    elseif key == "down" then
        _G.selected = selected + 1
    end
    if key == "up" or key == "down" then
        self:updateSelection()
    end
    if key == "space" or key == "return" then
        self:checkSelected()
    end
end

return self