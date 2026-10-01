-- Atomic native picker publication through the actual launcher polling path.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local RomImporter=require('src.import.RomImporter')
local file='picked_importer_gen5_bw.bin'
local partial=file..'.part'
local oldSave=love.filesystem.getSaveDirectory
love.filesystem.getSaveDirectory=function() return '/procedural-picker-fixture' end
local ready={}
for _,id in ipairs(require('src.core.GameVersion').ORDER) do ready[id]=true end
local function pending()
 return setmetatable({android=true,ready=ready,pickPending=true,pickerPendingKind='importer',
  pickerPendingImporterId='gen5_bw',_runImporterData=function(self,id,bytes)
   self.received={id=id,bytes=bytes}
  end},RomImporter)
end
for _,name in ipairs({file,partial,'pick_error.flag','pick_complete.flag'}) do love.filesystem.remove(name) end
love.filesystem.write(partial,'unfinished procedural data')
local ri=pending()
ri:_pollPickedFiles(10)
T.check(ri.pickPending,'partial copy keeps picker pending even after long delay')
T.eq(ri.received,nil,'partial file never starts import')
T.eq(ri.pickerPendingImporterId,'gen5_bw','pending importer identity retained')
love.filesystem.write(file,'complete procedural data')
ri:_pollPickedFiles(0.5)
T.eq(ri.received.id,'gen5_bw','final filename reaches correct importer')
T.eq(ri.received.bytes,'complete procedural data','final published bytes handed to importer')
T.eq(ri.pickPending,nil,'success clears pending state')
T.eq(love.filesystem.getInfo(file),nil,'consumed final inbox file removed')
ri=pending()
love.filesystem.write('pick_error.flag',file)
ri:_pollPickedFiles(0.5)
T.check(ri._importerNotice and ri._importerNotice.ok==false,'native copy failure reaches importer notice')
T.eq(ri.modNotice,nil,'copy failure does not become a required-mod import')
T.eq(ri.pickPending,nil,'failure clears pending state')
T.eq(ri.pickerPendingImporterId,nil,'failure retires importer identity')
love.filesystem.remove(partial)
love.filesystem.getSaveDirectory=oldSave
T.finish('gen5 Android atomic picker poll')
