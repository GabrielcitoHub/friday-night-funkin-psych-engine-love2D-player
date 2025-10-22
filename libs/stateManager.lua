local stateManager = {}
stateManager.state = {}
stateManager.stateFunctions = {}
stateManager.supportedFunctions = {"load","draw","update","keypressed"}
stateManager.lastState = {}
stateManager.debug = true
stateManager.cachedStates = {}

function stateManager:loadStateLocal(state, extra)
    extra = extra or {}
    package.loaded["states." .. state] = nil
    self.state = require("states." .. state)
    if type(self.state) == "boolean" then
        print("upper: states." .. state)
        self.state = require("states." .. string.lower(state))
        print("lower: states." .. string.lower(state))
        if type(self.state) == "boolean" then
            print("Could not load state \"" .. state .. "\"")
            return
        end
    end
    self.state.name = state
    self.stateFunctions = {}

    if self.laststate then
        package.loaded["states." .. self.laststate.name] = nil
    end

    -- Load functions
    for _,funcName in pairs(self.supportedFunctions) do
        if self.state[funcName] then
            self.stateFunctions[funcName] = true
        end
    end

    -- Call module load function
    if self.load then
        self:load(self.state)
    end

    -- Call state load function
    if self.stateFunctions.load then
        self.state:load(extra)
    end
end

-- function safeStateCall(funcName) -- Only use IF EXTREMELY NECCESARY, IT LAGS REALLY BAD
--     if stateManager.state[funcName] ~= nil then
--         stateManager.state[funcName]()
--     end
-- end

-- Loads a state into the state manager
---@param newstate string
function stateManager:loadState(newstate, extra)
    self:loadStateLocal(newstate, extra)
    self.laststate = self.state
end

function stateManager:reloadState(stateName)
    self:loadStateLocal(stateName or self.state.name)
end

function stateManager:draw()
    if self.debug then
        if self.state.id then
            love.graphics.print("state.id." .. self.state.id, 0, 20)
        end
    end
    if not self.stateFunctions.draw then return end
    self.state:draw()
end

function stateManager:update(dt)
    if not self.stateFunctions.update then return end
    self.state:update(dt)
end

function stateManager:keypressed(key)
    if not self.stateFunctions.keypressed then return end
    self.state:keypressed(key)
end

return stateManager