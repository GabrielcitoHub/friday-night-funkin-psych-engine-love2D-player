local spritemanager = {}
spritemanager.sprites = {}
spritemanager.debug = false
--spritemanager.placeholderImage = love.graphics.newImage("assets/images/placeholders/PLACEHOLDER.png")

local json = require "libs/json"

-- I made this!
-- (This took waaay too long to make... but it was worth it, imma finish the menu later)
-- G
--How in the fuk
function spritemanager:setPlayer(plr)
    self.player = plr
    self:createEvents()
end

function spritemanager:createEvents()
    if self.player and self.player.events then
        for _, event in ipairs(self.player.events) do
            local ev = event -- capture event name
            self[ev] = function(self, tag, func)
                self:addCollidable(tostring(tag), {[ev] = func})
            end
        end
    end
end

function spritemanager:setCamera(cam)
    self.camera = cam
end

function spritemanager:tagToSprite(tag)
    local spr = self.sprites[tag]
    if not spr then 
        print("Sprite with tag \"" .. tag .. "\" not found")
    end
    return spr
end

-- Loads a frame to use with :playFrame()
-- First parameter must be the object tag
-- Second parameter must be the frame name you want to load
-- to load a frame put the frame on the same folder as the object image
-- otherwise it won't work\n
function spritemanager:loadFrame(tag, frametag, framename)
    framename = framename or frametag

    local spr = self:tagToSprite(tag)
    local path = spr.path:match("^(.*)[/\\][^/\\]+$")
    local framedata = {}
    if type(framename) == "string" then
        local searchpath = path .. "/" .. framename
        local image, newpath = self:findImage(searchpath)
        framedata = {
            type = "image",
            image = image,
            path = newpath
        }
    else
        local frame = framename.frame
        framedata = {
            type = "quad",
            image = framename.image,
            quad = {
                x = frame.x,
                y = frame.y,
                width = frame.w,
                height = frame.h
            }
        }
    end

    if not spr.frames then
        spr.frames = {}
    end
    spr.frames[frametag] = framedata
end

-- Plays a frame from a previusly loaded frame with :loadFrame()
-- First parameter must be the object tag
-- Second parameter must be the frame name you want to play
function spritemanager:playFrame(tag, framename)
    local spr = self:tagToSprite(tag)
    local frame = spr.frames[framename]

    if self.debug then
        if not spr.frames then
            print("Tried to play frame " .. framename .. " but the sprite " .. spr.tag .. " has no frames")
            return
        end
        if not frame then
            print("Frame \"" .. framename .. "\" not found in \"" .. spr.tag .. "\"")
            return
        end
        if not frame.image then
            print("Frame \"" .. framename .. "\" in \"" .. spr.tag .. "\" does not have an image")
            return
        end
    end

    spr.image = frame.image
end

function spritemanager:animFrameToFrame(tag, animname, newframename, frameindex)
    frameindex = frameindex or 1
    local spr = self:tagToSprite(tag)
    local anim = spr.anims[animname]
    if anim then
        local frames = anim.frames
        local frame = frames[frameindex]
        if frame then
            self:loadFrame(tag,newframename,frame)
        else
            print("Animation Frame Index \"" .. frameindex .. "\" not found on sprite \"" .. spr.tag .. "\"")
        end
    else
        print("Animation \"" .. animname .. "\" not found on sprite \"" .. spr.tag .. "\"")
    end
end

function spritemanager:findImage(path)
    local placeholderImg = self.placeholderImage
    if not path then
        print("Warning: Invalid sprite path (nil)")
        return placeholderImg
    else
        local paths = {"","assets/","assets/images/"}
        local extensions = {"",".png",".jpg"}
        for _,ext in ipairs(extensions) do
            for _,testpath in ipairs(paths) do
                local trypath = testpath .. path .. ext
                local exists = love.filesystem.getInfo(trypath, "file")
                if exists then
                    local image = love.graphics.newImage(trypath)
                    local newpath = trypath
                    return image, newpath
                end
            end
        end
        print("Warning: image \"" .. path .. "\" not found")
        return placeholderImg
    end
end

