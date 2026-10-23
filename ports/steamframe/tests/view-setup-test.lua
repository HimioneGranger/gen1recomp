package.path="game/?.lua;"..package.path
local enabled,bridge=true,false
local w,h=1024,768
local flags={fullscreen=false,resizable=true}
local calls=0
local fail=false
love={window={getMode=function() return w,h,flags end,
  setMode=function(x,y,f)
    assert(not bridge,"resize must precede native XR")
    calls=calls+1; assert(f==flags)
    if fail then return false end
    w,h=x,y; return true
  end},graphics={getDimensions=function() return w,h end}}
local Runtime={isEnabled=function() return enabled end,isBridgeActive=function() return bridge end}
local View=require("framevr.ViewSetup")
assert(View.prepare(Runtime) and w==1600 and h==1000 and calls==1)
assert(View.prepare(Runtime) and calls==1,"does not repeat or shrink")
bridge=true; assert(not View.prepare(Runtime) and calls==1)
bridge=false; enabled=false; w,h=800,600
assert(not View.prepare(Runtime) and calls==1,"flat display untouched")
enabled=true; flags.fullscreen=true
assert(not View.prepare(Runtime) and calls==1,"user fullscreen desktop retained")
flags.fullscreen=false; fail=true
assert(not View.prepare(Runtime) and w==800 and h==600,"failed request retains usable window")
local Panel=require("framevr.MonoPanel")
local function eye(x) return {position={x=x,y=1.6,z=0},orientation={x=0,y=0,z=0,w=1},
  width=600,height=600,fov={left=-0.8,right=0.8,up=0.8,down=-0.8}} end
local views={eye(-0.032),eye(0.032)}
local a,width,height=Panel.geometry(views,1600,1000)
assert(math.abs(a.z+1.4)<1e-6 and width==1.9 and math.abs(height-1.1875)<1e-6)
local hit=Panel.hit(views,1600,1000,{valid=true,position={x=0,y=1.6,z=0},orientation={x=0,y=0,z=0,w=1}})
assert(hit.inside and math.abs(hit.x-800)<1e-6 and math.abs(hit.y-500)<1e-6,"closer screen center ray aligns")
local v=Panel.vertices(views[1],a,width,height)
assert(v[2][1]-v[1][1]>0.6,"closer screen covers more of eye FOV")
bridge=true
Runtime.frameViews=function() return views end
View.report(Runtime,Panel); View.report(Runtime,Panel)
print("PASS startup larger window before XR; flat/fullscreen/error handling; 1.4m screen and aligned pointer geometry")
