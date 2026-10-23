-- Run the unmodified release configuration, then restore this host's entry
-- point. The official archive is never extracted or rewritten.
function love.conf(t)
  local ok,err=xpcall(function()
  local file=assert(io.open(assert(os.getenv("FRAME_TEST_OFFICIAL")),"rb"))
  local bytes=file:read("*a");file:close()
  _G.FRAME_OFFICIAL_ARCHIVE=love.filesystem.newFileData(bytes,"official.dat")
  assert(love.filesystem.mount(_G.FRAME_OFFICIAL_ARCHIVE, "official.love", "", false),"cannot mount official release data")
  assert(not love.filesystem.read("conf.lua"):find("FRAME_OFFICIAL_MAIN",1,true),"official archive did not take read priority")
  _G.FRAME_OFFICIAL_MAIN = assert(love.filesystem.load("main.lua"))
  assert(love.filesystem.load("conf.lua"))()
  love.conf(t)
  t.identity=assert(os.getenv("GEN1_FRAME_TEST_ID"))
  t.console=false
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
