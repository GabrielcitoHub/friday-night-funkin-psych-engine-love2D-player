local state = {}
local self = state

function self:load()
end

function self:keypressed(key)
    if key == "escape" then
        Utils:goBack("menu")
    end
end

return self