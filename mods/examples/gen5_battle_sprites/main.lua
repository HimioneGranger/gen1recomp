-- Native asset-pack example. All sprite pixels come from the player's cache.
local mod = ...
local MAX_IMAGE = 8 * 1024 * 1024
local clock, reason, ready, warned = 0, "Gen 5 sprite pack is not installed", false, false
local entries, images, slots, atlases = {}, {}, {}, {}
local serial, imageCount, atlasCount = 0, 0, 0
local function integer(n, lo, hi)
  return type(n) == "number" and n == n and n % 1 == 0 and n >= lo and n <= hi
end
local function warn(message)
  reason = tostring(message)
  if not warned then
    warned = true
    mod.log:warn("Gen 5 sprites unavailable: %s. Import your own Black/White ROM in the launcher; native sprites remain active.", reason)
  end
end
local function loadIndex()
  local info, err = mod.packs:info("gen5_bw", "battle_sprites")
  if not info then error(err or reason, 0) end
  local list, listErr = mod.packs:entries("gen5_bw", "battle_sprites")
  if type(list) ~= "table" or #list > 10000 then error(listErr or "invalid pack entries", 0) end
  for _, raw in ipairs(list) do
    local s = raw.sprite
    if type(raw.id) ~= "string" or #raw.id > 80 or type(s) ~= "table"
        or not integer(s.width, 1, 256) or not integer(s.height, 1, 256)
        or not integer(s.columns, 1, 512) or not integer(s.frames, 1, 512)
        or s.tickRate ~= 60 or type(s.durations) ~= "table" or #s.durations ~= s.frames
        or not integer(raw.size, 24, MAX_IMAGE)
        or raw.width ~= s.width * s.columns
        or raw.height ~= s.height * math.ceil(s.frames / s.columns)
        or raw.width * raw.height > 4 * 1024 * 1024 then
      error("invalid pack sprite metadata " .. tostring(raw.id), 0)
    end
    local total, intro = 0, 0
    local loop = s.loopStartFrame or 0
    if not integer(loop, 0, s.frames - 1) then error("invalid animation loop start", 0) end
    for i, duration in ipairs(s.durations) do
      if not integer(duration, 1, 3600000) then error("invalid tick duration", 0) end
      total = total + duration
      if i <= loop then intro = intro + duration end
    end
    if s.cycleTicks ~= nil and s.cycleTicks ~= total then error("animation cycle length mismatch", 0) end
    if s.cycleCapped ~= true then
      entries[raw.id] = {width=s.width,height=s.height,columns=s.columns,frames=s.frames,
        durations=s.durations,total=total,intro=intro,loop=loop,size=raw.size,
        atlasWidth=raw.width,atlasHeight=raw.height}
    end
  end
  ready, reason = true, nil
end
local function release(value)
  if value and value.release then value:release() end
end
local function imageFor(id, entry, frame)
  local key = id .. ":" .. frame
  serial = serial + 1
  if images[key] then images[key].used = serial; return images[key].image end
  local data = atlases[id] and atlases[id].data
  if data then atlases[id].used = serial end
  if not data then
  local bytes, err = mod.packs:read("gen5_bw", "battle_sprites", id)
  if type(bytes) ~= "string" or #bytes ~= entry.size or #bytes > MAX_IMAGE then error(err or "invalid pack image length", 0) end
  -- IHDR is checked before decoding: a tiny compressed PNG must not allocate
  -- an arbitrary-size image. Atlas dimensions come from validated metadata.
  if bytes:sub(1, 8) ~= "\137PNG\13\10\26\10" or bytes:sub(13,16) ~= "IHDR" then error("invalid PNG", 0) end
  local function be(pos)
    local a,b,c,d = bytes:byte(pos, pos + 3)
    return a * 16777216 + b * 65536 + c * 256 + d
  end
  local aw, ah = entry.atlasWidth, entry.atlasHeight
  if aw * ah > 4 * 1024 * 1024 or be(17) ~= aw or be(21) ~= ah then error("PNG dimensions do not match index", 0) end
  local file = love.filesystem.newFileData(bytes, "private-gen5.png")
  data = love.image.newImageData(file)
  release(file)
  if atlasCount >= 4 then
    local oldest, used
    for candidate, item in pairs(atlases) do
      if not used or item.used < used then oldest, used = candidate, item.used end
    end
    release(atlases[oldest].data); atlases[oldest] = nil; atlasCount = atlasCount - 1
  end
  atlases[id], atlasCount = {data = data, used = serial}, atlasCount + 1
  end
  local out = love.image.newImageData(64, 64)
  local scale = math.min(64 / entry.width, 64 / entry.height, 1)
  local w, h = math.max(1, math.floor(entry.width * scale)), math.max(1, math.floor(entry.height * scale))
  local ox, oy = math.floor((64 - w) / 2), 64 - h
  local sx = ((frame - 1) % entry.columns) * entry.width
  local sy = math.floor((frame - 1) / entry.columns) * entry.height
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      out:setPixel(ox + x, oy + y, data:getPixel(sx + math.floor(x / scale), sy + math.floor(y / scale)))
    end
  end
  local image = love.graphics.newImage(out)
  release(out)
  image:setFilter("nearest", "nearest")
  if imageCount >= 8 then
    local oldest, used
    for candidate, item in pairs(images) do
      if not used or item.used < used then oldest, used = candidate, item.used end
    end
    release(images[oldest].image); images[oldest] = nil; imageCount = imageCount - 1
  end
  images[key], imageCount = {image = image, used = serial}, imageCount + 1
  return image
