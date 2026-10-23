-- An OpenXR controller exposed through LÖVE's normal gamepad/mouse boundary.
-- The official launcher and engine keep their own callbacks and input logic.
local Input = {buttons={},axes={},pointer=nil,subject=nil,kind=nil}
local previous, previousTrigger, recenterHeld = {}, false, false
local neutralRequired = true
local pad = {}
function pad:isGamepad() return true end
function pad:isConnected() return true end
function pad:getID() return 485,485 end
function pad:getName() return "Steam Frame OpenXR Controller" end
function pad:getGUID() return "frame-openxr-controller" end
function pad:getGamepadMappingString() return "" end
function pad:getButtonCount() return 0 end
function pad:getAxisCount() return 4 end
function pad:getHatCount() return 0 end
function pad:isGamepadDown(...)
  for i=1,select("#",...) do if Input.buttons[select(i,...)] then return true end end
  return false
end
function pad:getGamepadAxis(axis) return Input.axes[axis] or 0 end
function pad:getVibration() return 0,0 end
function pad:setVibration() return false end
Input.pad = pad

function Input.install(runtime,panel)
  Input.runtime,Input.panel=runtime,panel
  local js=love.joystick
  Input.originalJoysticks,Input.originalCount=js.getJoysticks,js.getJoystickCount
  js.getJoysticks=function()
    local list=Input.originalJoysticks()
    if runtime.isBridgeActive() then list[#list+1]=pad end
    return list
  end
  js.getJoystickCount=function()
    return Input.originalCount()+(runtime.isBridgeActive() and 1 or 0)
  end
  local mouse=love.mouse
  Input.originalPosition,Input.originalX,Input.originalY=mouse.getPosition,mouse.getX,mouse.getY
  mouse.getPosition=function()
    if Input.pointer then return Input.pointer.x,Input.pointer.y end
    return Input.originalPosition()
  end
  mouse.getX=function() local x=mouse.getPosition(); return x end
  mouse.getY=function() local _,y=mouse.getPosition(); return y end
  Input.originalMouseDown=mouse.isDown
  mouse.isDown=function(...)
    if Input.mouseDown and runtime.isBridgeActive() then
      for i=1,select("#",...) do if select(i,...)==1 then return true end end
    end
    return Input.originalMouseDown(...)
  end
end

function Input.setSubject(kind,subject)
  if subject~=Input.subject or kind~=Input.kind then
    Input.subject,Input.kind=subject,kind
    neutralRequired=true
    Input.release()
  end
end

function Input.release()
  Input.mouseDown,Input.mouseOrigin=false,nil
  local scroll=package.loaded["framevr.EditorScroll"]
  if scroll then scroll.reset() end
  for key,held in pairs(previous) do
    if held and love.gamepadreleased then love.gamepadreleased(pad,key) end
  end
  for axis,value in pairs(Input.axes) do
    if value~=0 and love.gamepadaxis then love.gamepadaxis(pad,axis,0) end
  end
  if previousTrigger and Input.pointer and love.mousereleased then
    love.mousereleased(Input.pointer.x,Input.pointer.y,1,false,1)
  end
  Input.buttons,Input.axes,previous={}, {}, {}
  Input.pointer,previousTrigger=nil,false
  if Input.panel then Input.panel.setPointer(nil) end
end

function Input.update(actions,views)
  actions=actions or {}
  local move=actions.move or {}
  local hands=actions.hands or {}
  local states={a=actions.a==true,b=actions.b==true,start=actions.start==true,back=actions.select==true}
  local axes={leftx=move.x or 0,lefty=-(move.y or 0),righty=-(actions.scrollY or 0)}
  local scroll=package.loaded["framevr.EditorScroll"]
  if scroll and scroll.controlsWheel() then axes.righty=0 end
  local hand=hands.right and hands.right.valid and hands.right
    or hands.left and hands.left.valid and hands.left
  local trigger=hand and (hand.trigger or 0)>=0.6 or false
  local any=trigger or math.abs(axes.leftx)>0.3 or math.abs(axes.lefty)>0.3 or math.abs(axes.righty)>0.3
  for _,held in pairs(states) do any=any or held end
  if neutralRequired then
    if any then return end
    neutralRequired=false
  end
  if actions.recenter and not recenterHeld then Input.runtime.recenter() end
  recenterHeld=actions.recenter==true
  -- Store polling state before firing edges, so engine reconciliation agrees.
  Input.buttons=states
  for _,key in ipairs({"back","start","b","a"}) do
    if states[key]~=previous[key] then
      if states[key] and love.gamepadpressed then love.gamepadpressed(pad,key)
      elseif not states[key] and love.gamepadreleased then love.gamepadreleased(pad,key) end
    end
  end
  for axis,value in pairs(axes) do
    if value~=(Input.axes[axis] or 0) and love.gamepadaxis then love.gamepadaxis(pad,axis,value) end
  end
  Input.axes,previous=axes,states
  local w,h=love.graphics.getDimensions()
  local hit=views and hand and Input.panel.hit(views,w,h,hand)
  local pointer=hit and hit.inside and hit or nil
  local previousPointer=Input.pointer
  Input.pointer=pointer
  Input.panel.setPointer((Input.kind=="launcher" or Input.kind=="skin_studio"
    or Input.kind=="editor" or Input.kind=="touch_editor") and hit or nil)
  if pointer then
    if love.mousemoved then
      love.mousemoved(pointer.x,pointer.y,previousPointer and pointer.x-previousPointer.x or 0,
        previousPointer and pointer.y-previousPointer.y or 0,false)
    end
    if trigger and not previousTrigger and love.mousepressed then
      Input.mouseDown=true
      Input.mouseOrigin={x=pointer.x,y=pointer.y}
      love.mousepressed(pointer.x,pointer.y,1,false,1)
    end
  end
  if not trigger and previousTrigger then
    Input.mouseDown,Input.mouseOrigin=false,nil
    local p=pointer or previousPointer
    if p and love.mousereleased then love.mousereleased(p.x,p.y,1,false,1) end
  end
  previousTrigger=trigger
end

function Input.suspend()
  Input.release(); neutralRequired=true
end

return Input
