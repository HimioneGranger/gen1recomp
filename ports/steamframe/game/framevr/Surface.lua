-- Virtualize only the display framebuffer. Intermediate engine canvases and
-- the engine's view of the default target remain unchanged.
local Surface={}
local target,active,runtime,filtered,mipmaps
local rawSet,rawGet
function Surface.install(hostRuntime)
  runtime=hostRuntime
  local g=love.graphics
  rawSet,rawGet=g.setCanvas,g.getCanvas
  g.setCanvas=function(value,...)
    if active and (value==nil or type(value)=="table" and next(value)==nil) then
      return rawSet({target,stencil=true})
    end
    return rawSet(value,...)
  end
  g.getCanvas=function()
    local value=rawGet()
    if active and value==target then return nil end
    return rawGet()
  end
end

function Surface.capture(draw,...)
  local g=love.graphics
  local w,h=g.getDimensions()
  local vr=runtime and runtime.isBridgeActive() or false
  if not target or target:getWidth()~=w or target:getHeight()~=h or filtered~=vr then
    if target then target:release() end
    filtered,mipmaps=vr,false
    if vr then
      local ok,value=pcall(g.newCanvas,w,h,{dpiscale=1,format="rgba8",readable=true,mipmaps="manual"})
      if ok then target=value; mipmaps=true end
    end
    if not mipmaps then target=g.newCanvas(w,h,{dpiscale=1,format="rgba8",readable=true}) end
    if vr then
      target:setFilter("linear","linear",8)
      if mipmaps then target:setMipmapFilter("linear",0) end
      print("[frame-quality] r14 screen sampling=linear anisotropy="..tostring(select(3,target:getFilter())).." mipmaps="..tostring(mipmaps))
    else target:setFilter("nearest","nearest") end
  end
  local args={n=select("#",...),...}
  g.push("all")
  rawSet({target,stencil=true}); g.origin(); g.clear(0,0,0,1)
  active=true
  local ok,err=xpcall(function() return draw(unpack(args,1,args.n)) end,debug.traceback)
  active=false
  g.pop()
  if not ok then error(err,0) end
  -- Once per completed source frame, before either eye samples it. No CPU
  -- readback or temporal history: the desktop/engine textures are untouched.
  if mipmaps then
    local generated,reason=pcall(target.generateMipmaps,target)
    if not generated then
      target:setMipmapFilter()
      mipmaps=false
      print("[frame-quality] r14 mip generation unavailable; linear fallback: "..tostring(reason))
    end
  end
  return target
end

function Surface.mirror(source)
  local g=love.graphics
  g.push("all")
  rawSet(); g.origin(); g.setShader(); g.setScissor(); g.setStencilTest()
  g.setDepthMode(); g.setColorMask(true,true,true,true)
  g.setColor(1,1,1,1); g.setBlendMode("replace","premultiplied")
  g.draw(source,0,0)
  g.pop()
end

function Surface.release()
  active=false
  if target then target:release(); target=nil end
  filtered,mipmaps=nil,nil
end
return Surface
