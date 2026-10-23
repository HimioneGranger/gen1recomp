return function(subject)
 local out=assert(os.getenv("FRAME_TEST_OUTPUT"))
 local Host=require("framevr.Host")
 local deadline=love.timer.getTime()+5
 repeat coroutine.yield() until love.timer.getTime()>=deadline
 assert(Host.runtime.isBridgeActive() and Host.input.kind=="launcher")
 local ioOpen=io.popen
 local dialogAttempts=0
 local function guard(command)
  local lower=tostring(command):lower()
  if lower:find("powershell",1,true) or lower:find("zenity",1,true)
   or lower:find("kdialog",1,true) or lower:find("osascript",1,true)
   or lower:find("openfiledialog",1,true) then
   dialogAttempts=dialogAttempts+1;error("desktop dialog attempted: "..lower)
  end
 end
 io.popen=function(command,...) guard(command);return ioOpen(command,...) end
 local Shell=require("src.core.HostShell")
 local shellOpen=Shell.popen
 if shellOpen then Shell.popen=function(command,...) guard(command);return shellOpen(command,...) end end
 local File=require("src.core.FilePicker")
 local originalOpen=File.open
 File.open=function() dialogAttempts=dialogAttempts+1;error("desktop FilePicker.open attempted") end
 for _,driver in ipairs({"main-rom","import-controls","skin-picker","studio-picker","editor-scroll","window-mode"}) do
  assert(loadfile(out.."/"..driver.."-driver.lua"))()(subject)
 end
 File.open=originalOpen;io.popen=ioOpen;Shell.popen=shellOpen
 assert(dialogAttempts==0,"no desktop dialog attempt")
 local f=assert(io.open(out.."/gpu-results.txt","wb"))
 f:write("PASS exact official 0.3.95 payload and retained r15 wrapper with scoped ImportPicker compatibility fix.\n",
 "Actual original main ROM choose/startPath boundary, Extras importer boundary, skin ZIP boundary, My Skins import validation/cancel.\n",
 "Real LOVE GPU + fake API2 XR; Frame Input stick/A/laser/cancel routing; no desktop dialog calls.\n",
 "Synthetic selected file paths and archive boundary only. No physical headset or actual ROM/skin installation tested.\n")
 f:close()
 love.event.quit(0)
end