end

local function clear()
  for _, item in pairs(images) do release(item.image) end
  for _, item in pairs(atlases) do release(item.data) end
  images, atlases, slots, imageCount, atlasCount, clock = {}, {}, {}, 0, 0, 0
end

mod.exports.api = 1
mod.exports.apiVersion = 1
-- Art generation is independent of the receiving game or voxel engine.
mod.exports.capabilities = {
  contract = "national-dex-battle-sprites", version = 1,
  source = "gen5_bw", maxDex = 649, sides = {"front", "back"},
  shiny = true, female = true, frameWidth = 64, frameHeight = 64,
  clock = "input.step", optional = true,
}
function mod.exports.status()
  return {ready = ready, reason = reason, cachedImages = imageCount, cachedAtlases = atlasCount}
end
-- Advanced by input.step once per simulation update; never by eye draws.
function mod.exports.update(dt)
  if type(dt) == "number" and dt == dt and dt >= 0 and dt < math.huge then clock = clock + dt * 1000 end
end
function mod.exports.frame(request)
  if not ready or type(request) ~= "table" or not integer(request.dex, 1, 649)
      or (request.side ~= "front" and request.side ~= "back")
      or (request.form ~= nil and request.form ~= 0 and request.form ~= "normal") then return nil end
  local id = (request.shiny and "shiny/" or "normal/") .. string.format("%03d", request.dex) .. "/" .. request.side
  local female = request.gender == "female" or request.gender == "F" or request.gender == 2
  if female and entries[id .. "/female"] then id = id .. "/female" end
  local entry = entries[id]
  if not entry then return nil end
  local slotKey = tostring(request.battleId or "battle") .. "/" .. tostring(request.battlerId or request.side)
  local slot = slots[slotKey]
  if not slot or slot.id ~= id or slot.mon ~= request.mon then
    local count = 0
    for _ in pairs(slots) do count = count + 1 end
    if count >= 16 then slots = {} end
    slot = {id = id, mon = request.mon, started = clock}; slots[slotKey] = slot
  end
  -- Keep identity storage bounded across battles, without advancing animation.
  if not slot.touched or clock - slot.touched > 60000 then
    for key, value in pairs(slots) do if clock - (value.touched or value.started) > 60000 then slots[key] = nil end end
  end
  slot.touched = clock
  local elapsed = math.floor((clock - slot.started) * 60 / 1000 + 1e-7)
  local phase, frame = elapsed, 1
  if elapsed >= entry.intro then
    phase = entry.intro + (elapsed - entry.intro) % (entry.total - entry.intro)
  end
  for i, duration in ipairs(entry.durations) do
    if phase < duration then frame = i; break end
    phase = phase - duration
  end
  local ok, image = pcall(imageFor, id, entry, frame)
  if not ok then entries[id] = nil; warn(image); return nil end
  return {image = image, width = 64, height = 64, groundOffset = 32, frame = frame, entryId = id}
end
local ok, err = pcall(loadIndex)
if not ok then entries = {}; warn(err) end
local function capture(...) return {n=select("#",...),...} end
mod.hooks:wrap("input.step", function(next, game, dt)
  local result = capture(next(game, dt))
  mod.exports.update(dt)
  return unpack(result,1,result.n)
end)
mod.events:on("core.session_ending", clear)
