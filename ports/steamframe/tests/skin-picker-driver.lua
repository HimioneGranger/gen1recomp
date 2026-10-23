return function(subject)
  local out=assert(os.getenv("FRAME_TEST_OUTPUT"))
  local Host=require("framevr.Host")
  local Kit=require("src.ui.kit.Kit")
  local Browser=Kit.FileBrowser
  local untilTime=love.timer.getTime()+1
  repeat coroutine.yield() until love.timer.getTime()>=untilTime
  local original=subject._installSkinZip
  local selected
  subject._installSkinZip=function(self,path) selected=path end
  subject.tab="skins"
  subject:chooseSkin()
  assert(Browser.active and Browser.mode=="mod" and Browser.title=="Select skin .zip")
  Browser.entries={{name="Synthetic skin.zip",path="/synthetic/skin.zip",isDir=false}}
  Browser.selectedIdx,Browser.page=1,1
  local press,draw=Kit.press,Browser.draw
  local row,recording
  Browser.draw=function(...) recording=true; local r=draw(...); recording=false; return r end
  Kit.press=function(x,y,w,h)
    if recording and not row then row={x=x+w/2,y=y+h/2} end
    return press(x,y,w,h)
  end
  Host.input.update({},Host.runtime.frameViews())
  _G.FRAME_TEST_BRIDGE_OBJECT.capture="skin-browser"
  coroutine.yield()
  Kit.press,Browser.draw=press,draw
  assert(row)
  local hit=Host.input.panel.hit
  Host.input.panel.hit=function() return {x=row.x,y=row.y,inside=true,
    point={x=0,y=1.6,z=-2},origin={x=0,y=1.4,z=-0.2}} end
  Host.input.update({hands={right={valid=true,trigger=0}}},Host.runtime.frameViews())
  Host.input.update({hands={right={valid=true,trigger=1}}},Host.runtime.frameViews())
  coroutine.yield()
  assert(not Browser.active and selected=="/synthetic/skin.zip","laser skin selection forwarded")
  Host.input.update({hands={right={valid=true,trigger=0}}},Host.runtime.frameViews())
  Host.input.panel.hit=hit
  selected=nil
  subject:chooseSkin()
  assert(Browser.active)
  Browser.close()
  assert(not selected and not Browser.active,"cancel without installing")
  subject._installSkinZip=original
  local f=assert(io.open(out.."/skin-tests.txt","wb"))
  f:write("PASS actual official launcher skin chooser opens inline ZIP browser, real GPU/fake XR laser selects synthetic skin path to installer callback, cancel clean. No real skin installed or physical Frame tested.\n")
  f:close()
end
