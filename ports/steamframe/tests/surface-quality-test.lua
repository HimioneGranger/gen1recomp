package.path="game/?.lua;"..package.path
local vr,failAllocation,failGeneration=false,false,false
local generated=0
local function canvas(w,h,opts)
  if opts.mipmaps and failAllocation then error("unsupported mip allocation") end
  local c={w=w,h=h,mips=opts.mipmaps}
  function c:getWidth() return self.w end
  function c:getHeight() return self.h end
  function c:setFilter(a,b,n) self.filter=a; self.aniso=n end
  function c:getFilter() return self.filter,self.filter,self.aniso end
  function c:setMipmapFilter(a) self.mipFilter=a end
  function c:generateMipmaps()
    generated=generated+1
    if failGeneration then error("unsupported mip generation") end
  end
  function c:release() self.released=true end
  return c
end
love={graphics={newCanvas=canvas,getDimensions=function() return 1600,1000 end,
  setCanvas=function() end,getCanvas=function() end,push=function() end,
  pop=function() end,origin=function() end,clear=function() end}}
local Surface=require("framevr.Surface")
Surface.install({isBridgeActive=function() return vr end})
local flat=Surface.capture(function() end)
assert(flat.filter=="nearest" and not flat.mips and generated==0)
vr=true
local smooth=Surface.capture(function() end)
assert(flat.released and smooth.filter=="linear" and smooth.mipFilter=="linear" and generated==1)
Surface.capture(function() end); assert(generated==2)
failGeneration=true
Surface.capture(function() end)
assert(smooth.mipFilter==nil,"failed mip generation disables mip sampling")
Surface.capture(function() end); assert(generated==3,"unsupported generation is not retried each frame")
Surface.release(); failAllocation=true
local fallback=Surface.capture(function() end)
assert(fallback.filter=="linear" and not fallback.mips,"unsupported allocation uses linear fallback")
vr=false
local again=Surface.capture(function() end)
assert(fallback.released and again.filter=="nearest" and not again.mips)
Surface.release()
print("PASS flat sampling preserved, per-frame VR mip refresh, runtime quality transitions, allocation/generation fallback and release")
