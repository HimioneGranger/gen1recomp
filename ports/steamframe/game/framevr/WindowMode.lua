-- OpenXR's GLX binding owns the current drawable/context until shutdown.
-- VideoMode (game start), FaithfulRes and editor transitions also mutate it.
local Adapter={}
local installed,counts
function Adapter.install(runtime)
  local window=love.window
  if installed==window then return true end
  if not (window and type(window.setMode)=="function") then return false end
  installed,counts=window,{}
  for _,name in ipairs({"setMode","setFullscreen","updateMode"}) do
    local original=window[name]
    if type(original)=="function" then
      window[name]=function(...)
        if not runtime.isBridgeActive() then return original(...) end
        counts[name]=(counts[name] or 0)+1
        if counts[name]<=4 then
          local caller=debug.getinfo(2,"Sl") or {}
          print(string.format("[frame-window] r13 deferred %s caller=%s:%s count=%d; live XR drawable retained",
            name,tostring(caller.short_src),tostring(caller.currentline),counts[name]))
        end
        -- Original callers own/save preferences. Apply desktop mode on a fresh
        -- launch before XR starts; query functions keep reporting actual size.
        return true
      end
    end
  end
  print("[frame-window] r13 native mode boundary installed; startup/flat changes remain native")
  return true
end
return Adapter
