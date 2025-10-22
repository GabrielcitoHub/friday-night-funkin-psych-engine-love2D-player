local Cur_Night = 1
_G.stateManager = require("libs/stateManager")
_G.sprm = require("libs/sprite")
_G.json = require("libs/json")
_G.soundManager = require("libs/soundManager")
soundManager:setFolder("sounds","assets/shared/sounds")
soundManager:setFolder("music","assets/shared/music")
FPS = require("libs/FPS")
Timer = require("libs/timer")
Utils = require("libs/utils")
local settings = {}

function _G.loadSettings(cfg)
    for _,opt in ipairs(cfg) do
        local name = opt.name
        local value = opt.value

        settings[name] = value
    end
end

local function setupStateManager(stsManager)
    if not stsManager then return end
    function stsManager:load(state)
        sprm:clearSprites() -- it was kind of interesting to see thing overlap over lol
        --i know lol
    end
end

function love.load()
    setupStateManager(stateManager)
    
    --G.audio = require("resources/libs/wave")

    -- Load setup

    -- Loads the settings
    stateManager:loadState("options")

    -- Loads the first state
    stateManager:loadState("intro")
end

function love.update(dt)
    Timer.update(dt)
    stateManager:update(dt)
    Utils:updateTweens(dt)
end

function love.keypressed(key)
    stateManager:keypressed(key)
end

function love.draw()
    sprm:draw()
    stateManager:draw()

    if not settings["Show FPS"] then return end
    local fps = FPS:getFps()

    if fps < 10 then
        love.graphics.setColor(1, 0, 0)
    elseif fps < 20 then
        love.graphics.setColor(1, 0.5, 0.5)
    else
        love.graphics.setColor(1, 1, 1)
    end

    love.graphics.print("FPS: "..fps, 0, 0)

    love.graphics.setColor(1, 1, 1)
    -- love.graphics.print("This is a test", 300, 400)
end

function love.quit()
    -- save()
end
