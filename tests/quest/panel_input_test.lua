local root='./'
package.path='./?.lua;./?/init.lua;'..package.path
local events,state,hand=0,4,2
local rays={{.25,.75,1},{.75,.5,1}}
local stick,rightStick=0,0
local function eq(a,b,msg) assert(a==b,(msg or '')..' expected '..tostring(b)..' got '..tostring(a)) end
love={mouse={getPosition=function() return 3,7 end,isDown=function() return true end},
 graphics={getDimensions=function() return 1000,800 end},
 keypressed=function() error('unexpected key fallback') end,keyreleased=function() end}
package.loaded.Theme={PAL={},clamp=function(v,a,b) return math.max(a,math.min(b,v)) end}
local Kit=dofile(root..'tools/save-editor/Kit.lua');package.loaded.Kit=Kit
local padActive=true
package.loaded['src.ui.PadCursor']={gamepadaxis=function() end,yieldToPointer=function() padActive=false end}
local native={
 questxr_poll_pointer_axes=function(x,y) x[0],y[0]=0,stick end,
 questxr_poll_pointer_positions=function(lx,ly,la,rx,ry,ra)
  lx[0],ly[0],la[0]=unpack(rays[1]);rx[0],ry[0],ra[0]=unpack(rays[2]) end,
 questxr_poll_panel_scroll_y=function() return rightStick end,
 questxr_poll_input=function() local e=events;events=0;return e end,
 questxr_poll_select_hand=function() return hand end,
 questxr_poll_panel_input_state=function() return state end,
 questxr_set_panel_pointers=function() end,questxr_request_panel_capture=function() end,questxr_log=function() end,
}
local backend=require('src.host.android.QuestOpenXRDisplay')._newForTests(native)
local log={}
local owner={mousepressed=function(x,y) log[#log+1]={'down',x,y,love.mouse.isDown(1)} end,
 mousereleased=function(x,y) log[#log+1]={'up',x,y,love.mouse.isDown(1)} end,
 mousemoved=function() end,keypressed=function(k) log[#log+1]={k} end}
local function tick(e,s,h) events=e or 0;state=s or 4;hand=h or 2;backend:update(.05) end
local function drawRows(offset)
 local x,y=love.mouse.getPosition();Kit.beginFrame(x,y,false,0)
 local n=Kit.scroll(0,0,1000,800,offset or 0,1000,10)
 Kit.endFrame();return n
end
for _,kind in ipairs({'editor','touch_editor','skin_studio'}) do
 log={};backend:endFrame(kind,owner)
 tick(16,6) -- Scene entered with trigger already down.
 eq(#log,0,'entry hold ignored')
 tick(0,4);tick(16,6,2)
 eq(log[1][1],'down');eq(log[1][2],750);eq(log[1][3],400);eq(log[1][4],true)
 rays[1][1]=.1 -- Moving other hand must not steal a drag.
 tick(0,6);eq(backend.activePointerHand,2)
 tick(0,4);eq(log[2][1],'up');eq(log[2][4],false,'release visible before callback')
 tick(16,5,1);eq(log[3][2],100,'left trigger selects left ray')
 rays[1][3]=0;tick(0,5);eq(log[4][1],'up','tracking loss releases')
 rays[1][3]=1;tick(16,5,1);eq(#log,4,'tracking return cannot reacquire held trigger')
 tick(0,4);tick(16,5,1);eq(#log,5)
 tick(0,0);eq(log[6][1],'up','focus loss releases')
 tick(0,4);tick(32,4);eq(log[7][1],'escape')
 eq(padActive,false,'ray suppresses second pad cursor')
 backend:endFrame('game',{})
 local x,y=love.mouse.getPosition();eq(x,3);eq(y,7)
 eq(love.mouse.isDown(1),true,'game real mouse unchanged')
end
-- Actual widget integration: hold accelerates and scrollbar jumps/drags.
backend:endFrame('editor',owner);rays[2]={.5,.5,1};tick(0,4);drawRows()
local n=0;stick=-1
for _=1,25 do tick(0,4);n=drawRows(n) end
assert(n>40,'sustained stick faster than old ~6 rows/sec')
-- Either thumbstick scrolls; right takes precedence when both are deflected.
local prior=n;stick=1;rightStick=-1
for _=1,25 do tick(0,4);n=drawRows(n) end
assert(n>prior+40,'right stick overrides opposing left stick')
rightStick=0
stick=0;rays[2]={.985,.2,1};tick(0,4);drawRows(n)
tick(16,6,2);n=drawRows(n);assert(n>600,'first trigger frame track jump')
rays[2][2]=.8;tick(0,6);local nextN=drawRows(n);assert(nextN<n,'held thumb drag')
backend:endFrame('launcher',{})
local before=#log;eq(love.mouse.getPosition(),3)
eq(log[before][1],'up','owner change releases old editor')
-- Optional symbol lookup must remain protected for an older native library.
native.questxr_poll_panel_input_state=nil
setmetatable(native,{__index=function(_,key) if key=='questxr_poll_panel_input_state' then error('undefined symbol') end end})
backend:endFrame('skin_studio',owner);tick(0,4)
local start=#log;tick(16,6);eq(#log,start+2,'legacy tap presses and releases once')
backend:endFrame('game',{})
-- Detect is inert on stock desktop.
love.system={getOS=function() return 'Windows' end}
assert(require('src.host.android.QuestOpenXRDisplay').detect()==nil)
print('panel_input: PASS (real adapter and editor Kit, mocked native; no saves/device)')
