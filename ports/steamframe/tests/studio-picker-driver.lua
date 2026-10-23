return function(subject)
  local out=assert(os.getenv("FRAME_TEST_OUTPUT"))
  local Host=require("framevr.Host")
  local Input=Host.input
  local Kit=require("src.ui.kit.Kit")
  local Browser=Kit.FileBrowser
  local untilTime=love.timer.getTime()+1
  repeat coroutine.yield() until love.timer.getTime()>=untilTime
  assert(subject.onOpenSkinStudio,"real My Skins host entry")
  subject.onOpenSkinStudio("red")
  coroutine.yield(); coroutine.yield()
  local Studio=require("src.ui.SkinStudio")
  assert(Input.kind=="skin_studio" and Input.subject==Studio,"real scene active")
  local File=require("src.core.FilePicker")
  local Skin=require("src.core.TouchSkin")
  local open,read,install=File.open,File.read,Skin.installArchive
  local installed
  File.open=function() error("desktop picker must not execute") end
  File.read=function(path) return "synthetic archive boundary" end
  Skin.installArchive=function(name,data)
    installed={name,data}; return nil,"Synthetic validation rejection"
  end
  local function actions(a) Input.update(a,Host.runtime.frameViews()) end
  local function picker()
    Studio.importSkinFile()
    assert(Browser.active and Browser.mode=="all")
    Browser.entries={}
    for i=1,17 do Browser.entries[i]={name="Synthetic "..i..".cfg",path="/synthetic/"..i..".cfg",isDir=false} end
    Browser.selectedIdx,Browser.page=1,1
    actions({})
  end
  picker()
  actions({move={x=1,y=0}})
  assert(Browser.page==2 and Browser.selectedIdx==9,"Frame page navigation")
  actions({}); actions({move={x=0,y=-1}})
  assert(Browser.selectedIdx==10,"Frame row navigation")
  actions({}); actions({a=true})
  assert(not Browser.active and installed and installed[1]:match("10.cfg$"),"A reaches original skin validation")
  assert(Studio.statusErr and Studio.status:find("Synthetic validation rejection",1,true),"official error UI retained")
  actions({})
  installed=nil
  picker()
  local press=Kit.press
  local row
  Kit.press=function(x,y,w,h) if not row then row={x=x+w/2,y=y+h/2} end; return press(x,y,w,h) end
  _G.FRAME_TEST_BRIDGE_OBJECT.capture="my-skins-browser"
  coroutine.yield()
  Kit.press=press
  assert(row)
  local hit,set=Input.panel.hit,Input.panel.setPointer
  local pointerSeen=false
  Input.panel.hit=function() return {x=row.x,y=row.y,inside=true,
    point={x=0,y=1.6,z=-2},origin={x=0,y=1.4,z=-0.2}} end
  Input.panel.setPointer=function(p) if p then pointerSeen=true end; return set(p) end
  actions({hands={right={valid=true,trigger=0}}})
  actions({hands={right={valid=true,trigger=1}}})
  coroutine.yield()
  assert(not Browser.active and installed and installed[1]:match("1.cfg$"),"laser selection reaches original validator")
  assert(pointerSeen,"skin studio receives visible ray pointer")
  actions({hands={right={valid=true,trigger=0}}})
  Input.panel.hit,Input.panel.setPointer=hit,set
  installed=nil
  picker(); actions({select=true}); actions({})
  assert(not Browser.active and not installed,"Frame cancel never imports")
  picker(); love.keypressed("escape")
  assert(not Browser.active and not installed,"keyboard cancel retained")
  File.open,File.read,Skin.installArchive=open,read,install
  local f=assert(io.open(out.."/studio-tests.txt","wb"))
  f:write("PASS actual My Skins scene and original import workflow: inline browser, Frame stick/page/A, laser with visible pointer, original validation rejection UI, Frame/keyboard cancel. Real GPU/fake XR; synthetic archive boundary, no skin installed or physical Frame tested.\n")
  f:close()
end
