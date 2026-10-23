-- Run the unmodified release configuration, then restore this host's entry
-- point. The official archive is never extracted or rewritten.
function love.conf(t)
  local ok,err=xpcall(function()
  _G.FRAME_OFFICIAL_ARCHIVE=assert(love.filesystem.newFileData("official.dat"))
  assert(love.filesystem.mount(_G.FRAME_OFFICIAL_ARCHIVE, "official.love", "", false),"cannot mount official release data")
  assert(not love.filesystem.read("conf.lua"):find("FRAME_OFFICIAL_MAIN",1,true),"official archive did not take read priority")
  _G.FRAME_OFFICIAL_MAIN = assert(love.filesystem.load("main.lua"))
  assert(love.filesystem.load("conf.lua"))()
  love.conf(t)
  assert(love.filesystem.unmount(_G.FRAME_OFFICIAL_ARCHIVE))
  end,debug.traceback)
  if not ok then
    local output=os.getenv("FRAME_TEST_OUTPUT")
    if output then
      local f=io.open(output.."/startup-error.txt","wb")
      if f then f:write(err); f:close() end
      os.exit(1)
    end
    error(err,0)
  end
end
