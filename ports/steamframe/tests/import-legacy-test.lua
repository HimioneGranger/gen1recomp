package.path="game/?.lua;"..package.path
local Browser={active=false}
Browser.open=function() Browser.active=true end
local steps=0
Browser.gamepadpressed=function() steps=steps+1 end
local Importer={_beginImporterImport=function() error("desktop dialog") end,
  _runImporter=function() end,gamepadaxis=function() end}
package.loaded["src.import.RomImporter"]=Importer
package.loaded["src.ui.kit.Kit"]={FileBrowser=Browser}
package.loaded["src.import.Importers"]={get=function() return {name="fixture"} end}
assert(require("framevr.ImportPicker").install({isBridgeActive=function() return true end}))
local subject=setmetatable({},{__index=Importer})
for _,field in ipairs({"pickPending","pickerPendingKind","_hostPick","_importerJob"}) do
  subject[field]=true;subject:_beginImporterImport("test")
  assert(not Browser.active,"legacy busy flag "..field);subject[field]=nil
end
subject:_beginImporterImport("test");assert(Browser.active)
subject:gamepadaxis(nil,"lefty",1);assert(steps==1)
Browser.active=false;Browser.open()
subject:gamepadaxis(nil,"lefty",1);assert(steps==2,"cancel/reopen resets edge")
print("PASS missing newer importer helper; legacy busy guards and reopen edge")
