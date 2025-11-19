local state = {}
local self = state
self.song = {}

self.arrows = {}       -- falling notes
self.noteArrows = {}   -- static target arrows
self.noteOpponentArrows = {} -- static opponent arrows
self.scrollSpeed = 1.5
self.strumLineY = love.graphics.getHeight() - 150
self.arrowKeys = {"left", "down", "up", "right", "left", "down", "up", "right"}
self.preloadTime = 1 -- seconds ahead of time to spawn notes
self.notePool = {} -- free sprites to reuse
self.songended = false

function self:clickSound()
    if not settings["Click Sound"] then return end
    soundManager:playSound("hitsound", {new = true})
end

function self:exit()
    self.song.inst:stop()
    if self.song.voices then
        self.song.voices:stop()
    end
    Utils:goBack("menu")
end

function self:makeCharacters()
    self.characters = {}
    self.characters.bf = CharactersLib:getBF()
    local chart = self.song.chart
    local song = chart
    if self.oldChart then
        song = chart.song
    end
    local dad = song.player2
    print("Player 2: " .. dad)
    if not self.oldChart then
        self.characters.opponent = CharactersLib:getOpponent(dad, self.mod, dad)
    else
        print("MOD = " .. self.mod.modName)
        self.characters.opponent = CharactersLib:getOldOpponent(self.mod, dad)
    end
end

function self:defineConstants()
    if self.song.chart.song.notes then
        self.oldChart = true
    end
end

function self:tryFixFilename(path)
    -- Separate directory and filename
    local dir, filename = path:match("^(.-)([^/]+)$")

    if not dir or not filename then
        return path -- fallback safety
    end

    -- Try original filename first
    if love.filesystem.getInfo(path) then
        return path
    end

    -- Replace spaces ONLY in filename
    local fixedName = filename:gsub(" ", "-")
    local altPath = dir .. fixedName

    if love.filesystem.getInfo(altPath) then
        return altPath, fixedName
    end

    altPath = dir .. string.lower(fixedName)

    if love.filesystem.getInfo(altPath) then
        return altPath, fixedName
    end

    return path -- if still not found, keep original
end

-- 🔹 LOAD FUNCTION
function self:load(song)
    self.song = song
    self.paths = song.path
    self.mod = song.mod
    self.difficulty = string.lower(song.difficulty)
    if self.difficulty == "normal" then
        self.difficulty = ""
    end
    print(self.mod.modName)

    self.songPath = self.paths.songs
    self.dataPath = self.paths.data

    -- Chart
    local chartPath = self.dataPath
    local newSongName
    if not love.filesystem.getInfo(chartPath) then
        local oldPath = chartPath
        chartPath, newSongName = self:tryFixFilename(chartPath)
        if chartPath == oldPath then
            print("Chart not found... " .. chartPath)
            Utils:goBack("menu")
        end
    end
    if newSongName then song.name = newSongName end

    print(chartPath)
    
    local chartLoadPath = chartPath .. "/" .. song.name .. "-" .. self.difficulty .. ".json"
    if self.difficulty == "" then
        chartLoadPath = chartPath .. "/" .. song.name .. ".json"
    end
    if not love.filesystem.getInfo(chartLoadPath) then
        chartLoadPath = chartPath .. "/" .. song.name .. ".json"
    end
    print("PATH2: " .. chartLoadPath)
    
    self.song.chart = Utils:loadJson(chartLoadPath)
    self.song.stage = self.song.chart.stage or self.song.chart.song.stage
    self.song.stage = StagesLib:loadStage(self.song.stage, song.mod)

    -- Audio
    local instPath = self.songPath
    if not love.filesystem.getInfo(instPath) then
        instPath = self:tryFixFilename(instPath)
        -- try again but replacing spaces in the filename with "-"
    end

    print(instPath)
    self.song.inst = love.audio.newSource(instPath .. "/inst.ogg", "static")
    local voicesPath = self.songPath .. "/voices.ogg"
    if love.filesystem.getInfo(voicesPath) then
        self.song.voices = love.audio.newSource(voicesPath, "static")
    end

    print("BPM:", self.song.chart.bpm)

    self.song.inst:play()
    if self.song.voices then
        self.song.voices:play()
    end

    self:defineConstants()

    self:makeCharacters()
    self:makePlayableArrows()
    self:makeArrows()
