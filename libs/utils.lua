local utils = {}
local self = utils
self.active = true
self.paths = {
    mods = "mods/",
    assets = "assets/"
}
self.paths.shared = self.paths.assets .. "shared/"
self.paths.images = self.paths.shared .. "images/"

function self:getPath(desiredPath)
    return self.paths[desiredPath]
end

function self:fancyChange(time, state, extra, extra2)
    if not self.active then return end
    extra2 = extra2 or {}
    if not state then
        state = time
        time = 1
    end
    time = time or 1
    if not extra2.nosound then
        soundManager:playSound("confirmMenu",nil,{new = true})
    end
    self.active = false
    Timer.after(time, function()
        self.active = true
        stateManager:loadState(state, extra)
    end)
end

function self:goBack(state)
    soundManager:playSound("cancelMenu")
    stateManager:loadState(state)
end

function self:loadJson(path)
    local jsonData

    if love.filesystem.getInfo(path) then
        local content, size = love.filesystem.read(path)
        if content then
            local success, decoded = pcall(json.decode, content)
            if success and decoded then
                jsonData = decoded
            else
                print("Error: Failed to decode JSON in \"" .. path .. "\"")
            end
        else
            print("Error: Could not read file \"" .. path .. "\"")
        end
    end

    return jsonData
end

function self:loadDefaultMod(mod)
    self.defaultMod = mod
end

function self:getCurrentMod()
    return self.defaultMod
end

function self:buildQuads(atlas, texture)
    local quads = {}
    for name, frame in pairs(atlas.frames) do
        quads[name] = love.graphics.newQuad(
            frame.x, frame.y, frame.width, frame.height,
            texture:getWidth(), texture:getHeight()
        )
    end
    return quads
end

