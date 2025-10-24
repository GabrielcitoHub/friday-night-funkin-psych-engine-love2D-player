local characters = {}
local self = characters
self.characters = {}

function self:newCharacter(name)
    local char = {}

    char.name = name
    char.standTimer = 0
    char.standed = true

    self.characters[name] = char
end

function self:getcharacter(name)
    return self.characters[name]
end

function self:playBFAnimation(anim, miss)
    local bf = self:getcharacter("boyfriend")
    if not miss then
        sprm:playAnim(bf.name, anim)
    else
        sprm:playAnim(bf.name, anim .. "_miss")
    end
    bf.standTimer = 0.6
    bf.standed = false
end

function self:playDadAnimation(anim)
    local dad = self:getcharacter("dad")
    sprm:playAnim(dad.name, anim)
    dad.standTimer = 0.6
    dad.standed = false
end

function self:playOpponentAnimation(tag, anim)
    local opponent = self:getcharacter(tag)
    sprm:playAnim(opponent.name, anim)
    opponent.standTimer = 0.6
    opponent.standed = false
end

function self:getCharacterData(path, mod)
    return Utils:loadJson(Utils:getPath("mods") .. mod.modName .. "/characters/" .. path .. ".json")
end

function self:getBF()
    local bf = "boyfriend"
    self:newCharacter(bf)
    sprm:makeLuaSprite(bf, Utils:getPath("images") .. "characters/BOYFRIEND", love.graphics:getWidth() - 700, love.graphics:getHeight() - 700)
    sprm:setObjectOrder(bf, -1)
    sprm:addLuaAnimation(bf, "idle", "BF idle dance", "xml")

    sprm:addLuaAnimation(bf, "left", "BF NOTE LEFT", "xml")
    sprm:addLuaAnimation(bf, "down", "BF NOTE DOWN", "xml")
    sprm:addLuaAnimation(bf, "up", "BF NOTE UP", "xml")
    sprm:addLuaAnimation(bf, "right", "BF NOTE RIGHT", "xml")

    sprm:addLuaAnimation(bf, "left_miss", "BF NOTE LEFT MISS", "xml")
    sprm:addLuaAnimation(bf, "down_miss", "BF NOTE DOWN MISS", "xml")
    sprm:addLuaAnimation(bf, "up_miss", "BF NOTE UP MISS", "xml")
    sprm:addLuaAnimation(bf, "right_miss", "BF NOTE RIGHT MISS", "xml")

    sprm:playAnim(bf, "idle")
    return bf
end

function self:getOpponent(optName, mod, path)
    optName = optName or path
    self:newCharacter(optName)

    local charJson = self:getCharacterData(path, mod)
    local oppSprPath = charJson.image
    sprm:makeLuaSprite(optName, Utils:getPath("mods") .. mod.modName .. "/images/" .. oppSprPath, 0, love.graphics:getHeight() - 1400)
    sprm:setObjectOrder(optName, -1)
    for _, anim in pairs(charJson.animations) do
        local animation = anim.anim
        local name = anim.name
        if animation == "singLEFT" then
            animation = "left"
        elseif animation == "singDOWN" then
            animation = "down"
        elseif animation == "singUP" then
            animation = "up"
        elseif animation == "singRIGHT" then
            animation = "right"
        end
        sprm:addLuaAnimation(optName, animation, name, "xml")
    end
    
    sprm:playAnim(optName, "idle")
    return optName
end

function self:getOldOpponent(mod, path)
    print("MOD: " .. mod.modName)
    local dad = "dad"
    self:newCharacter(dad)

    local charJson = self:getCharacterData(path, mod)
    local oppSprPath = charJson.image
    print("imagePath: " .. oppSprPath)

    sprm:makeLuaSprite(dad, Utils:getPath("mods") .. mod.modName .. "/images/" .. oppSprPath, 0, love.graphics:getHeight() - 1400)
    sprm:setObjectOrder(dad, -1)
    sprm:addLuaAnimation(dad, "idle", "Dad idle dance", "xml")

    sprm:addLuaAnimation(dad, "left", "Dad Sing Note LEFT", "xml")
    sprm:addLuaAnimation(dad, "down", "Dad Sing Note DOWN", "xml")
    sprm:addLuaAnimation(dad, "up", "Dad Sing Note UP", "xml")
    sprm:addLuaAnimation(dad, "right", "Dad Sing Note RIGHT", "xml")

    sprm:playAnim(dad, "idle")
    return dad
end

function self:update(dt)
    if not self.characters then return end

    for name,char in pairs(self.characters) do
        if not char.standed then
            if char.standTimer > 0 then
                char.standTimer = char.standTimer - 1 * dt
            else
                sprm:playAnim(name, "idle")
                char.standed = true
            end
        end
    end
end

return characters