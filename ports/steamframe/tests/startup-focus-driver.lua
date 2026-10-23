return function()
  local Host=require("framevr.Host")
  local bridge=assert(_G.FRAME_TEST_BRIDGE_OBJECT)
  local path=assert(os.getenv("GEN1_FRAME_STARTUP_FILE"))
  local function signals()
    local f=assert(io.open(path,"rb")); local text=f:read("*a"); f:close(); return text
  end
  -- The actual launcher must draw a frame while the real XR focus flag is false.
  coroutine.yield(); coroutine.yield()
  assert(Host.submits>0 and not bridge.focused)
  assert(signals()=="ready\n","first completed submit flushes ready without granting focus")
  local before=Host.submits
  coroutine.yield(); coroutine.yield()
  assert(Host.submits>before and signals()=="ready\n")
  bridge.focused=true
  coroutine.yield(); coroutine.yield()
  assert(signals()=="ready\nfocused\n","actual XR focus delivered separately and only once")
  bridge.focused=false
  coroutine.yield(); coroutine.yield()
  bridge.focused=true
  coroutine.yield(); coroutine.yield()
  assert(signals()=="ready\nfocused\n","later menu/focus changes never rearm startup helper")
  local out=assert(os.getenv("FRAME_TEST_OUTPUT"))
  local f=assert(io.open(out.."/startup-gpu-tests.txt","wb"))
  f:write("PASS real official launcher/SDL/GPU fake XR: submits while unfocused, flushed first-frame ready, actual XR focus signal once; subsequent focus changes do not rearm. No Steam UI or physical Frame contacted.\n"); f:close()
end
