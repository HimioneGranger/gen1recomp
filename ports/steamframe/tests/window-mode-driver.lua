return function()
  local out=assert(os.getenv("FRAME_TEST_OUTPUT"))
  local Host=require("framevr.Host")
  local untilTime=love.timer.getTime()+1
  repeat coroutine.yield() until love.timer.getTime()>=untilTime
  local Window=require("src.import.LauncherWindow")
  local Save=require("src.core.SaveData")
  local portable=Save.portableFs
  local dimensions={love.graphics.getDimensions()}
  local fullscreen=love.window.getFullscreen()
  local writes={}
  local fs={read=function() return nil end,write=function(path,data) writes[#writes+1]=data; return true end}
  Save.portableFs=function() return fs end
  assert(Window.apply("fullscreen") and Window.mode()=="fullscreen")
  assert(writes[#writes]:match("^fullscreen\n"),"original fullscreen preference written")
  assert(Window.apply("windowed") and Window.mode()=="windowed")
  assert(writes[#writes]:match("^windowed\n"),"original windowed preference written")
  Window.activate()
  -- Actual per-game startup path missed by r12; even windowed calls setFullscreen.
  local Video=require("src.core.VideoMode")
  for _=1,3 do
    Video.applyOptions({videoMode="borderless"})
    Video.applyOptions({videoMode="windowed"})
    assert(love.window.setFullscreen(true,"desktop"))
    assert(love.window.setMode(800,600,{fullscreen=true,resizable=true}))
    if love.window.updateMode then assert(love.window.updateMode(900,700,{})) end
    coroutine.yield()
  end
  Save.portableFs=portable
  assert(love.graphics.getWidth()==dimensions[1] and love.graphics.getHeight()==dimensions[2])
  assert(love.window.getFullscreen()==fullscreen,"actual SDL mirror unchanged")
  local submits=Host.submits
  _G.FRAME_TEST_BRIDGE_OBJECT.capture="video-mode-stable"
  coroutine.yield(); coroutine.yield()
  assert(Host.runtime.isBridgeActive() and Host.submits>submits,"XR rendering continues after mode changes")
  local f=assert(io.open(out.."/window-tests.txt","wb"))
  f:write("PASS actual official launcher mode apply/activate persists both preferences through synthetic FS; original game VideoMode startup/borderless/windowed plus direct setMode/setFullscreen/updateMode requests preserve real SDL size/fullscreen; per-eye GPU submissions continue. Fake native XR only; physical crash/dashboard acceptance pending.\n")
  f:close()
end