local function getSpriteData(data, extra)
    extra = extra or {}
    return {
        tag = data.tag,
        path = data.path,
        image = data.image,
        x = extra.x or data.x or 0,
        y = extra.y or data.y or 0,
        r = extra.rotation or 0,
        sx = extra.scalex or 1,
        sy = extra.scaley or 1,
        ox = extra.offsetx or 0,
        oy = extra.offsety or 0,
        kx = extra.shearx or 0,
        ky = extra.sheary or 0,
        visible = (extra.visible == nil) and true or extra.visible,
        enabled = {extra.enabled == nil} and true or extra.enabled,
        order = extra.order or 1,
        layer = extra.layer or "game"
    }
end

function spritemanager:makeLuaSprite(tag, path, x, y, extra)
    x = x or 0
    y = y or 0
    if extra ~= nil then
        if extra.visible ~= nil then
            print("visible: " .. tostring(extra.visible))
        else
            print("visible: not set")
        end
    end
    local image, newpath = self:findImage(path)
    local data = {
        tag = tag,
        path = newpath,
        image = image,
        x = x,
        y = y
    }
    local spritedata = getSpriteData(data, extra)

    --table.insert(spritemanager.sprites, spritedata)
    self.sprites[tag] = spritedata
    if not self.debug then return end
    print(self.sprites[tag].tag .. " " .. self.sprites[tag].path)
end

-- this does nothing yet and therebefore shouln't be used like at all
function spritemanager:makeAnimatedLuaSprite(tag, path, x, y, extra)
    local image, newpath = self:findImage(path)
        local data = {
        tag = tag,
        path = newpath,
        image = image,
        x = x,
        y = y
    }
    local spritedata = getSpriteData(data, extra)
    spritedata.anims = {}
    self.sprites[tag] = spritedata
end

---@alias ANIMATION_TYPES
---| "xml"
---| "librejson"
---| "json"
---| "quad"

-- New default for animations file format
---@param extname ANIMATION_TYPES
function spritemanager:setDefaultAnimationFileFormat(extname)
    self.animExt = extname
end

-- W.I.P, please don't use yet
---@param tag string A sprite tag
---@param animname string The name of the animation to load
---@param animtype ANIMATION_TYPES
---@param extra table|nil Extra animation parameters (depending on type)
function spritemanager:addLuaAnimation(tag, animTag, animname, animtype, extra)
    local spr = self:tagToSprite(tag)
    if not spr then return end

    animtype = (animtype and string.lower(animtype)) or self.animExt or "xml"
    spr.anims = spr.anims or {}

    ----------------------------------------------------------
    -- 1️⃣ XML Animation Parsing (Texture Atlas format)
    ----------------------------------------------------------
    if animtype == "xml" then
        local xmlPath = spr.path:gsub("%.[^%.]+$", "") .. ".xml"
        print("XML Path: " .. xmlPath)
        if not love.filesystem.getInfo(xmlPath) then
            print("[WARN] Missing XML animation file: " .. xmlPath)
            return
        end

        spr.cache = spr.cache or {}
        spr.cache.xml = spr.cache.xml or {}
        local xmlData = spr.cache.xml.data or love.filesystem.read(xmlPath)
        local anim = Utils:parseXMLAnimation(xmlData, animname) -- You can make this loader
        if not anim then return end

        spr.anims[animTag] = {
            type = "xml",
            frames = anim.frames,
            image = anim.image,
            interval = anim.interval or (1/24)
        }
        spr.cache.xml.data = xmlData

    ----------------------------------------------------------
    -- 2️⃣ Psych Engine / LibreSprite JSON format
    ----------------------------------------------------------
    elseif animtype == "librejson" then
        local folder = spr.path:match("^(.*)/") .. "/"
        local imgPath = folder .. animname .. "-sheet.png"
        local img = self:findImage(imgPath)
        if not img then
            print("[WARN] Missing JSON sheet image: " .. imgPath)
            return
        end

        local jsonPath = spr.path:gsub("%.[^%.]+$", "") .. ".json"
        local decoded = json.decode(love.filesystem.read(jsonPath))
        if not decoded then return end

        local frames = {}

        for key, frame in pairs(decoded.frames) do
            -- Match: animname 0000.png / animname 1.png / animname123.png, etc
            local name, num = key:match("^(.-)%s*(%d+)%.png$")
            if name == animname then
                table.insert(frames, {
                    frame = frame,
                    num = tonumber(num)
                })
            end
        end

        table.sort(frames, function(a,b) return a.num < b.num end)

        local ordered = {}
        for i,v in ipairs(frames) do
            ordered[i] = v.frame
        end

        spr.anims[animTag] = {
            type = "json",
            frames = ordered,
            image = img,
            interval = extra and extra.interval or 1/24
        }

    ----------------------------------------------------------
    -- 3️⃣ Texture Packer JSON (formats that include atlas definition)
    ----------------------------------------------------------
    elseif animtype == "json" then
        local jsonPath = spr.path:gsub("%.[^%.]+$", "") .. ".json"
        local decoded = json.decode(love.filesystem.read(jsonPath))
        if not decoded or not decoded.animations or not decoded.animations[animname] then
            print("[WARN] Missing JSON animation section for: " .. animname)
            return
        end

        spr.anims[animTag] = {
            type = "json_atlas",
            frames = decoded.animations[animname],
            image = spr.image,
            interval = extra and extra.interval or 1/24
        }

    ----------------------------------------------------------
    -- 4️⃣ Quad Sheet Animations (manual)
    ----------------------------------------------------------
    elseif animtype == "quad" or animtype == "quads" then
        if not extra then
            print("[ERROR] Missing quad data for manual animation")
            return
        end

        spr.anims[animTag] = {
            type = "quad",
            quads = extra.quads or extra,
            interval = extra.interval or extra.duration or extra.time or 0.05,
            image = spr.image
        }
    ----------------------------------------------------------
    else
        print("[ERROR] Unknown animation type: " .. tostring(animtype))
    end