end

function self:getNoteSprite(note)
    local dir = self.arrowKeys[note.lane + 1]
    -- reuse sprite if available
    if #self.notePool > 0 then
        local tag = table.remove(self.notePool)
        if not sprm:getProperty(tag, "frames") or not sprm:getProperty(tag, "frames")[dir] then
            sprm:loadFrame(tag, dir)
        end
        sprm:playFrame(tag, dir)
        return tag
    end

    -- otherwise create a new sprite
    local tag = "note_" .. note.time .. "_" .. dir .. "_" .. note.lane
    local img = Utils:getPath("images") .. "arrows/" .. dir .. ".png"

    sprm:makeLuaSprite(tag, img, 0, 0)
    sprm:setObjectOrder(tag, 3)
    sprm:setObjectSize(tag, 2, 2)

    return tag
end

function self:spawnNoteSprite(note)
    if note.sprite then return end

    local sprite = self:getNoteSprite(note)

    note.sprite = sprite
    note.active = true
end

function self:releaseNoteSprite(note)
    self.lastNote = note
    note.active = false
    note.hit = true
    if note.sprite then
        table.insert(self.notePool, note.sprite) -- reuse later
        note.sprite = nil
    end
end

function self:getDir(lane)
    return self.arrowKeys[lane + 1]
end

function self:hitArrow(arrow, note)
    if self.song.voices then
        self.song.voices:setVolume(1)
    end
    self:releaseNoteSprite(note)
    if arrow then
        sprm:playFrame(arrow,self.arrowKeys[note.lane + 1])
        Utils:tweenScale(arrow, 2, 2.4, 0.1, function()
            sprm:playFrame(arrow,"strum_" .. self.arrowKeys[note.lane + 1])
            Utils:tweenScale(arrow, 2.4, 2, 0.1)
        end)
    end
    self:clickSound()
end

function self:noteMiss(note)
    if note.lane < 4 then
        local dir = self:getDir(note.lane)
        CharactersLib:playBFAnimation(dir, true)
        if self.song.voices then
            self.song.voices:setVolume(0)
        end
    end
end

function self:miss()
    if self.song.voices then
        self.song.voices:setVolume(0)
    end
end

-- 🔹 UPDATE FUNCTION
function self:update(dt)
    local songTime = self.song.inst:tell("seconds")

    -- Spawn upcoming notes
    while self.arrows[self.nextNoteIndex] do
        local note = self.arrows[self.nextNoteIndex]
        if note.time - songTime <= self.preloadTime then
            self:spawnNoteSprite(note)
            self.nextNoteIndex = self.nextNoteIndex + 1
        else
            break
        end
    end

    -- Opponent hit notes code
    for _, note in ipairs(self.arrows) do
        if not note.hit and note.lane > 3 then
            local diff = math.abs(note.y - self.strumLineY)
            if diff < 50 then
                local key = self.arrowKeys[note.lane + 1]
                local sprArrow = self:getOpponentArrow(key)
                self:hitArrow(sprArrow, note)
                if self.characters.opponent == "dad" then
                    CharactersLib:playDadAnimation(key)
                else
                    CharactersLib:playOpponentAnimation(self.characters.opponent, key)
                end
                break
            end
        end
    end

    -- Update active notes
    for _, note in ipairs(self.arrows) do
        if note.active and not note.hit then
            note.y = self.strumLineY - (note.time - songTime) * 400 * self.scrollSpeed
            
            if note.y > love.graphics.getHeight() + 200 then
                self:noteMiss(note)
                self:releaseNoteSprite(note)
            end
        end
    end

    if not self.song.inst:isPlaying()then
        self:onEndsong()
    end
