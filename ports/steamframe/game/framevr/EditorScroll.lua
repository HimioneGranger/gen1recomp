-- VR interaction around the original save editor's pixel-scrolled lists.
local Scroll={}
local runtime,input,held,direction,drag
local regions,activeKit={},nil
local installed=setmetatable({},{__mode="k"})
function Scroll.install(r,i) runtime,input=r,i; Scroll.reset() end
function Scroll.reset() held,direction,drag=0,0,nil; regions={} end
function Scroll.isActive()
  return runtime and runtime.isBridgeActive() and input.kind=="editor"
end
function Scroll.controlsWheel()
  if not Scroll.isActive() then return false end
  local p=input.pointer or activeKit and {x=activeKit.mouseX,y=activeKit.mouseY}
  if not p or not p.x or not p.y then return false end
  for _,r in ipairs(regions) do
    if p.x>=r.x and p.x<=r.x+r.w+16*(activeKit.scale or 1) and p.y>=r.y and p.y<=r.y+r.h then return true end
  end
  return false
end
function Scroll.update(value,dt)
  if not Scroll.isActive() then Scroll.reset(); return end
  if not input.mouseDown then drag=nil end
  if not Scroll.controlsWheel() then held,direction=0,0; return end
  value=tonumber(value) or 0
  local sign=value>0.28 and 1 or value< -0.28 and -1 or 0
  if sign==0 then held,direction=0,0; return end
  dt=math.max(0,math.min(tonumber(dt) or 0,0.05))
  if sign~=direction then held=0 end
  direction=sign
  held=held+dt
  local speed=8+12*math.min(1,math.max(0,(held-0.4)/0.6))
  if love.wheelmoved then love.wheelmoved(0,value*speed*dt) end
end
function Scroll.attach(Kit)
  if not Kit or type(Kit.scrollPixels)~="function" then return false end
  activeKit=Kit
  if installed[Kit] then return true end
  installed[Kit]=true
  local begin=Kit.beginFrame
  if begin then Kit.beginFrame=function(...) regions={}; return begin(...) end end
  local original=Kit.scrollPixels
  Kit.scrollPixels=function(x,y,w,h,offset,content)
    if not Scroll.isActive() or Kit.blockClicks then return original(x,y,w,h,offset,content) end
    local max=math.max(0,(content or 0)-h)
    if max>0 then regions[#regions+1]={x=x,y=y,w=w,h=h} end
    local p=input.pointer
    if not input.mouseDown then drag=nil end
    if max>0 and h>0 and p and input.mouseDown then
      local key=x..":"..y..":"..w..":"..h
      local scale=Kit.scale or 1
      local thumb=math.min(h,math.max(18*scale,h*h/(h+max)))
      local origin=input.mouseOrigin
      if not drag and origin and origin.x>=x+w-12*scale and origin.x<=x+w+16*scale
          and origin.y>=y and origin.y<=y+h then
        local top=y+(h-thumb)*math.max(0,math.min(offset or 0,max))/max
        local grab=origin.y>=top and origin.y<=top+thumb and origin.y-top or thumb/2
        drag={key=key,grab=grab}
      end
      if drag and drag.key==key then
        Kit.mouseClicked=false
        Kit._pointerDrag,Kit._drag=nil,nil
        return math.max(0,math.min(max,(p.y-y-drag.grab)/math.max(1,h-thumb)*max))
      end
    end
    return original(x,y,w,h,offset,content)
  end
  print("[frame-scroll] r11 save editor smooth stick scroll and laser scrollbar installed")
  return true
end
return Scroll
