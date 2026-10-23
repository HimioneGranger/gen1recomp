local function trace(text)
  local out=os.getenv("FRAME_TEST_OUTPUT")
  if out then local f=io.open(out.."/startup-trace.txt","ab"); if f then f:write(text,"\n"); f:close() end end
end
trace("host-main-enter")
assert(love.filesystem.mount(assert(_G.FRAME_OFFICIAL_ARCHIVE), "official.love", "", false))
trace("official-mounted")
local official = assert(_G.FRAME_OFFICIAL_MAIN, "official release entry point missing")
_G.FRAME_OFFICIAL_MAIN = nil
official()
trace("official-main-loaded")
local testBridge=os.getenv("FRAME_TEST_BRIDGE")
if testBridge then
  local bridge=assert(loadfile(testBridge))()
  _G.FRAME_TEST_BRIDGE_OBJECT=bridge
  local loadlib=package.loadlib
  package.loadlib=function(path,symbol)
    if symbol=="luaopen_xrbridge" then return function() return bridge end end
    return loadlib(path,symbol)
  end
end
require("framevr.Host").install()
trace("host-installed")