function self:parseXMLAnimation(data, animName, extra)
    extra = extra or {}
    self.cache = self.cache or {}
    self.cache.atlases = self.cache.atlases or {}
    local atlas = self.cache.atlases[animName]
    if extra.new or not atlas then
        atlas = self:parseTextureAtlas(data)
    end
    if not self.cache.atlases[animName] then
        -- self.cache.atlases[animName] = atlas
    end
    local frames = {}

    -- Look for frames starting with animName
    for name, frame in pairs(atlas.frames) do
        local prefix, num = name:match("^(.-)(%d+)$")
        if prefix == animName then
            table.insert(frames, {
                index = tonumber(num),
                quadData = frame
            })
        end
    end

    if #frames == 0 then
        print("[ERROR] No frames found for animation: \"" .. animName .. "\"")
        return nil
    end

    -- Sort frames numerically
    table.sort(frames, function(a, b)
        return a.index < b.index
    end)

    -- Convert to clean frames table
    for i, f in ipairs(frames) do
        frames[i] = f.quadData
    end

    print("XML Animation parsed: \"" .. animName .. "\" Frames: \"" ..  #frames .. "\"")

    return {
        type = "xml",
        imagePath = atlas.imagePath,
        frames = frames
    }
end

function self:parseTextureAtlas(xmlText)
    local atlas = {frames = {}}

    -- Get the image path
    atlas.imagePath = xmlText:match('imagePath="(.-)"')

    -- Iterate over each SubTexture tag
    for name, x, y, width, height, frameX, frameY, frameWidth, frameHeight in xmlText:gmatch(
        '<SubTexture%s+name="(.-)"%s+x="(.-)"%s+y="(.-)"%s+width="(.-)"%s+height="(.-)"%s*frameX="(.-)"?%s*frameY="(.-)"?%s*frameWidth="(.-)"?%s*frameHeight="(.-)"?%s*/>'
    ) do
        -- Convert to numbers where possible
        local frame = {
            x = tonumber(x),
            y = tonumber(y),
            width = tonumber(width),
            height = tonumber(height)
        }

        if frameX ~= "" then
            frame.frameX = tonumber(frameX)
            frame.frameY = tonumber(frameY)
            frame.frameWidth = tonumber(frameWidth)
            frame.frameHeight = tonumber(frameHeight)
        end

        atlas.frames[name] = frame
    end

    return atlas
end

-- Add this to your Utils table
function self:tweenScale(obj, targetX, targetY, duration, onComplete)
    local obj = sprm:tagToSprite(obj)
    local startX, startY = obj.sx or 1, obj.sy or 1
    local elapsed = 0

    -- Make sure we have somewhere to update per frame
    if not self._tweens then self._tweens = {} end

    table.insert(self._tweens, {
        update = function(dt)
            elapsed = elapsed + dt
            local t = math.min(elapsed / duration, 1)
            obj.sx = startX + (targetX - startX) * t
            obj.sy = startY + (targetY - startY) * t
            if t >= 1 then
                if onComplete then onComplete() end
                return true -- done
            end
        end
    })
end

-- Call this from your main update(dt)
function self:updateTweens(dt)
    if not self._tweens then return end
    for i = #self._tweens, 1, -1 do
        local t = self._tweens[i]
        if t.update(dt) then
            table.remove(self._tweens, i)
        end
    end
end

function self:loadModData(modPath)
    local modData = {}

    local packPath = modPath .. "/pack.json"
    modData = Utils:loadJson(packPath)
    modData.meta = modData

    local imagePath = modPath .. "/pack.png"
    if love.filesystem.getInfo(imagePath) then
        modData.image = love.graphics.newImage(imagePath)
    end

    return modData
end

-- Save the current order + states
function self:saveModsOrder(mods, filename)
    filename = filename or "modsList"
    local lines = {}
    for _, mod in ipairs(mods) do
        local active = mod.active and "1" or "0"
        table.insert(lines, mod.folderName .. "|" .. active)
    end
    love.filesystem.write(filename .. ".txt", table.concat(lines, "\n"))
end

-- Load the mod order + activation states
function self:loadModsOrder()
    local order = {}
    if love.filesystem.getInfo("modsList.txt") then
        for line in love.filesystem.lines("modsList.txt") do
            local name, active = line:match("([^|]+)|([01])")
            if name then
                table.insert(order, { name = name, active = active == "1" or false })
            end
        end
    end
    return order
end

function self:encodeSongs(newSongsTable, songs, mod, extra)
    newSongsTable = newSongsTable or {}
    extra = extra or {}
    if extra.new then
        newSongsTable = {}
    end
    for _, song in pairs(songs) do
        song.path = {
            songs = Utils:getPath("mods") .. mod.modName .. "/songs/" .. song[1],
            data = Utils:getPath("mods") .. mod.modName .. "/data/" .. song[1]
        }
        song.mod = mod
        song.name = song[1]
        song.difficulties = extra.difficulties or {"Hard"}

        table.insert(newSongsTable, song)
    end
end

function self:loadMod(path)
    local orderLookup = self:getOrderLookup()
    local modName = path:match("([^/]+)$")
    local mod = self:loadModData(path)

    mod.path = path
    mod.modName = modName
    mod.name = mod.meta and mod.meta.name or modName
    mod.folderName = modName
    mod.active = orderLookup[modName] and orderLookup[modName].active or false

    mod.scripts = nil

    mod.weeks = {}
    local weeksFolder = "mods/" .. modName .. "/weeks"
    local rawWeeks = love.filesystem.getDirectoryItems(weeksFolder)
    for _,rawWeek in pairs(rawWeeks) do
        local weekName = rawWeek:match("^(.*)%.") or rawWeek
        local week = Utils:loadJson(weeksFolder .. "/" .. weekName .. ".json")
        mod.weeks[weekName] = week
    end

    return mod
end

function self:getOrderLookup()
    local orderData = self:loadModsOrder()
    local orderLookup = {}
    for i, entry in ipairs(orderData) do
        orderLookup[entry.name] = { index = i, active = entry.active }
    end

    return orderLookup
end

function self:loadMods(modState)
    local orderLookup = self:getOrderLookup()
    local mods = {}
    local rawMods = love.filesystem.getDirectoryItems("mods")

    for _, rawMod in pairs(rawMods) do
        local modName = rawMod:match("^(.*)%.") or rawMod
        local modPath = Utils:getPath("mods") .. modName
        local mod
        if modState then
            print(modName)
            if orderLookup[modName] and orderLookup[modName].active == modState then
                print(orderLookup[modName].active)
                mod = self:loadMod(modPath)
            end
        else
            mod = self:loadMod(modPath)
        end

        if mod then
            table.insert(mods, mod)
        end
    end

    -- Sort according to order.txt, fallback alphabetical
    table.sort(mods, function(a, b)
        local aInfo, bInfo = orderLookup[a.folderName], orderLookup[b.folderName]
        if aInfo and bInfo then
            return aInfo.index < bInfo.index
        elseif aInfo then
            return true
        elseif bInfo then
            return false
        else
            return a.folderName < b.folderName
        end
    end)

    return mods
end

function self:getSetting(name)
    if self.options then
        for i,v in ipairs(self.options) do
            if v.name == name then
                return v.value
            end
        end
    end
end

function self:loadSong(song)
    Utils:loadDefaultMod(song.mod)
    soundManager:stopAllMusics()
    Utils:fancyChange(1, "gameplay", song)
end

function self:loadWeek(week)
    Utils:loadDefaultMod(week.mod)
    week.curSong = 1
    local loadSong = week.loadedSongs[week.curSong]
    if loadSong then
        soundManager:stopAllMusics()
        Utils:fancyChange(1, "gameplay", loadSong)
    else
        print("This week has no songs")
        Utils:fancyChange(1, "menu")
    end
    
end

function self:loadNextWeekSong(song)
    assert(song.week, "This song has no week")
    local week = song.week
    local nextSong = week.songs[week.curSong + 1]
    
    if nextSong then
        soundManager:stopAllMusics()
        Utils:fancyChange(1, "gameplay", nextSong, {nosound = true})
        week.curSong = week.curSong + 1
    else
        Utils:fancyChange(1, "story_mode", nil, {nosound = true})
    end
end

return self