package.path="game/?.lua;game/?/init.lua;"..package.path
local Scroll=require("framevr.EditorScroll")
local vr=true
local input={kind="editor",pointer={x=50,y=50}}
local wheel=0
love={wheelmoved=function(_,y) wheel=wheel+y end}
local Kit={scale=1,mouseClicked=true,beginFrame=function() end,
  scrollPixels=function(_,_,_,_,at) return at end}
Scroll.install({isBridgeActive=function() return vr end},input)
assert(Scroll.attach(Kit))
Kit.beginFrame(); Kit.scrollPixels(0,0,100,200,0,2000)
assert(Scroll.controlsWheel())
Scroll.update(-1,0.05); local fine=wheel
for _=1,20 do Scroll.update(-1,0.05) end
assert(fine<0 and wheel< -12,"held stick accelerates with fractional smooth notches")
Scroll.update(0,0.01); wheel=0; Scroll.update(-1,0.05)
assert(wheel==fine,"neutral resets acceleration")
input.pointer={x=300,y=300}; wheel=0; Scroll.update(-1,0.05)
assert(wheel==0 and not Scroll.controlsWheel(),"non-list/map viewport not accelerated")
input.pointer={x=105,y=190}; input.mouseOrigin={x=105,y=10}; input.mouseDown=true
local at=Kit.scrollPixels(0,0,100,200,0,2000)
assert(at>1700 and not Kit.mouseClicked,"right-side track drag reaches near end and consumes row click")
input.pointer.y=0
assert(Kit.scrollPixels(0,0,100,200,at,2000)==0,"drag clamps top")
input.mouseDown=false; input.mouseOrigin=nil
assert(Kit.scrollPixels(0,0,100,200,25,2000)==25,"release ends drag")
Kit.blockClicks=true; input.mouseDown=true; input.mouseOrigin={x=105,y=0}; input.pointer.y=190
assert(Kit.scrollPixels(0,0,100,200,25,2000)==25,"modal shield preserved")
Kit.blockClicks=false; vr=false
assert(Kit.scrollPixels(0,0,100,200,25,2000)==25,"flat original behavior")
print("PASS editor smooth acceleration/reset, list-only targeting, laser scrollbar hit/drag/clamp/release, click shield, flat routing")
