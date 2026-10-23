return function(subject)
  local out=assert(os.getenv("FRAME_TEST_OUTPUT"))
  local bridge=assert(_G.FRAME_TEST_BRIDGE_OBJECT)
  local Host=require("framevr.Host")
  local Input=Host.input
  local Kit=require("src.ui.kit.Kit")
  local Browser=Kit.FileBrowser
  local untilTime=love.timer.getTime()+1
  repeat coroutine.yield() until love.timer.getTime()>=untilTime
  assert(Host.runtime.isBridgeActive() and bridge.submits>0)
  local original=subject._runImporter
  local selected
  subject._runImporter=function(self,id,path) selected={id,path} end
  local function open()
    subject:_beginImporterImport("gen5_bw")
    assert(Browser.active)
    Browser.entries={{name="Synthetic first.nds",path="/synthetic/first.nds",isDir=false},
      {name="Synthetic second.nds",path="/synthetic/second.nds",isDir=false}}
    Browser.selectedIdx,Browser.page=1,1
  end
  local function actions(a) Input.update(a,Host.runtime.frameViews()) end
  open()
  actions({})
  actions({move={x=0,y=-1}})
  assert(Browser.selectedIdx==2,"Frame stick down moves original browser selection")
  actions({move={x=0,y=-1}})
  assert(Browser.selectedIdx==2,"held stick does not double-step")
  actions({}); actions({move={x=0,y=1}})
  assert(Browser.selectedIdx==1,"Frame stick up moves selection")
  actions({}); actions({move={x=0,y=-1}}); actions({})
  actions({a=true})
  assert(not Browser.active and selected and selected[2]=="/synthetic/second.nds","Frame A selects highlighted file")
  actions({})
  selected=nil
  open()
  local press=Kit.press
  local draw=Browser.draw
  local rows={}
  local recording=false
  Browser.draw=function(...) recording=true; local r=draw(...); recording=false; return r end
  Kit.press=function(x,y,w,h)
    if recording then rows[#rows+1]={x=x+w/2,y=y+h/2} end
    return press(x,y,w,h)
  end
  bridge.capture="controller-browser"
  coroutine.yield()
  Kit.press=press
  Browser.draw=draw
  assert(#rows>=2,"record original browser row hitboxes")
  local hit=Input.panel.hit
  Input.panel.hit=function() return {x=rows[2].x,y=rows[2].y,inside=true,
    point={x=0,y=1.6,z=-2},origin={x=0,y=1.4,z=-0.2}} end
  actions({hands={right={valid=true,trigger=0}}})
  actions({hands={right={valid=true,trigger=1}}})
  coroutine.yield()
  assert(not Browser.active and selected and selected[2]=="/synthetic/second.nds","Frame ray trigger selects original browser row")
  actions({hands={right={valid=true,trigger=0}}})
  Input.panel.hit=hit
  selected=nil
  open(); actions({})
  -- Real users wait for the modal's opening transition before pressing Cancel.
  local deadline=love.timer.getTime()+3
  repeat coroutine.yield() until not require("src.ui.kit.Transition").active() or love.timer.getTime()>deadline
  local callback=love.gamepadpressed
  local received={}
  love.gamepadpressed=function(pad,button)
    received[#received+1]=button
    return callback(pad,button)
  end
  actions({select=true})
  love.gamepadpressed=callback
  local fdiag=assert(io.open(out.."/cancel-diagnostic.txt","wb"))
  fdiag:write("events="..table.concat(received,",").." active="..tostring(Browser.active)..
    " transition="..tostring(require("src.ui.kit.Transition").active()).." hostPick="..tostring(subject._hostPick).."\n")
  fdiag:close()
  assert(not Browser.active,"Frame select closes browser; held="..tostring(Input.buttons.back))
  assert(not selected,"Frame select cancels without import")
  actions({})
  subject._runImporter=original
  local f=assert(io.open(out.."/controls-tests.txt","wb"))
  f:write("PASS actual official browser via Frame Input.update: stick down/up/neutral/hold, A selected file, ray trigger selected file, Select cancelled. Original row layout and callbacks; GPU capture. Synthetic files/callback, fake XR bridge: physical Frame/ROM import pending.\n")
  f:close()
end