end

-- Removes a lua sprite from rendering
-- First parameter must be the object tag
function spritemanager:removeLuaSprite(tag)
    self.sprites[tag] = nil
    -- Uhh i don't think that sprite exists bro... im sorry
    -- i still think that sprites doesn't exist
end

function spritemanager:_applyFrameToSprite(spr, anim)
    local frameIndex = spr.frameIndex or 1
    local frame = anim.frames[frameIndex]
    if not frame then return end

    -- Animation types:
    if anim.type == "quad" then
        spr.quad = anim.quads[frameIndex]

    elseif anim.type == "json" or anim.type == "json_atlas" then
        spr.quad = love.graphics.newQuad(
            frame.frame.x, frame.frame.y,
            frame.frame.w, frame.frame.h,
            anim.image:getDimensions()
        )

    elseif anim.type == "xml" then
        if not anim.image then
            anim.image = spr.image
        end

        spr.quad = love.graphics.newQuad(
            frame.x, frame.y,
            frame.width, frame.height,
            anim.image:getWidth(), anim.image:getHeight()
        )
    end
end

function spritemanager:playAnim(tag, anim)
    local spr = self:tagToSprite(tag)
    if not spr then return end

    spr.currentAnim = anim
    spr.frameIndex = 1
    spr.frameTime = 0
    self:_applyFrameToSprite(spr, spr.anims[anim])
end

function spritemanager:stopAnim(tag)
    local spr = self:tagToSprite(tag)
    if not spr then return end

    spr.currentAnim = nil
end

function spritemanager:update(dt)
    for tag, spr in pairs(self.sprites) do
        if spr.currentAnim then
            local anim = spr.anims and spr.anims[spr.currentAnim]
            if anim then
                spr.frameTime = spr.frameTime + dt

                local interval = anim.interval or (1/24)
                if spr.frameTime >= interval then
                    spr.frameTime = spr.frameTime - interval
                    spr.frameIndex = spr.frameIndex + 1

                    -- loop animation
                    if spr.frameIndex > #anim.frames then
                        spr.frameIndex = 1
                    end

                    -- update actual sprite visual
                    self:_applyFrameToSprite(spr, anim)
                end
            end
        end
    end
end

-- Gets a property from a sprite object
-- First parameter must be the object tag
function spritemanager:getProperty(tag,property)
    local spr = self:tagToSprite(tag)
    if not spr then
        -- That is... not a real sprite...
        return
    end
    return spr[property]
end

-- Sets a property from an sprite object
-- First parameter must be the object tag
-- Second parameter must be the property of the object
-- Third parameter must be the new value of that property
function spritemanager:setProperty(tag,property,value)
    self:tagToSprite(tag)[property] = value
end

