package.path="game/?.lua;game/?/init.lua;"..package.path
local active,fail=true,false
local entries={{name="Folder",path="/synthetic/empty",isDir=true},{name="Old row",isDir=false}}
local Browser={active=true,entries=entries}
local Kit={FileBrowser=Browser,blockClicks=true}
local calls=0
function Browser.setDirectory(path) calls=calls+1; Browser.currentDir=path; Browser.entries={} end
local directory=Browser.setDirectory
function Kit.press(i) return not Kit.blockClicks and i==1 end
local press=Kit.press
function Browser.open() end
function Browser.draw()
  Kit.blockClicks=true
  for i=1,#Browser.entries do
    local entry=Browser.entries[i]
    if Kit.press(i) and entry.isDir then Browser.setDirectory(entry.path) end
    assert(entry.name,"each old row remains valid throughout drawing")
    if fail then error("synthetic failure after queued directory click") end
  end
end
package.loaded["src.import.RomImporter"]={_beginImporterImport=function() end,
  _importerPickPending=function() end,_runImporter=function() end}
package.loaded["src.ui.kit.Kit"]=Kit
package.loaded["src.import.Importers"]={get=function() end}
assert(require("framevr.ImportPicker").install({isBridgeActive=function() return active end}))
Browser.draw()
assert(calls==1 and #Browser.entries==0 and Browser.currentDir=="/synthetic/empty")
assert(Browser.setDirectory==directory and Kit.press==press and Kit.blockClicks)
Browser.setDirectory("/synthetic/immediate")
assert(calls==2,"outside-draw navigation remains immediate")
Browser.entries=entries; fail=true
assert(not pcall(Browser.draw))
assert(calls==2,"failed draw discards queued navigation")
assert(Browser.setDirectory==directory and Kit.press==press and Kit.blockClicks,"error restores callbacks/shield")
Browser.entries=entries; fail=false; active=false
Browser.draw()
assert(calls==2,"flat mode retains original click shield/behavior")
print("PASS directory click defers until draw completes; original scan once; immediate outside draw; error discards/restores; flat behavior preserved")
