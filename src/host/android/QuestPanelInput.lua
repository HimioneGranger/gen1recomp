-- Pointer routing for the existing panel editors. Gameplay keeps its own input.
local Panel = {}
local supported = { editor = true, touch_editor = true, skin_studio = true }
local function call(subject, name, ...)
  if subject and type(subject[name]) == "function" then return subject[name](...) end
end

function Panel.new(backend)
  local self = { backend = backend, armed = false }
  local mouse = love.mouse
  local position, down = mouse.getPosition, mouse.isDown
  mouse.getPosition = function(...)
    if self.pointer then return self.pointer.x, self.pointer.y end
    return position(...)
  end
  local getX, getY = mouse.getX, mouse.getY
  if getX then mouse.getX = function() return self.pointer and self.pointer.x or getX() end end
  if getY then mouse.getY = function() return self.pointer and self.pointer.y or getY() end end
  mouse.isDown = function(...)
    if self:isActive() then
      local queriedPrimary = false
      for i = 1, select("#", ...) do
        if select(i, ...) == 1 then
          queriedPrimary = true
          if self.held then return true end
        elseif down and down(select(i, ...)) then return true end
      end
      if queriedPrimary then return false end
    end
    return down and down(...) or false
  end

  function self:release()
    local p = self.pointer or self.lastPointer or {x=0,y=0}
    self.held = false
    if self.pressed then call(self.subject, "mousereleased", p.x, p.y, 1) end
    self.pressed = false
  end

  function self:setOwner(kind, subject)
    if kind == self.kind and subject == self.subject then return end
    self:release()
    if self.scroll then self.scroll:reset() end
    self.pointer, self.lastPointer, self.dragHand = nil, nil, nil
    self.kind, self.subject = kind, subject
    self.armed = false -- A held trigger cannot click through a scene change.
  end

  function self:isActive() return supported[self.kind] and self.subject ~= nil end

  function self:update(dt)
    if not self:isActive() then return end
    local b = self.backend
    local ok, state = pcall(function() return b.native.questxr_poll_panel_input_state() end)
    state = ok and tonumber(state) or nil
    local focused = state == nil or b.bit.band(state, 4) ~= 0
    local heldMask = state and b.bit.band(state, 3) or 0
    if heldMask == 0 then self.armed = true end
    local last = self.pointer
    local hand = self.dragHand or b.activePointerHand
    local x, y, active = b:pointerValues(hand)
    if not active and not self.dragHand then
      hand = hand == 1 and 2 or 1
      x, y, active = b:pointerValues(hand)
    end
    if not focused or not active then
      self:release()
      self.pointer, self.dragHand, self.armed = nil, nil, false
      if self.scroll then self.scroll:reset() end
      return
    end
    b.activePointerHand = hand
    local w, h = love.graphics.getDimensions()
    self.pointer = {x=math.max(0,math.min(w,x*w)), y=math.max(0,math.min(h,(1-y)*h))}
    self.lastPointer = self.pointer
    local handHeld = b.bit.band(heldMask, hand == 1 and 1 or 2) ~= 0
    if self.pressed and not handHeld then self:release(); self.dragHand = nil end
    local pad = package.loaded["src.ui.PadCursor"]
    if pad then
      pad.gamepadaxis(nil, "leftx", 0)
      pad.gamepadaxis(nil, "lefty", 0)
      pad.gamepadaxis(nil, "righty", 0)
      pad.yieldToPointer()
    end
    call(self.subject, "mousemoved", self.pointer.x, self.pointer.y,
      last and self.pointer.x-last.x or 0, last and self.pointer.y-last.y or 0)
    if self.kind == "editor" then
      local Kit = package.loaded["Kit"]
      if Kit then
        if self.scrollKit ~= Kit then
          if self.scroll then self.scroll:detach() end
          self.scroll = require("src.host.android.QuestEditorScroll").attach(Kit)
          self.scrollKit = Kit
        end
        local scrollY = tonumber(b.axisY[0]) or 0
        local scrollOk, rightY = pcall(function() return b.native.questxr_poll_panel_scroll_y() end)
        rightY = scrollOk and tonumber(rightY) or 0
        if math.abs(rightY or 0) > 0.28 then scrollY = rightY end
        self.scroll:begin(self.pointer, scrollY, dt, self.held, self.subject)
      end
    elseif self.scroll then self.scroll:reset() end
  end

  function self:select(hand)
    if not self:isActive() then return false end
    -- Reselect from the hand that actually pulled the trigger, not a moving ray.
    local b = self.backend
    hand = hand == 1 and 1 or hand == 2 and 2 or b.activePointerHand
    local x, y, active = b:pointerValues(hand)
    local ok, state = pcall(function() return b.native.questxr_poll_panel_input_state() end)
    state = ok and tonumber(state) or nil
    if not self.armed or not active or (state and b.bit.band(state,4)==0) then return true end
    self:release()
    local w,h = love.graphics.getDimensions()
    self.pointer = {x=math.max(0,math.min(w,x*w)),y=math.max(0,math.min(h,(1-y)*h))}
    self.lastPointer, self.dragHand = self.pointer, hand
    b.activePointerHand = hand
    self.held, self.pressed = true, true
    if self.kind == "editor" and self.scroll then
      self.scroll:begin(self.pointer, 0, 0, true, self.subject)
    end
    call(self.subject,"mousepressed",self.pointer.x,self.pointer.y,1)
    -- Legacy bridges still support a complete tap; they cannot latch a drag.
    if not state then self:release(); self.dragHand = nil end
    return true
  end

  function self:key(key)
    if not self:isActive() then return false end
    if key == "escape" then
      self:release()
      call(self.subject, "keypressed", key)
    end
    return true -- Continuous axes own direction; no second focus cursor.
  end
  return self
end
return Panel
