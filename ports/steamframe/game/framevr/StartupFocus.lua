-- Small, flushed signals to the optional bounded startup helper. No focus is
-- synthesized here: OpenXR still owns input and simulation eligibility.
local Focus={}
local ready,focused
local function signal(value)
  local path=os.getenv("GEN1_FRAME_STARTUP_FILE")
  if not path or path=="" then return end
  local f=io.open(path,"ab")
  if f then f:write(value,"\n"); f:close() end
end
function Focus.focus(value)
  if value and not focused then focused=true; signal("focused") end
end
function Focus.submitted()
  if not ready then ready=true; signal("ready") end
end
return Focus
