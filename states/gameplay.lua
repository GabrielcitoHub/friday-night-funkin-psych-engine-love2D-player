local state = {}
local self = state
self.song = {}

self.arrows = {}       -- falling notes
self.noteArrows = {}   -- static target arrows
self.noteOpponentArrows = {} -- static opponent arrows
self.scrollSpeed = 1.5
self.strumLineY = love.graphics.getHeight() - 150
self.arrowKeys = {"left", "down", "up", "right", "left", "down", "up", "right"}

-- 🔹 LOAD FUNCTION
function self:load(song)
    self.paths = song.path
    self.mod = song.mod

    self.songPath = self.paths.songs
    self.dataPath = self.paths.data

    -- Audio
    self.song.inst = love.audio.newSource(self.songPath .. "/inst.ogg", "static")
    self.song.voices = love.audio.newSource(self.songPath .. "/voices.ogg", "static")

    -- Chart
    self.song.chart = Utils:loadJson(self.dataPath .. "/" .. song.name .. "-hard.json")
    print("BPM:", self.song.chart.bpm)

    self.song.inst:play()
    self.song.voices:play()

    self:makeNoteArrows()
    self:makeOpponentNoteArrows()
    self:makeArrows()
end

-- 🔹 UPDATE FUNCTION
function self:update(dt)
    -- Opponent hit notes code
    for _, note in ipairs(self.arrows) do
        if not note.hit and note.lane > 3 then
            local diff = math.abs(note.y - self.strumLineY)
            if diff < 50 then
                local key = self.arrowKeys[note.lane + 1]
                local sprArrow = self:getOpponentArrow(key)
                if sprArrow then
                    Utils:tweenScale(sprArrow, 2, 2.4, 0.1, function()
                        Utils:tweenScale(sprArrow, 2.4, 2, 0.1)
                    end)
                end
                note.hit = true
                soundManager:playSound("hitsound", {new = true})
                break
            end
        end
    end

    local songTime = self.song.inst:tell("seconds")

    for _, note in ipairs(self.arrows) do
        if not note.hit then
            note.y = self.strumLineY - (note.time - songTime) * 400 * self.scrollSpeed
        end
    end
end

-- 🔹 DRAW FUNCTION
function self:draw()
    for _, note in ipairs(self.arrows) do
        local dir = self.arrowKeys[note.lane + 1]
        local targetSprite
        if note.lane <= 3 then
            targetSprite = sprm:tagToSprite(self.noteArrows[dir])
        else
            targetSprite = sprm:tagToSprite(self.noteOpponentArrows[dir])
        end
        
        local x = targetSprite.x

        love.graphics.setColor(1, 1, 1)
        if not note.hit then
            love.graphics.rectangle("fill", x, note.y, 64, 16)
        end
    end

    -- strum line
    love.graphics.setColor(1, 0, 0)
    love.graphics.rectangle("fill", 0, self.strumLineY, love.graphics.getWidth(), 5)
    love.graphics.setColor(1, 1, 1)

    for _, dir in ipairs(self.arrowKeys) do
        local spriteName = "arrow_" .. dir
        sprm:draw(spriteName)
    end

    for _, dir in ipairs(self.arrowKeys) do
        local spriteName = "opponentArrow_" .. dir
        sprm:draw(spriteName)
    end
end

-- 🔹 MAKE STATIC ARROWS
function self:makeNoteArrows()
    local imgFolder = "assets/shared/images/"
    local spacing = 80
    local baseX = love.graphics.getWidth() - (spacing * #self.arrowKeys)
    local baseY = self.strumLineY

    for i, dir in ipairs(self.arrowKeys) do
        local spriteName = "arrow_" .. dir
        local imgPath = imgFolder .. "arrows/" .. dir .. ".png"

        sprm:makeLuaSprite(spriteName, imgPath, baseX + (i - 1) * spacing, baseY)
        sprm:setObjectSize(spriteName, 2, 2)

        -- Save reference
        self.noteArrows[dir] = spriteName
    end
end

-- 🔹 MAKE STATIC ARROWS
function self:makeOpponentNoteArrows()
    local imgFolder = "assets/shared/images/"
    local spacing = 80
    local baseX = 0
    local baseY = self.strumLineY

    for i, dir in ipairs(self.arrowKeys) do
        local spriteName = "opponentArrow_" .. dir
        local imgPath = imgFolder .. "arrows/" .. dir .. ".png"

        sprm:makeLuaSprite(spriteName, imgPath, baseX + (i - 1) * spacing, baseY)
        sprm:setObjectSize(spriteName, 2, 2)

        -- Save reference
        self.noteOpponentArrows[dir] = spriteName
    end
end

local function getReversed(v, max)
    return max - v
end

-- 🔹 CREATE FALLING ARROWS
function self:makeArrows()
    self.arrows = {}
    local chart = self.song.chart
    local notesSections = chart.notes or chart.song.notes
    if chart.song.notes then
        self.oldChart = true
    end
    local bpm = chart.bpm or 120

    for _, section in ipairs(notesSections) do
        for _, noteData in ipairs(section.sectionNotes) do
            local mustHit = section.mustHitSection
            local time = noteData[1] / 1000
            local lane = noteData[2]
            if not mustHit and self.oldChart then
                lane = getReversed(lane, 7)
            end
            local length = noteData[3] or 0

            table.insert(self.arrows, {
                musthit = mustHit,
                time = time,
                lane = lane,
                length = length,
                y = -100,
                hit = false
            })
        end
    end
end

-- 🔹 GET STATIC ARROW BY KEY
function self:getArrow(key)
    return self.noteArrows[key]
end

-- 🔹 GET STATIC OPPONENT ARROW BY KEY
function self:getOpponentArrow(key)
    return self.noteOpponentArrows[key]
end

-- 🔹 INPUT HANDLING
function self:keypressed(key)
    local keyMap = {left = 0, down = 1, up = 2, right = 3}
    local lane = keyMap[key]

    if lane ~= nil then
        for _, note in ipairs(self.arrows) do
            if not note.hit and note.lane == lane then
                local diff = math.abs(note.y - self.strumLineY)
                if diff < 50 then
                    local sprArrow = self:getArrow(key)
                    if sprArrow then
                        Utils:tweenScale(sprArrow, 2, 2.4, 0.1, function()
                            Utils:tweenScale(sprArrow, 2.4, 2, 0.1)
                        end)
                    end
                    note.hit = true
                    soundManager:playSound("hitsound", {new = true})
                    break
                end
            end
        end
    elseif key == "escape" then
        self.song.inst:stop()
        self.song.voices:stop()
        Utils:goBack("menu")
    end
end

return self