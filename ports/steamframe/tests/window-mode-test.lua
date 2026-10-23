local engine=arg[1] or "../.."
package.path="game/?.lua;"..engine.."/?.lua;"..package.path
local vr=false
local writes={}
local nativeCalls=0
local failNative=false
love={system={getOS=function() return "Linux" end},window={
  getMode=function() return 1024,768,{fullscreen=false,display=1,minwidth=480,minheight=360} end,
  getDesktopDimensions=function() return 1920,1080 end,
  setMode=function() nativeCalls=nativeCalls+1; if failNative then error("live native window change") end; return true end,
  setFullscreen=function() nativeCalls=nativeCalls+1; if failNative then error("live native fullscreen change") end; return true end,
  updateMode=function() nativeCalls=nativeCalls+1; return false,"native failure preserved" end,
}}
package.loaded["src.core.SaveData"]={portableFs=function() return {
  read=function() return nil end,
  write=function(path,bytes) writes[#writes+1]={path,bytes}; return true end,
} end}
local Window=require("src.import.LauncherWindow")
local native=love.window.setMode
local Video=require("src.core.VideoMode")
failNative=false; nativeCalls=0; vr=false
assert(require("framevr.WindowMode").install({isBridgeActive=function() return vr end}))
local guarded=love.window.setMode
assert(Window.apply("windowed") and nativeCalls==1,"startup before XR uses actual native mode")
nativeCalls=0; vr=true
assert(Window.apply("fullscreen") and Window.mode()=="fullscreen")
assert(nativeCalls==0 and writes[#writes][2]:match("^fullscreen\n"),"original preference persisted without native reset")
assert(love.window.setMode==guarded,"persistent boundary remains installed")
assert(Window.apply("windowed") and Window.mode()=="windowed" and nativeCalls==0)
assert(writes[#writes][2]:match("^windowed\n"))
Window.activate(); assert(nativeCalls==0,"launcher reactivation remains XR safe")
failNative=true
Video.applyOptions({videoMode="windowed"})
Video.applyOptions({videoMode="borderless"})
assert(love.window.setMode(800,600,{fullscreen=true}))
assert(love.window.setFullscreen(true,"desktop"))
assert(love.window.updateMode(1600,1000,{}))
assert(nativeCalls==0,"game start, direct fullscreen/size, updated engine path protected")
assert(require("framevr.WindowMode").install({isBridgeActive=function() return vr end}))
assert(love.window.setMode==guarded,"repeat installation is idempotent")
failNative=false
vr=false
assert(Window.apply("fullscreen") and nativeCalls==1,"flat/startup still applies natively")
Video.apply("windowed"); assert(nativeCalls==2)
local result,detail=love.window.updateMode(900,700,{})
assert(result==false and detail=="native failure preserved","native multiple returns preserved")
-- Force a failure inside original apply/flush; wrapper must restore the setter.
vr=true
local fs=package.loaded["src.core.SaveData"]
local previous=fs.portableFs
fs.portableFs=function() error("synthetic preference failure") end
assert(not pcall(Window.apply,"windowed"))
assert(love.window.setMode==guarded,"preference errors cannot remove boundary")
fs.portableFs=previous
print("PASS current engine launcher/game/native mode APIs guarded while XR live; original preference writes, flat/startup/native returns and errors preserved")
