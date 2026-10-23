package.path="game/?.lua;game/?/init.lua;"..package.path
local active=true
local axes,mouse=0,0
local Browser={active=true}
local Kit={FileBrowser=Browser,blockClicks=true}
local Importer={_beginImporterImport=function() end,_importerPickPending=function() end,_runImporter=function() end}
function Importer:gamepadaxis() axes=axes+1 end
function Importer:mousepressed() mouse=mouse+1 end
local steps,clicks=0,0
function Browser.gamepadpressed() steps=steps+1 end
function Browser.open() end
function Kit.press() return not Kit.blockClicks end
local originalPress=Kit.press
local fail=false
function Browser.draw()
  Kit.blockClicks=true
  assert(Kit.press()==active,"only VR modal rows bypass click shield")
  if fail then error("synthetic draw failure") end
end
package.loaded["src.import.RomImporter"]=Importer
package.loaded["src.ui.kit.Kit"]=Kit
package.loaded["src.import.Importers"]={get=function() end}
package.loaded["src.import.LauncherView"]={clickAt=function() clicks=clicks+1 end}
assert(require("framevr.ImportPicker").install({isBridgeActive=function() return active end}))
local subject=setmetatable({},{__index=Importer})
Browser.draw()
assert(Kit.press==originalPress and Kit.blockClicks,"modal restores press/shield")
fail=true
assert(not pcall(Browser.draw))
assert(Kit.press==originalPress and Kit.blockClicks,"error restores press/shield")
fail=false
subject:gamepadaxis({},"lefty",1)
subject:gamepadaxis({},"lefty",1)
assert(steps==1 and axes==0,"stick edges consumed without duplicate")
subject:gamepadaxis({},"lefty",0); subject:gamepadaxis({},"lefty",-1)
assert(steps==2,"neutral permits next direction")
subject:mousepressed(1,2,1,false)
assert(clicks==1 and mouse==0,"VR browser click uses official click queue")
Browser.active=false
subject:gamepadaxis({},"lefty",1); subject:mousepressed(1,2,1,false)
assert(axes==1 and mouse==1,"outside browser original callbacks preserved")
Browser.active=true; active=false
subject:gamepadaxis({},"lefty",1); subject:mousepressed(1,2,1,false)
assert(axes==2 and mouse==2,"flat mode original callbacks preserved")
Browser.draw()
assert(Kit.press==originalPress,"flat browser unchanged")
print("PASS VR row click shield/restoration/error; stick edges/neutral; official click queue; outside-modal and flat routing")