end

-- 🔹 DRAW FUNCTION
function self:draw()
    for _, note in ipairs(self.arrows) do
        if note.active and not note.hit then
            local dir = self.arrowKeys[note.lane + 1]
            local strum = note.lane > 3
            if not strum then
                strum = self.noteArrows[dir]
            else
                strum = self.noteOpponentArrows[dir]
            end
            local target = sprm:tagToSprite(strum)
            if note.sprite then
                sprm:setObjectPosition(note.sprite, target.x, note.y)
            else
                love.graphics.rectangle("line",target.x, note.y, 2, 1)
            end
        end
    end
end


function self:makeArrow(tag, path, list, extra)
    extra = extra or {}
    sprm:makeLuaSprite(tag, path, extra.baseX + (extra.i - 1) * extra.spacing, extra.baseY)
    sprm:setObjectOrder(tag,4)
    sprm:setObjectSize(tag, 2, 2)
    sprm:moveObject(tag, 0, -sprm:getProperty(tag, "image"):getHeight()/2)

    --Frames
    sprm:loadFrame(tag,extra.dir)
    sprm:loadFrame(tag,"strum_" .. extra.dir)

    list[extra.dir] = tag
end

function self:makePlayableArrows()
    local imgFolder = "assets/shared/images/"
    local spacing = 80
    local baseX = love.graphics.getWidth() - (spacing * #self.arrowKeys)
    local baseY = self.strumLineY

    -- Player Arrows
    for i, dir in ipairs(self.arrowKeys) do
        local spriteName = "arrow_" .. dir
        local imgPath = imgFolder .. "arrows/strum_" .. dir .. ".png"

        self:makeArrow(spriteName, imgPath, self.noteArrows, {baseX = baseX, i = i, spacing = spacing, baseY = baseY, dir = dir})
    end

    local baseX = 0
    local baseY = self.strumLineY

    -- Opponent Arrows
    for i, dir in ipairs(self.arrowKeys) do
        local spriteName = "opponentArrow_" .. dir
        local imgPath = imgFolder .. "arrows/strum_" .. dir .. ".png"

        self:makeArrow(spriteName, imgPath, self.noteOpponentArrows, {baseX = baseX, i = i, spacing = spacing, baseY = baseY, dir = dir})
    end
end

local function getReversed(v, max)
    return max - v
end

-- 🔹 CREATE FALLING ARROWS
function self:makeArrows()
    self.arrows = {}
    self.nextNoteIndex = 1

    local chart = self.song.chart
    local notesSections = chart.notes or chart.song.notes

    for _, section in ipairs(notesSections) do
        for _, noteData in ipairs(section.sectionNotes) do
            local mustHit = section.mustHitSection
            local time = noteData[1] / 1000
            local lane = noteData[2]
            if not mustHit and self.oldChart then
                lane = getReversed(lane, 7) -- reversed mapping
            end
            local length = noteData[3] or 0

            table.insert(self.arrows, {
                time = time,
                lane = lane,
                mustHit = mustHit,
                length = length,
                sprite = nil,
                y = -200,
                hit = false,
                active = false,
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

function self:onEndsong()
    if self.songEnded then return end
    self.songEnded = true
    
    if self.song.week then
        Utils:loadNextWeekSong(self.song)
    else
        Utils:fancyChange(1,"freeplay",nil,{nosound = true})
    end
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
                    self:hitArrow(sprArrow, note)
                    CharactersLib:playBFAnimation(key)
                    break
                else
                    CharactersLib:playBFAnimation(key, true)
                    self:miss()
                end
            end
        end
    elseif key == "escape" then
        self:exit()
    elseif key == "e" then
        self:onEndsong()
    end
end

return self