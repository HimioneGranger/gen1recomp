-- ROM-free job regression: missing female graphics must alias male assets,
-- while actual female art still gets composed/encoded and published separately.
for _,name in ipairs({'Nds','Narc','Lz','Graphics','Cells','Animation','Composer'}) do
  package.loaded['src.import.gen5.'..name]={}
end
package.loaded['src.mods.StreamMD5']={}
local writes,published,encoded,read,composed=0,nil,0,{},{}
package.loaded['src.import.Importers']={
  writeAsset=function(importer,pack,file,bytes) writes=writes+1;return #bytes end,
  writePack=function(importer,pack,manifest) published=manifest;return true end,
}
love={image={}}
local Bw=require('src.import.gen5.BwImport')
assert(Bw.EXPORT_VERSION=='1.0.1')
local archive={member=function(index)
  -- Dex25 has distinct front female art; dex252 has none on either side.
  return index==25*20+3 and 'female art' or ''
end}
Bw.identify=function() return {md5='fixture'},archive end
Bw.readPokemon=function(_,dex,side,female)
  local key=dex..'/'..side..'/'..tostring(female)
  read[#read+1]=key
  return {key=key,normal='normal',shiny='shiny',capped=dex==252}
end
Bw.poses=function(sprite,progress)
  composed[#composed+1]=sprite.key
  progress(1,1)
  return {frames={{}},cycleCapped=sprite.capped}
end
Bw.image=function(poses,palette)
  return {getDimensions=function()return 8,8 end,release=function()end,
    encode=function()
      encoded=encoded+1
      return {getString=function()return palette end,release=function()end}
    end}, {cycleCapped=poses.cycleCapped,frames=1,tickRate=60,durations={1}}
end
local job=Bw.job('no ROM',{}, {species={25,252}})
local lastDone,result=0,nil
while coroutine.status(job)~='dead' do
  local ok,value=coroutine.resume(job);assert(ok,value)
  if coroutine.status(job)=='dead' then result=value
  else
    assert(value.total==16 and value.done>=lastDone and value.done<=16)
    lastDone=value.done
  end
end
assert(result.packs.battle_sprites==16 and result.cappedCycles==8)
assert(#read==5 and #composed==5 and writes==10 and encoded==10)
assert(published.version=='1.0.1')
local count=0
for id,entry in pairs(published.entries) do
  count=count+1;assert(entry.file:find('/1.0.1/',1,true))
  if id:match('/female$') then
    local male=published.entries[id:gsub('/female$','')]
    if id:find('/025/front',1,true) then assert(entry.file~=male.file)
    else
      assert(entry.file==male.file and entry.size==male.size and entry.width==male.width)
      assert(entry.sprite==male.sprite and entry.frames==male.frames)
    end
  end
end
assert(count==16)
print('PASS missing-female atlas reuse: logical entries, distinct female art, capped counts, species selection and bounded progress')

writes,published,encoded,read,composed=0,nil,0,{},{}
local full=Bw.job('no ROM',{})
repeat
  local ok,value=coroutine.resume(full);assert(ok,value)
  if coroutine.status(full)=='dead' then result=value end
until coroutine.status(full)=='dead'
assert(result.packs.battle_sprites==5192 and result.cappedCycles==8)
assert(#read==1299 and #composed==1299 and writes==2598 and encoded==2598)
count=0;for _ in pairs(published.entries) do count=count+1 end
assert(count==5192 and published.entries['shiny/649/back/female'])
print('PASS complete 649-species logical entry coverage with fallback alias optimization')
