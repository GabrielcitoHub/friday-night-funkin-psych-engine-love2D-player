-- fnf_xml_to_lua.lua
-- A standalone Lua script to parse a generic XML (FNF charts or similar) into a Lua table
-- and optionally serialize that table to a Lua source file.
-- No external dependencies. Works with Lua 5.1+ (including LuaJIT).

-- Usage examples at the bottom.

local M = {}

-- Trim helpers
local function trim(s) return (s:gsub("^%s+","") :gsub("%s+$","")) end

-- Parse attributes from a tag's inside string, e.g. ' id="1" note="up"'
local function parse_attributes(s)
  local attrs = {}
  ---@diagnostic disable-next-line
  for k, v in s:gmatch('%s*([%w:_-]+)%s*=\s*"([^"]*)"') do
    attrs[k] = v
  end
  ---@diagnostic disable-next-line
  for k, v in s:gmatch("%s*([%w:_-]+)%s*=\s*'([^']*)'") do
    attrs[k] = v
  end
  return attrs
end

-- Parse next node (recursive). Returns node, new_position
local function parse_node(xml, pos)
  local _, s, tag, rest, closepos = xml:find("<(%/?[%w:_-]+)(.-)(%/?)>", pos)
  if not s then return nil, pos end

  local is_closing = tag:sub(1,1) == '/'
  if is_closing then
    -- closing tag, shouldn't happen here at top-level
    return nil, closepos + 1
  end

  local node = { tag = tag, attr = parse_attributes(rest), children = {}, text = nil }
  pos = closepos + 1

  -- self closing
  if rest:match("/%s*$") or rest:match("/%s+$") or rest:match("/$") then
    return node, pos
  end

  -- read until matching closing tag
  local contentStart = pos
  while true do
    local nextOpenStart = xml:find("<", pos)
    if not nextOpenStart then
      -- no more tags: take rest as text
      local text = trim(xml:sub(contentStart))
      if #text > 0 then node.text = text end
      return node, #xml+1
    end

    -- if there's text before next tag, add as text child
    if nextOpenStart > pos then
      local text = xml:sub(pos, nextOpenStart-1)
      text = trim(text)
      if #text > 0 then
        table.insert(node.children, text)
      end
      pos = nextOpenStart
    end

    -- look what the next tag is
    local _, t2s, t2tag, t2rest, t2closepos = xml:find("<(%/?[%w:_-]+)(.-)(%/?)>", pos)
    if not t2s then
      -- malformed
      break
    end

    if t2tag:sub(1,1) == '/' then
      -- closing tag
      local closingName = t2tag:sub(2)
      if closingName == node.tag then
        -- consume closing, done
        pos = t2closepos + 1
        return node, pos
      else
        -- mismatched closing: include as text and continue
        pos = t2closepos + 1
      end
    else
      -- child node or self-closing child
      local child, newpos = parse_node(xml, pos)
      if not child then
        pos = newpos
        break
      end
      table.insert(node.children, child)
      pos = newpos
    end
  end

  return node, pos
end

-- Parse the whole XML into a table of nodes (skips leading prolog and comments)
function M.parse_xml(xml)
  local nodes = {}
  local pos = 1
  while true do
    local s, e, tag, rest = xml:find("<%?xml(.-)%?>", pos)
    if s then pos = e + 1 else break end
  end

  while true do
    local s = xml:find("<%-%-", pos)
    if s then
      local e = xml:find("%-%->", s)
      if not e then break end
      xml = xml:sub(1, s-1) .. xml:sub(e+3)
    else break end
  end

  pos = 1
  while true do
    local node, newpos = parse_node(xml, pos)
    if not node then break end
    table.insert(nodes, node)
    pos = newpos
    if pos > #xml then break end
  end
  return nodes
end

