return function()
  local out=assert(os.getenv("FRAME_TEST_OUTPUT"))
  local Host=require("framevr.Host")
  local Input,Scroll=Host.input,require("framevr.EditorScroll")
  local untilTime=love.timer.getTime()+1
  repeat coroutine.yield() until love.timer.getTime()>=untilTime
  local path=love.filesystem.getRequirePath()
  love.filesystem.setRequirePath("tools/save-editor/?.lua;tools/save-editor/panels/?.lua;"..path)
  local Kit=require("Kit") -- actual save-editor widgets, not launcher Kit
  love.filesystem.setRequirePath(path)
  assert(Scroll.attach(Kit))
  local kind,subject=Input.kind,Input.subject
  Input.setSubject("editor",{})
  local hit=Input.panel.hit
  local mx,my=250,150
  Input.panel.hit=function() return {x=mx,y=my,inside=true,
    point={x=0,y=1.6,z=-2},origin={x=0,y=1.4,z=-0.2}} end
  local press,release,moved,wheel,axis=love.mousepressed,love.mousereleased,love.mousemoved,love.wheelmoved,love.gamepadaxis
  local queued=0
  love.mousepressed=function() assert(love.mouse.isDown(1),"held state precedes press callback") end
  love.mousereleased=function() assert(not Input.mouseDown,"held state cleared before release") end
  love.mousemoved=function() end
  love.wheelmoved=function(_,y) queued=queued+y end
  love.gamepadaxis=function(_,name,value) assert(name~="righty" or value==0,"no duplicate slow editor stick wheel") end
  local g=love.graphics
  local canvas=g.newCanvas(800,600)
  local state={offset=0}
  local function actions(value,trigger)
    Input.update({scrollY=value or 0,hands={right={valid=true,trigger=trigger or 0}}},Host.runtime.frameViews())
  end
  local function draw()
    g.push("all"); g.setCanvas(canvas); g.origin(); g.clear(0.06,0.07,0.08,1)
    Kit.layout(800,600)
    Kit.beginFrame(mx,my,false,queued); queued=0
    local n,shift=Kit.list(state,"offset",100,100,300,300,386,28)
    for i=1,n do
      local y=100+(i-1)*28-shift
      g.setColor(0.1,0.15,0.2,1); g.rectangle("fill",100,y,300,26)
      g.setColor(1,1,1,1); g.print("Synthetic species row "..(state.offset+i),110,y+4)
    end
    Kit.popClip(); Kit.listScrollbar(state,"offset",100,100,300,300)
    Kit.endFrame(); g.pop()
    return state._listState.offset.pixels
  end
  actions(); draw()
  for _=1,120 do actions(-1); Scroll.update(-1,1/60); draw() end
  local down=state._listState.offset.pixels
  assert(down>800,"two-second stick hold smoothly traverses many original list rows")
  for _=1,30 do actions(1); Scroll.update(1,1/60); draw() end
  assert(state._listState.offset.pixels<down,"reverse stick moves up")
  actions(); Scroll.update(0,1/60)
  mx,my=405,385 -- original thin scrollbar is outside the list body's right edge
  actions(0,1); draw()
  assert(Input.mouseDown and state._listState.offset.pixels>9000,"track click jumps near list end")
  my=105; actions(0,1); local top=draw()
  assert(top<400,"held laser drag moves original list near top")
  actions(0,0); draw()
  assert(not Input.mouseDown and not love.mouse.isDown(1),"laser release clears polled held state")
  local at=state._listState.offset.pixels
  my=380; actions(); draw()
  assert(state._listState.offset.pixels==at,"moving after release does not continue dragging")
  local raw=Input.originalMouseDown
  Input.originalMouseDown=function(button) return button==2 end
  assert(love.mouse.isDown(2) and not love.mouse.isDown(1),"physical mouse buttons preserved")
  Input.originalMouseDown=raw
  local image=canvas:newImageData(); local png=image:encode("png")
  local f=assert(io.open(out.."/editor-list.png","wb")); f:write(png:getString()); f:close()
  png:release(); image:release(); canvas:release()
  Input.panel.hit=hit
  love.mousepressed,love.mousereleased,love.mousemoved,love.wheelmoved,love.gamepadaxis=press,release,moved,wheel,axis
  Input.setSubject(kind,subject)
  local f=assert(io.open(out.."/scroll-tests.txt","wb"))
  f:write("PASS actual save-editor Kit.list/scrollPixels/scrollbar and production Frame input: smooth accelerated stick/reverse, no old wheel axis, 386 synthetic rows, track click/end-to-top laser drag, release, physical mouse preserved. Real GPU/fake XR, no save file or Frame test.\n")
  f:close()
end
