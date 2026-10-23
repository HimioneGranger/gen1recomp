return function(subject)
 local out=assert(os.getenv("FRAME_TEST_OUTPUT"))
 assert(loadfile(out.."/startup-focus-driver.lua"))()(subject)
 local Host=require("framevr.Host")
 local Panel=require("framevr.MonoPanel")
 local source=Host.surface.capture(function() love.graphics.clear(0,0,1,1) end)
 local min,mag,aniso=source:getFilter()
 assert(min=="linear" and mag=="linear" and aniso>=1)
 assert(source:getMipmapCount()>1 and source:getMipmapFilter()=="linear")
 for _,col in ipairs({{0,0,1},{0,1,0}}) do
  source=Host.surface.capture(function() love.graphics.clear(col[1],col[2],col[3],1) end)
  local eye=Panel.render(source,Host.runtime.frameViews())
  local data=eye:newImageData()
  local cr,cg,cb=data:getPixel(math.floor(eye:getWidth()/2),math.floor(eye:getHeight()/2))
  assert(math.abs(cr-col[1])<.02 and math.abs(cg-col[2])<.02 and math.abs(cb-col[3])<.02,"fresh mip source colors")
  data:release()
 end
 _G.FRAME_TEST_BRIDGE_OBJECT.capture="latest-launcher"
 coroutine.yield();coroutine.yield()
 local f=assert(io.open(out.."/gpu-results.txt","wb"))
 f:write("PASS exact0.3.95 launcher with retainedr15 startup focus signaling: submits while unfocused, one ready, one actual focused event, no rearm. Real GPU source linear/trilinear/anisotropic filtering and fresh mip colors verified. Fake XR only; physical Steam dashboard/image quality pending.\n");f:close()
 love.event.quit(0)
end