function spritemanager:addCollidable(tag, collidable)
    if not self.player then return end
    local spr = self:tagToSprite(tag)
    local id = "collidable" .. 1
    if self.player.collidables then
        id = "collidable" .. (#self.player.collidables + 1)
    end
    collidable.id = id
    -- print(collidable.id)

    if not spr.collidable then
        spr.collidable = self.player:newCollidable(spr.x, spr.y, spr.image:getWidth() * spr.sx, spr.image:getHeight() * spr.sy, collidable)
    end
end

function spritemanager:moveObject(tag, xspeed, yspeed)
    local spr = self:tagToSprite(tag)
    xspeed = xspeed or 0
    yspeed = yspeed or 0

    spr.x = spr.x + xspeed
    spr.y = spr.y + yspeed
end

-- first argument must be the sprite tag, second argument can either be "x", "y" or "xy", 
function spritemanager:centerObject(tag, centertype)
    local spr = self:tagToSprite(tag)
    centertype = centertype or "xy"
    centertype = string.lower(centertype)
    local xcenter = (love.graphics.getWidth() / 2) - (spr["image"]:getWidth() / 2)
    local ycenter = (love.graphics.getHeight() / 2) - (spr["image"]:getHeight() / 2)
    if centertype == "x" then
        spr.x = xcenter
    elseif centertype == "y" then
        spr.y = ycenter
    elseif centertype == "xy" then
        spr.x = xcenter
        spr.y = ycenter
    else
        -- Umh... invalid... input?
    end
    --spritemanager:updateSprite(spr.tag, spr)
end

function spritemanager:_draw(spr)
    if spr.quad then
        love.graphics.draw(spr.image,spr.quad,spr.x,spr.y,spr.r,spr.sx,spr.sy,spr.ox,spr.oy,spr.kx,spr.ky)
    else
        love.graphics.draw(spr.image,spr.x,spr.y,spr.r,spr.sx,spr.sy,spr.ox,spr.oy,spr.kx,spr.ky)
    end
end

function spritemanager:drawSprite(tag)
    local cam = self.camera

    if type(tag) == "string" then
        tag = self:tagToSprite(tag)
    end

    local spr = tag.sprite or tag
    local layer = string.lower(spr.layer)
    if spr.anims then
        for _,anim in pairs(spr.anims) do
            -- print(anim.frames[1].duration)
        end
    end
    if spr.visible and spr.enabled then
        if layer == "game" or not self.camera then
            self:_draw(spr)
        elseif cam and (layer == "hud" or layer == "gui" or layer == "ui") then
            cam:detach()
                self:_draw(spr)
            cam:attach()
        end
    end
end

-- Function in charge of drawing the sprites
function spritemanager:draw(tag)
    if not self.sprites then return end
    if tag then
        self:drawSprite(tag)
    end
    self.drawSprites = {}

    for id, sprite in pairs(self.sprites) do
        table.insert(self.drawSprites, {id = id, sprite = sprite})
    end

    table.sort(self.drawSprites, function(a, b)
        return a.sprite.order < b.sprite.order
    end)

    for _,value in ipairs(self.drawSprites) do
        self:drawSprite(value)
    end
end

-- Utils

-- Sets the position of a sprite object
-- First parameter must be the object tag
function spritemanager:setObjectPosition(tag, x, y)
    local spr = self:tagToSprite(tag)
    x = x or spr.x
    y = y or spr.y
    spr.x = x
    spr.y = y
end

-- Sets the scalex and scaley of an object
-- First parameter must be the object tag
function spritemanager:setObjectSize(tag, width, height)
    local spr = self:tagToSprite(tag)
    width = width or spr.sx
    height = height or spr.sy
    spr.sx = width
    spr.sy = height
end

-- Sets the draw order of an object
-- First parameter must be the object tag
function spritemanager:setObjectOrder(tag, order)
    local spr = self:tagToSprite(tag)
    order = order or 1
    spr.order = order
end

-- Sets the draw order of an object
-- First parameter must be the object tag
function spritemanager:setObjectVisible(tag, visible)
    visible = visible or true
    local spr = self:tagToSprite(tag)
    spr.visible = visible
end

-- Clears all of the sprites from drawing
function spritemanager:clearSprites()
    self.sprites = {}
end

return spritemanager