-- Convert parsed nodes to a simplified Lua-friendly table.
-- This tries to convert repeated children of same tag into arrays.
local function simplify_node(node)
  if type(node) == 'string' then return node end
  local out = {}
  -- copy attributes
  for k, v in pairs(node.attr) do out[k] = v end

  -- group children by tag or keep text
  for _, child in ipairs(node.children) do
    if type(child) == 'string' then
      -- text node (trim and set as _text)
      local t = trim(child)
      if #t > 0 then
        if out._text then out._text = out._text .. ' ' .. t else out._text = t end
      end
    else
      local tag = child.tag
      local simplified = simplify_node(child)
      if out[tag] then
        if type(out[tag]) ~= 'table' or (type(out[tag])=='table' and out[tag][1]==nil) then
          -- convert to array
          out[tag] = { out[tag] }
        end
        table.insert(out[tag], simplified)
      else
        out[tag] = simplified
      end
    end
  end
  -- if a node has text directly (node.text), prefer it
  if node.text and #trim(node.text) > 0 then out._text = trim(node.text) end
  return out
end

function M.xml_to_table(xml)
  local nodes = M.parse_xml(xml)
  -- if there's a single root node, return its simplified form
  if #nodes == 1 then
    local root = nodes[1]
    local t = {}
    t[root.tag] = simplify_node(root)
    return t
  else
    local t = {}
    for i, n in ipairs(nodes) do t[i] = { [n.tag] = simplify_node(n) } end
    return t
  end
end

-- Pretty-print lua value (serialize) with indentation
local function is_identifier(s)
  return type(s)=='string' and s:match('^[_%a][_%w]*$')
end
local function quote_str(s)
  s = s:gsub('\\','\\\\'):gsub('\"','\\\"'):gsub('\n','\\n')
  return '"'..s..'"'
end

local function serialize(val, indent, visited)
  indent = indent or ''
  visited = visited or {}
  local t = type(val)
  if t=='nil' then return 'nil' end
  if t=='number' or t=='boolean' then return tostring(val) end
  if t=='string' then return quote_str(val) end
  if t=='table' then
    if visited[val] then return 'nil --[[circular]]' end
    visited[val] = true
    -- detect array-like
    local is_array = true
    local maxn = 0
    for k in pairs(val) do
      if type(k) ~= 'number' then is_array = false; break end
      if k > maxn then maxn = k end
    end
    local parts = {}
    if is_array and maxn > 0 then
      for i=1,maxn do
        table.insert(parts, indent..'  '..serialize(val[i], indent..'  ', visited))
      end
      return '{\n'..table.concat(parts, ',\n')..'\n'..indent..'}'
    else
      for k,v in pairs(val) do
        local key
        if is_identifier(k) then key = k else key = '['..serialize(k, indent..'  ', visited)..']' end
        local value = serialize(v, indent..'  ', visited)
        table.insert(parts, indent..'  '..key..' = '..value)
      end
      return '{\n'..table.concat(parts, ',\n')..'\n'..indent..'}'
    end
  end
  return 'nil'
end

-- Write a Lua source file that returns the table
function M.table_to_lua_file(tbl, filename)
  local f, err = io.open(filename, 'w')
  if not f then return nil, err end
  f:write('-- Generated by fnf_xml_to_lua.lua\n')
  f:write('return ')
  f:write(serialize(tbl, '', {}))
  f:close()
  return true
end

-- Convenience function: parse xml string and write lua file
function M.convert_xml_string_to_lua_file(xmlstring, outfilename)
  local ok, tbl = pcall(function() return M.xml_to_table(xmlstring) end)
  if not ok then return nil, 'parse failed' end
  return M.table_to_lua_file(tbl, outfilename)
end

-- CLI support when run as a script
if not (...) then
  local arg = arg or {}
  if #arg >= 1 then
    local infile = arg[1]
    local outfile = arg[2] or (infile:gsub('%.[^%.]+$','') .. '.lua')
    local f, e = io.open(infile, 'r')
    if not f then io.stderr:write('Cannot open '..tostring(infile)..' - '..tostring(e) .. '\n'); os.exit(1) end
    local data = f:read('*a') f:close()
    local ok, err = M.convert_xml_string_to_lua_file(data, outfile)
    if ok then print('Wrote '..outfile) else io.stderr:write('Error: '..tostring(err).."\n") end
  else
    print('\nfnf_xml_to_lua.lua - usage: lua fnf_xml_to_lua.lua input.xml [output.lua]\n')
  end
end

-- Example usage (as comments):
-- local xml = io.open('chart.xml','r'):read('*a')
-- local t = require('fnf_xml_to_lua').xml_to_table(xml)
-- print(require('fnf_xml_to_lua').table_to_lua_file(t, 'chart.lua'))

return M
