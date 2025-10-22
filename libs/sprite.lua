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
        error("Sprite with tag \"" .. tag .. "\" not found")
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
---@param extra table|nil Extra animation parameters
function spritemanager:addLuaAnimation(tag, animname, animtype, extra)
    animtype = string.lower(animtype) or self.animExt or "xml"
    local spr = self:tagToSprite(tag)
    if animtype == "xml" then
    elseif animtype == "librejson" then
        local folder = spr.path:match("^(.*)/") .. "/"
        local animpath = folder .. animname .. "-sheet.png"
        local animImage = self:findImage(animpath)
        local json_decoded = json.decode(love.filesystem.read(string.gsub(spr.path, "%.[^%.]+$", "") .. ".json"))
        local newframes = {}
        if not json_decoded then return end
        for key,frame in pairs(json_decoded.frames) do
            local str = key
            -- Capture everything up to the last space, then capture number + extension
            local name, num, ext = str:match("^(.*)%s+(%d+)%.([^.]+)$")
            if name == animname then
                local framedata = {
                    frame = frame,
                    num = tonumber(num),
                    image = animImage
                }
                table.insert(newframes, framedata)
            end

            -- print("Name: ", name)
            -- print("Num: ", num)
            -- print("Ext: ", ext)
        end
        table.sort(newframes, function(a, b)
            return a.num < b.num
        end)
        for i,v in ipairs(newframes) do
            newframes[i] = v.frame
        end

        local animdata = {
            type = "json",
            image = animImage,
            frames = newframes
        }

        spr.anims[animname] = animdata
    elseif animtype == "json" then
    elseif animtype == "quad" or animtype == "quads" then
        if not extra then return end
        local quads = extra.quads or extra
        local interval = extra.interval or extra.duration or extra.time
        local animdata = {
            type = "quad",
            quads = quads,
            interval = interval
        }
        self.anims[animname] = animdata
    end
end

-- Removes a lua sprite from rendering
-- First parameter must be the object tag
function spritemanager:removeLuaSprite(tag)
    local spr = self:tagToSprite(tag)
    spr = nil
    -- Uhh i don't think that sprite exists bro... im sorry
    -- i still think that sprites doesn't exist
end

function spritemanager:update()
    -- for tag,spr in pairs(self.sprites) do
    --     if spr.onCollide then
    --     end
    -- end
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
            love.graphics.draw(spr.image,spr.x,spr.y,spr.r,spr.sx,spr.sy,spr.ox,spr.oy,spr.kx,spr.ky)
        elseif cam and (layer == "hud" or layer == "gui" or layer == "ui") then
            cam:detach()
                love.graphics.draw(spr.image,spr.x,spr.y,spr.r,spr.sx,spr.sy,spr.ox,spr.oy,spr.kx,spr.ky)
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

-- Clears all of the sprites from drawing
function spritemanager:clearSprites()
    self.sprites = {}
end

return spritemanager