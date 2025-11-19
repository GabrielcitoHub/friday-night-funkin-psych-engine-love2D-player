local state = {}
local self = state
self.goToState = "freeplay"
self.debug = true

local function continue()
    stateManager:loadState(self.goToState)
end

function self:load()
    soundManager:playMusic("freakyMenu")
    if self.debug then
        continue()
    end
end

function self:draw()
    love.graphics.print("Friday Night Funkin: Love2D Player")
end

function self:keypressed(key)
    continue()
end

return state