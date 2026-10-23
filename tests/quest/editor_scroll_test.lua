-- Run with LuaJIT from any working directory. Loads the immutable real Kit.
local root='./'
package.loaded.Theme={PAL={},clamp=function(v,a,b) return math.max(a,math.min(b,v)) end}
love={mouse={isDown=function() return false end}}
local Kit=dofile(root..'tools/save-editor/Kit.lua')
local Scroll=require('src.host.android.QuestEditorScroll')
local c=Scroll.attach(Kit)
assert(Scroll.attach(Kit)==c,'idempotent attach')
local owner='editor-a'
local function frame(p,wheel,held,draw,stick,dt)
  c:begin(p,stick or 0,dt or 0.05,held,owner)
  Kit.beginFrame(p.x,p.y,held,wheel or 0)
  local result=draw()
  Kit.endFrame()
  return result
end
local p={x=50,y=50}
local offset=30
local function rows() offset=Kit.scroll(0,0,200,100,offset,1000,10); return offset end
frame(p,0,false,rows)
for i=1,4 do frame(p,-0.1,false,rows) end
assert(offset==31,'fractional wheel accumulates rather than sign-only jumps')
frame(p,-10,false,rows)
assert(offset==61,'wheel magnitude retained')
local early=0
for i=1,4 do local before=offset; frame(p,0,false,rows,-1); early=early+offset-before end
for i=1,20 do frame(p,0,false,rows,-1) end
local late=0
for i=1,4 do local before=offset; frame(p,0,false,rows,-1); late=late+offset-before end
assert(late>early,'sustained stick accelerates')
local before=offset
frame({x=300,y=300},-5,false,rows,-1)
assert(offset==before,'outside wheel ignored')
frame(p,-5,false,function() Kit.blockClicks=true; rows(); Kit.blockClicks=false end)
assert(offset==before,'modal blocks scroll')
frame(p,-5,false,function() Kit.pushClip(100,0,100,100); rows(); Kit.popClip() end)
assert(offset==before,'clip blocks scroll')
-- Pixel track is invoked after content: prior-frame track shields earlier rows.
c:reset()
local px=0
local function pixels() px=Kit.scrollPixels(0,0,200,100,px,1000); return px end
frame(p,0,false,pixels)
local pressed
frame({x=190,y=80},0,true,function()
  pressed=Kit.press(0,0,200,100); pixels()
end)
assert(not pressed and px>500,'track click seeks and shields earlier content')
frame({x=190,y=500},0,true,pixels)
assert(px==900,'held drag clamps beyond track')
frame(p,0,false,pixels)
-- A hold that began outside cannot acquire a track after pointer crossing.
px=0
frame(p,0,true,pixels)
frame({x=190,y=80},0,true,pixels)
assert(px==0,'crossing track during hold cannot acquire')
owner='editor-b'
frame({x=190,y=80},0,true,pixels)
assert(px==0,'owner change during hold cannot acquire')
frame({x=190,y=80},0,false,pixels)
frame({x=190,y=80},0,true,pixels)
assert(px>500,'release rearms track')
frame({x=190,y=30},0,true,function() Kit.blockClicks=true; pixels(); Kit.blockClicks=false end)
local modalOffset=px
frame({x=190,y=80},0,true,pixels)
assert(px==modalOffset,'modal cancels capture until fresh press')
frame(p,0,false,pixels)
px=0
frame(p,-0.25,false,pixels)
assert(px==12,'pixel scroll preserves fractional magnitude')
-- First consumer owns the wheel, and grid row offsets retain step alignment.
frame(p,-2,false,function()
  local a=Kit.scroll(0,0,100,100,0,1000,20,4)
  local b=Kit.scrollPixels(0,0,200,100,0,1000)
  assert(a==8 and b==0,'nested first claim and grid alignment')
end)
-- Reset disables adaptations while another owner uses the shared Kit.
c:reset()
Kit.beginFrame(50,50,false,-10)
assert(Kit.scroll(0,0,200,100,0,1000,10)==3,'inactive baseline behavior restored')
Kit.endFrame()
c:detach()
Kit.beginFrame(50,50,false,-10)
assert(Kit.scroll(0,0,200,100,0,1000,10)==3,'detach restores original')
Kit.endFrame()
print('scroll_headless: PASS (actual baseline Kit; synthetic rows/pixels; no saves)')
