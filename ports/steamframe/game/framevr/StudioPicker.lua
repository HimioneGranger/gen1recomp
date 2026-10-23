-- Adapt the separate My Skins screen without replacing its import/validation.
local Adapter={}
function Adapter.install(runtime)
  local ok,Studio=pcall(require,"src.ui.SkinStudio")
  local fileOK,FilePicker=pcall(require,"src.core.FilePicker")
  local kitOK,Kit=pcall(require,"src.ui.kit.Kit")
  if not (ok and fileOK and kitOK and type(Studio.importSkinFile)=="function"
      and type(Studio.draw)=="function" and type(FilePicker.open)=="function"
      and Kit.FileBrowser and type(Kit.FileBrowser.open)=="function") then
    print("[frame-studio] My Skins interface unavailable; keeping official picker")
    return false
  end
  for _,name in ipairs({"safeFrame","mousepressed","mousereleased","mousemoved",
      "keypressed","gamepadpressed","gamepadreleased","gamepadaxis"}) do
    if type(Studio[name])~="function" then
      print("[frame-studio] My Skins input interface unavailable; keeping official picker")
      return false
    end
  end
  local Browser=Kit.FileBrowser
  local picking,click,mouseRelease=false,nil,false
  local axes,releases={},{}
  local original=Studio.importSkinFile
  local function modal() return picking and Browser.active and runtime.isBridgeActive() end
  local function finish() picking=false; click=nil; axes={} end
  Studio.importSkinFile=function(...)
    if not runtime.isBridgeActive() then return original(...) end
    if picking or Browser.active then return false end
    picking=true
    mouseRelease=Studio.pointerDown==true or Studio.libraryPress~=nil
    Studio.clicked,Studio.pointerDown,Studio.libraryPress=false,false,nil
    click=nil; axes={}
    Browser.open({title="Select skin (.zip / .deltaskin / .cfg)",mode="all",
      onCancel=finish,
      onSelect=function(path)
        finish()
        -- Replay just the file selection. The official read/install/error and
        -- editor-opening code executes unchanged; desktop dialogs never run.
        local open,available=FilePicker.open,FilePicker.available
        FilePicker.open=function() return path end
        FilePicker.available=function() return true end
        local success,result=pcall(original)
        FilePicker.open,FilePicker.available=open,available
        if not success then error(result,0) end
        return result
      end})
    return true
  end
  local draw=Studio.draw
  Studio.draw=function(...)
    if not modal() then return draw(...) end
    local w,h=Studio.safeFrame()
    Kit.layout(w,h)
    local x,y=love.mouse.getPosition()
    if click then x,y=click.x,click.y end
    Kit.beginFrame(x,y,click~=nil,0); click=nil
    Browser.draw({W=w,H=h,s=Kit.scale})
    Kit.endFrame()
  end
  local update=Studio.update
  if update then Studio.update=function(...)
    if modal() then return end
    local input=package.loaded["framevr.Input"]
    if not (runtime.isBridgeActive() and input and type(input.originalPosition)=="function") then
      return update(...)
    end
    -- PadCursor's motion detector must see the real mouse, not tiny movements
    -- of the projected laser. Original mouse presses still yield to the laser.
    local position=love.mouse.getPosition
    love.mouse.getPosition=input.originalPosition
    local success,result=pcall(update,...)
    love.mouse.getPosition=position
    if not success then error(result,0) end
    return result
  end end
  local mouse=Studio.mousepressed
  Studio.mousepressed=function(x,y,button,...)
    if modal() then
      if button==1 then click={x=x,y=y}; mouseRelease=true end
      return
    end
    return mouse(x,y,button,...)
  end
  local release=Studio.mousereleased
  Studio.mousereleased=function(x,y,button,...)
    if modal() or button==1 and mouseRelease then mouseRelease=false; return end
    return release(x,y,button,...)
  end
  local moved=Studio.mousemoved
  Studio.mousemoved=function(...) if not modal() then return moved(...) end end
  local key=Studio.keypressed
  Studio.keypressed=function(k,...) if modal() then return Browser.keypressed(k) end; return key(k,...) end
  local pad=Studio.gamepadpressed
  Studio.gamepadpressed=function(joystick,button,...)
    if modal() then
      releases[button]=true
      if button=="back" then button="select" end
      return Browser.gamepadpressed(button)
    end
    return pad(joystick,button,...)
  end
  local padRelease=Studio.gamepadreleased
  Studio.gamepadreleased=function(joystick,button,...)
    if releases[button] then releases[button]=nil; return end
    if not modal() then return padRelease(joystick,button,...) end
  end
  local axis=Studio.gamepadaxis
  Studio.gamepadaxis=function(joystick,name,value,...)
    if modal() then
      if name=="leftx" or name=="lefty" then
        local d=value>0.55 and 1 or value< -0.55 and -1 or 0
        local old=axes[name] or 0; axes[name]=d
        if d~=0 and d~=old then Browser.gamepadpressed(name=="lefty"
          and (d>0 and "dpdown" or "dpup") or (d>0 and "dpright" or "dpleft")) end
      end
      return
    end
    return axis(joystick,name,value,...)
  end
  print("[frame-studio] r9 My Skins browser and stable pad cursor installed")
  return true
end
return Adapter
