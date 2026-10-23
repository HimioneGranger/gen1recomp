-- Keep optional cartridge selection inside the original launcher's VR surface.
local Picker={}
local installed=setmetatable({}, {__mode="k"})
function Picker.install(runtime)
  local ok,Importer=pcall(require,"src.import.RomImporter")
  local kitOK,Kit=pcall(require,"src.ui.kit.Kit")
  local descOK,Importers=pcall(require,"src.import.Importers")
  if not (ok and kitOK and Kit.FileBrowser and type(Kit.FileBrowser.open)=="function") then
    print("[frame-import] Browser interface unavailable; keeping official picker")
    return false
  end
  if installed[Importer] then return true end
  installed[Importer]=true
  local Browser=Kit.FileBrowser
  -- Older payloads expose pending fields rather than the newer helper.
  local function pickPending(self)
    return (type(self._importerPickPending)=="function" and self:_importerPickPending())
      or self.pickPending or self.pickerPendingKind or self._hostPick
      or self._importerJob or self.workState=="working" or Browser.active
  end
  -- Reset axis edges for every browser session, including the original ROM picker.
  local open=Browser.open
  local generation=0
  Browser.open=function(...)
    generation=generation+1
    return open(...)
  end
  if descOK and type(Importers.get)=="function"
      and type(Importer._beginImporterImport)=="function" and type(Importer._runImporter)=="function" then
  local original=Importer._beginImporterImport
  Importer._beginImporterImport=function(self,importerId,...)
    if not runtime.isBridgeActive() then return original(self,importerId,...) end
    if pickPending(self) then return end
    local desc=Importers.get(importerId)
    if not desc or desc.status=="planned" then return end
    self._importerNotice=nil
    self._padCursorActive=false
    Kit.FileBrowser.open({
      title="Select "..desc.name, mode="all",
      onSelect=function(path) self:_runImporter(importerId,path) end,
    })
  end
  end
  if type(Importer.chooseSkin)=="function" and type(Importer._installSkinZip)=="function" then
    local skin=Importer.chooseSkin
    Importer.chooseSkin=function(self,...)
      if not runtime.isBridgeActive() then return skin(self,...) end
      if pickPending(self) then return end
      if self._inboxImport and self:_inboxImport() then return skin(self,...) end
      self._padCursorActive=false
      self._skinNotice=nil
      Browser.open({title="Select skin .zip",mode="mod",
        onSelect=function(path) self:_installSkinZip(path) end})
    end
  end
  -- The original browser raises blockClicks for its modal, then uses Kit.press
  -- for its own rows. Permit only those row tests while drawing this modal.
  if type(Browser.draw)=="function" and type(Kit.press)=="function" then
    local draw=Browser.draw
    Browser.draw=function(...)
      if not runtime.isBridgeActive() or not Browser.active then return draw(...) end
      local press,blocked=Kit.press,Kit.blockClicks
      -- A folder click inside draw must not replace entries under its row loop.
      -- Keep the original scan/navigation; perform it after that loop completes.
      local directory,pendingDirectory=Browser.setDirectory,nil
      if type(directory)=="function" then
        Browser.setDirectory=function(path) pendingDirectory=path end
      end
      Kit.press=function(...)
        local saved=Kit.blockClicks
        Kit.blockClicks=false
        local ok,result=pcall(press,...)
        Kit.blockClicks=saved
        if not ok then error(result,0) end
        return result
      end
      local ok,result=pcall(draw,...)
      Kit.press,Kit.blockClicks=press,blocked
      Browser.setDirectory=directory
      if not ok then error(result,0) end
      if pendingDirectory and Browser.active then directory(pendingDirectory) end
      return result
    end
  end
  -- The browser consumes d-pad edges, whereas OpenXR supplies stick axes.
  if type(Importer.gamepadaxis)=="function" and type(Browser.gamepadpressed)=="function" then
    local axis=Importer.gamepadaxis
    Importer.gamepadaxis=function(self,pad,name,value,...)
      if runtime.isBridgeActive() and Browser.active and (name=="leftx" or name=="lefty") then
        if self._frameBrowserGeneration~=generation then
          self._frameBrowserAxes=nil
          self._frameBrowserGeneration=generation
        end
        self._frameBrowserAxes=self._frameBrowserAxes or {}
        local direction=value>0.55 and 1 or value< -0.55 and -1 or 0
        local prior=self._frameBrowserAxes[name] or 0
        self._frameBrowserAxes[name]=direction
        if direction~=0 and direction~=prior then
          Browser.gamepadpressed(name=="lefty" and (direction>0 and "dpdown" or "dpup")
            or (direction>0 and "dpright" or "dpleft"))
        end
        return
      end
      self._frameBrowserAxes=nil
      return axis(self,pad,name,value,...)
    end
  end
  if type(Importer.mousepressed)=="function" then
    local mouse=Importer.mousepressed
    Importer.mousepressed=function(self,x,y,button,istouch,...)
      if runtime.isBridgeActive() and Browser.active and button==1 and not istouch then
        require("src.import.LauncherView").clickAt(self,x,y)
        return
      end
      return mouse(self,x,y,button,istouch,...)
    end
  end
  print("[frame-import] Inline browsers and available VR controls installed")
  return true
end
return Picker
