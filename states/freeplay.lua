local state = {}
local self = state
self.imagesFolder = Utils:getPath("images")

-- Example songs (you can replace this later with dynamic loading)
self.songs = {
    { name = "Fallen Down", difficulty = "Normal", path = "songs/fallen_down" },
    { name = "Megalovania", difficulty = "Hard", path = "songs/megalovania" },
    { name = "Heartache", difficulty = "Easy", path = "songs/heartache" }
}
self.songs = {}

self.selectedIndex = 1
self.selectedDifficulty = 1
self.font = nil

function self:loadSongs()
    local loadedSongs = {}
    for _, mod in ipairs(self.mods) do
        print(mod.name)
        print(mod.active)
        for _, week in pairs(mod.weeks) do
            if week.songs then
                Utils:encodeSongs(loadedSongs, week.songs, mod, {difficulties = week.difficulties})
            end
        end
    end

    return loadedSongs
end

function self:load()
    sprm:makeLuaSprite("bg", self.imagesFolder .. "menuDesat")
    sprm:centerObject("bg")

    self.mods = Utils:loadMods(true)
    self.font = love.graphics.newFont(18)
    love.graphics.setFont(self.font)
    self.scrollTimer = 0

    if self.mods then
        print("MODS LOADED")
        local songs = self:loadSongs()
        if songs then
            for index, song in pairs(songs) do
                -- The actual songs saving
                local fixSong = {
                    name = song[1],
                    icon = song[2],
                    color = song[3],
                    difficulties = song.difficulties,
                    path = song.path,
                    mod = song.mod
                }
                table.insert(self.songs, fixSong)
            end
        else
            print("[Freeplay] No songs loaded!")
        end
    else
        print("[Freeplay] No mods loaded!")
    end
end

function self:update(dt)
    -- could be used for scrolling animation or previewing songs later
end

function self:draw()
    love.graphics.clear(0.1, 0.1, 0.1) -- dark background

    local selectedSong
    for i, song in ipairs(self.songs) do
        song.index = i
        if i == self.selectedIndex then
            selectedSong = song
            break
        end
    end

    selectedSong = selectedSong or {}
    local color = selectedSong.color or {255,255,122}

    love.graphics.setColor(color[1]/255, color[2]/255, color[3]/255) -- yellow for selected
    sprm:draw("bg")

    love.graphics.printf("Freeplay", 0, 40, love.graphics.getWidth(), "center")

    love.graphics.setColor(1, 1, 1)

    if #self.songs > 0 then
        for i, song in ipairs(self.songs) do
            local y = 100 + (i - 1) * 40

            song.name = song.name or "???"
            song.difficulties = song.difficulties or {"Hard", "Normal", "Easy"}
            if type(song.difficulties) == "string" then
                song.difficulties = {song.difficulties}
            end
            song.difficulty = song.difficulties[self.selectedDifficulty] or song.difficulties[1] -- or "N/A"

            if i == self.selectedIndex then
                love.graphics.setColor(0.8, 1, 1) -- yellow for selected
                if self.selectedDifficulty > #song.difficulties then
                    self.selectedDifficulty = 1
                elseif self.selectedDifficulty < 1 then
                    self.selectedDifficulty = #song.difficulties
                end
            else
                love.graphics.setColor(1, 1, 1)
            end

            love.graphics.printf(song.name .. " [" .. song.difficulty .. "]", 0, y, love.graphics.getWidth(), "center")
        end
    else
        love.graphics.printf("No songs loaded!", 0, love.graphics.getHeight()/2, love.graphics.getWidth(), "center", 0)
    end
end

function self:keypressed(key)
    if key == "escape" then
        Utils:goBack("menu")

    elseif key == "up" then
        self.selectedIndex = self.selectedIndex - 1
        if self.selectedIndex < 1 then
            self.selectedIndex = #self.songs
        end

    elseif key == "down" then
        self.selectedIndex = self.selectedIndex + 1
        if self.selectedIndex > #self.songs then
            self.selectedIndex = 1
        end

    elseif key == "left" then
        self.selectedDifficulty = self.selectedDifficulty - 1

    elseif key == "right" then
        self.selectedDifficulty = self.selectedDifficulty + 1

    elseif key == "return" or key == "space" then
        local selected = self.songs[self.selectedIndex]
        if selected then
            print("Loading song:", selected.name, "from", selected.name)
            assert(selected.mod)
            Utils:loadSong({path = selected.path, mod = selected.mod, name = selected.name, difficulty = selected.difficulty})
        else
            print("No songs to load")
        end
    end
end

return self