local View={}
local last
function View.prepare(runtime)
  if not runtime.isEnabled() or runtime.isBridgeActive() then return false end
  local w,h,flags=love.window.getMode()
  flags=flags or {}
  if flags.fullscreen then
    print("[frame-view] r12 fullscreen desktop size retained; closer VR screen enabled")
    return false
  end
  local width,height=math.max(w,1600),math.max(h,1000)
  if width==w and height==h then return true end
  -- This executes before Runtime.start creates the native graphics binding.
  local ok,result=pcall(love.window.setMode,width,height,flags)
  local actualW,actualH=love.graphics.getDimensions()
  print(string.format("[frame-view] r12 startup requested=%dx%d actual=%dx%d accepted=%s",
    width,height,actualW,actualH,tostring(ok and result~=false)))
  return ok and result~=false
end
function View.report(runtime,panel)
  if not runtime.isBridgeActive() then return end
  local views=runtime.frameViews()
  if not (views and views[1] and views[2]) then return end
  local w,h=love.graphics.getDimensions()
  local a,width=panel.geometry(views,w,h)
  local key=table.concat({w,h,views[1].width,views[1].height,views[2].width,views[2].height},"x")
  if key==last then return end
  last=key
  local native=runtime.status and runtime.status().native or {}
  print(string.format("[frame-quality] r14 foveation requested=%s applied=%s status=%s",
    tostring(native.foveationRequested),tostring(native.foveationApplied),tostring(native.foveationMessage)))
  local p,q=views[1].position,views[2].position
  local dx,dy,dz=a.x-(p.x+q.x)/2,a.y-(p.y+q.y)/2,a.z-(p.z+q.z)/2
  print(string.format("[frame-view] r12 source=%dx%d eyes=%dx%d/%dx%d screenWidth=%.2fm distance=%.2fm",
    w,h,views[1].width,views[1].height,views[2].width,views[2].height,width,math.sqrt(dx*dx+dy*dy+dz*dz)))
end
return View
