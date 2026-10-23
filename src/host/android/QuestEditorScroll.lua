-- Scoped adapter for the Quest owner's save-editor Kit instance.
-- begin must precede the editor draw; held is explicit native pointer state.
local Scroll = {}
local attached = setmetatable({}, { __mode = 'k' })
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
local function inside(p, r)
  return p and p.x and p.y and p.x >= r.x and p.x <= r.x+r.w
    and p.y >= r.y and p.y <= r.y+r.h
end
local function key(kind,x,y,w,h) return table.concat({kind,x,y,w,h}, ':') end

function Scroll.attach(Kit)
  assert(type(Kit)=='table' and type(Kit.scroll)=='function'
    and type(Kit.scrollPixels)=='function', 'save-editor Kit required')
  if attached[Kit] then return attached[Kit] end
  local self = { Kit=Kit }
  local original = {}
  for _,n in ipairs({'beginFrame','endFrame','press','scroll','scrollPixels','scrollbar'}) do
    original[n]=Kit[n]
  end
  function self:reset()
    self.regions, self.current, self.fractions = {}, {}, {}
    self.drag, self.down, self.ready, self.direction, self.duration = nil,false,false,0,0
    self.pointer, self.pending, self.claimed = nil,nil,false
    Kit._drag=nil
  end
  self:reset()
  function self:begin(pointer, scrollY, dt, held, origin)
    if origin ~= self.origin then self:reset(); self.origin=origin end
    local down = held == true
    self.fresh = self.ready and down and not self.down
    self.down = down
    self.pointer = pointer and {x=pointer.x,y=pointer.y} or nil
    if not down then self.drag=nil; self.ready=true end
    local value=tonumber(scrollY) or 0
    local sign=value>0.28 and 1 or value< -0.28 and -1 or 0
    local over=false
    for _,r in ipairs(self.regions) do if inside(self.pointer,r.body) then over=true; break end end
    if sign==0 or not over then self.direction,self.duration=0,0; value=0
    else
      if sign~=self.direction then self.duration=0 end
      self.direction=sign
      dt=clamp(tonumber(dt) or 0,0,0.05)
      self.duration=self.duration+dt
      value=value*(8+12*clamp((self.duration-0.4)/0.6,0,1))*dt
    end
    self.pending=value
  end
  local function blockedTrack()
    if self.drag then return true end
    for _,r in ipairs(self.regions) do
      if inside(self.pointer,r.track) and inside(self.pointer,r.clip or r.body) then return true end
    end
    return false
  end
  Kit.beginFrame=function(mx,my,clicked,wheel)
    original.beginFrame(mx,my,clicked,wheel)
    if self.pending==nil then return end
    if self.pointer then Kit.mouseX,Kit.mouseY=self.pointer.x,self.pointer.y end
    Kit.mouseDown=false -- this adapter owns drags; never acquire baseline mid-hold.
    Kit._drag=nil
    Kit.wheelY=(wheel or 0)+self.pending
    self.current={}; self.claimed=false
    if blockedTrack() then Kit.mouseClicked=false end
  end
  Kit.press=function(...)
    if self.pending~=nil and blockedTrack() then return false end
    return original.press(...)
  end
  local function drawTrack(x,y,w,h,offset,total,visible)
    local max=total-visible
    if max<=0 or h<=0 or visible<=0 then return end
    local scale=Kit.scale or 1
    local bw=math.min(w,math.max(26,30*scale))
    local thumb=math.min(h,math.max(30*scale,h*visible/total))
    local G=love and love.graphics
    if G and G.rectangle and G.setColor then
      local r,g,b,a
      if G.getColor then r,g,b,a=G.getColor() end
      G.setColor(0.15,0.2,0.25,0.85); G.rectangle('fill',x+w-bw,y,bw,h,5,5)
      G.setColor(0.3,0.65,1,0.95)
      G.rectangle('fill',x+w-bw+3,y+(h-thumb)*clamp(offset or 0,0,max)/max,
        math.max(1,bw-6),thumb,5,5)
      if r then G.setColor(r,g,b,a) end
    end
  end
  local function apply(kind,x,y,w,h,offset,total,visible,step)
    local max=math.max(0,total-visible)
    offset=clamp(offset or 0,0,max)
    if Kit.blockClicks then self.drag=nil; return offset end
    if w<=0 or h<=0 or visible<=0 then return offset end
    local id=key(kind,x,y,w,h)..':'..total..':'..visible..':'..(step or 1)
    local scale=Kit.scale or 1
    local bw=math.min(w,math.max(26,30*scale))
    local track={x=x+w-bw,y=y,w=bw,h=h}
    local body={x=x,y=y,w=w,h=h}
    local clip=Kit._clipRect
    local thumb=math.min(h,math.max(30*scale,h*visible/math.max(visible,total)))
    local top=y+(h-thumb)*(max>0 and offset/max or 0)
    if max>0 then
      self.current[#self.current+1]={track=track,body=body,clip=clip and
        {x=clip.x,y=clip.y,w=clip.w,h=clip.h} or nil}
      if self.fresh and not self.claimed and not self.drag and inside(self.pointer,track)
          and Kit.hit(x,y,w,h) then
        self.drag={id=id,grab=(self.pointer.y>=top and self.pointer.y<=top+thumb)
          and self.pointer.y-top or thumb/2}
        self.claimed=true
      end
      if self.drag and self.drag.id==id then
        self.claimed=true; Kit.mouseClicked=false; Kit.wheelY=0
        if self.down and self.pointer then
          offset=clamp((self.pointer.y-y-self.drag.grab)/math.max(1,h-thumb)*max,0,max)
        end
      elseif not self.claimed and Kit.hit(x,y,w,h) and (Kit.wheelY or 0)~=0 then
        local unit=kind=='px' and 48*scale or (step or math.max(1,math.min(3,visible)))
        local delta=-Kit.wheelY*unit
        Kit.wheelY=0
        if kind=='rows' then
          local quantum=math.max(1,step or 1)
          local amount=(self.fractions[id] or 0)+delta
          local whole=amount>=0 and math.floor(amount/quantum)*quantum or math.ceil(amount/quantum)*quantum
          self.fractions[id]=amount-whole
          offset=clamp(offset+whole,0,max)
        else offset=clamp(offset+delta,0,max) end
      end
      if kind=='rows' then
        local quantum=math.max(1,step or 1)
        offset=clamp(math.floor(offset/quantum+0.5)*quantum,0,max)
      end
      if kind=='px' then drawTrack(x,y,w,h,offset,total,visible) end
    end
    return offset
  end
  Kit.scroll=function(x,y,w,h,offset,total,perPage,step)
    if self.pending==nil then return original.scroll(x,y,w,h,offset,total,perPage,step) end
    return apply('rows',x,y,w,h,offset,total or 0,perPage or 0,step)
  end
  Kit.scrollPixels=function(x,y,w,h,offset,contentH)
    if self.pending==nil then return original.scrollPixels(x,y,w,h,offset,contentH) end
    return apply('px',x,y,w,h,offset,contentH or 0,math.max(0,h))
  end
  Kit.scrollbar=function(x,y,w,h,offset,total,perPage)
    if self.pending==nil then return original.scrollbar(x,y,w,h,offset,total,perPage) end
    drawTrack(x,y,w,h,offset,total or 0,perPage or 0)
  end -- row lists draw after their content; pixel lists draw in scrollPixels.
  Kit.endFrame=function(...)
    original.endFrame(...)
    if self.pending~=nil then self.regions=self.current end
    self.pending=nil
  end
  function self:detach()
    for n,f in pairs(original) do Kit[n]=f end
    attached[Kit]=nil; self:reset()
  end
  attached[Kit]=self
  return self
end
return Scroll
