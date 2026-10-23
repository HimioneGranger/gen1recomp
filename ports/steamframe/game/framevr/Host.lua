-- Platform adapter around an unmodified official .love release.
local Runtime=require("framevr.Runtime")
local Panel=require("framevr.MonoPanel")
local Input=require("framevr.Input")
local Surface=require("framevr.Surface")
local StartupFocus=require("framevr.StartupFocus")
local Host={runtime=Runtime,input=Input,surface=Surface}
local prepared,paused,pausedAudio
local owner,ownerKind,renderingState
local nextDiagnostic,diagnosticState=0,nil
Host.draws,Host.submits=0,0
function Host.desktopState(visible,focus,active) return visible(),focus(),active() end
local function trace(text)
  local out=os.getenv("FRAME_TEST_OUTPUT")
  if out then local f=io.open(out.."/startup-trace.txt","ab"); if f then f:write(text,"\n"); f:close() end end
end

local function mountRoms()
  local source=love.filesystem.getSource():gsub("\\","/")
  local base=source:match("^(.*)/[^/]+$")
  if not base then return end
  local path=base.."/roms"
  -- Prepending source archives is LÖVE's job; this extra read-only root is
  -- appended so a player's ROM folder can never shadow official source files.
  if love.filesystem.mount(path,"",true) then return end
  local ok,ffi=pcall(require,"ffi")
  if not ok then return end
  pcall(ffi.cdef,"int PHYSFS_mount(const char *, const char *, int);")
  for _,name in ipairs({"love","love-11.5","liblove-11.5.so"}) do
    local loaded,lib=pcall(ffi.load,name)
    if loaded then
      local mounted=pcall(function() assert(lib.PHYSFS_mount(path,"",1)~=0) end)
      if mounted then return end
    end
  end
  pcall(function() ffi.C.PHYSFS_mount(path,"",1) end)
end

local function beginFrame()
  if prepared or not Runtime.isEnabled() then return end
  Runtime.beginFrame(love.graphics.getDimensions())
  prepared=true
end

local function closeFrame()
  Runtime.abortFrame()
  prepared=nil
end

local function attachCallbacks()
  -- Called AFTER official love.load/Boot handoff, including self-updates.
  require("framevr.ImportPicker").install(Runtime)
  require("framevr.StudioPicker").install(Runtime)
  local scroll=require("framevr.EditorScroll")
  scroll.install(Runtime,Input)
  local backend={}
  function backend:beginFrame(kind,subject)
    if kind=="editor" then scroll.attach(package.loaded["Kit"]) end
    if Runtime.isBridgeActive() and (subject~=owner or kind~=ownerKind) then
      owner,ownerKind=subject,kind
      Host.focusDirty=true
    end
    Input.setSubject(kind,subject)
  end
  require("src.core.HostDisplay").setBackend(backend)
  local sync=require("src.core.PresentSync")
  local wait,hardware=sync.waitBeforePresent,sync.hardwarePacesCap
  sync.waitBeforePresent=function(...)
    if Runtime.isBridgeActive() and Runtime.isFramePaced() then return end
    return wait(...)
  end
  sync.hardwarePacesCap=function(...)
    if Runtime.isBridgeActive() and Runtime.isFramePaced() then return true end
    return hardware(...)
  end
  local update,draw=love.update,love.draw
  love.update=function(dt)
    beginFrame()
    local simulate=not Runtime.isBridgeActive() or Runtime.shouldSimulate()
    if Runtime.isBridgeActive() then StartupFocus.focus(simulate) end
    if paused~=not simulate then
      paused=not simulate; Input.suspend()
      Host.focusDirty=true
      if love.audio then
        if paused then pausedAudio=love.audio.pause()
        elseif pausedAudio then love.audio.play(pausedAudio); pausedAudio=nil end
      end
    end
    local rendering=Runtime.shouldRender()
    if Host.focusDirty then
      trace("focus-dispatch:"..tostring(simulate))
      local focus=Host.focusCallback or love.focus
      if focus then focus(simulate) end
      trace("focus-dispatched")
    end
    if Runtime.isBridgeActive() and (Host.focusDirty or renderingState~=rendering) then
      local visible=Host.visibleCallback
      trace("visible-dispatch:"..tostring(rendering))
      if visible then visible(rendering) end
      trace("visible-dispatched")
      renderingState=rendering
    end
    Host.focusDirty=nil
    if Runtime.isBridgeActive() then
      local state=table.concat({tostring(simulate),tostring(rendering),tostring(ownerKind),
        tostring(Host.desktopActive),tostring(Host.desktopVisible),tostring(Host.desktopFocused)},"/")
      local now=love.timer.getTime()
      if state~=diagnosticState or now>=nextDiagnostic then
        local status=Runtime.status().native or {}
        print(string.format("[frame-focus] simulate=%s render=%s session=%s xrFocus=%s owner=%s desktopActive=%s desktopVisible=%s desktopFocus=%s draws=%d submits=%d",
          tostring(simulate),tostring(rendering),tostring(status.sessionState),tostring(status.focused),
          tostring(ownerKind),tostring(Host.desktopActive),tostring(Host.desktopVisible),tostring(Host.desktopFocused),Host.draws,Host.submits))
        diagnosticState=state; nextDiagnostic=now+30
      end
    end
    if Runtime.isQuitRequested() then love.event.quit() end
    if simulate and Runtime.isBridgeActive() then
      local actions=Runtime.pollActions()
      Input.update(actions,Runtime.frameViews())
      scroll.update(actions.scrollY,Runtime.frameDelta(dt))
    end
    if simulate or Input.kind~="game" then
      update(Runtime.frameDelta(dt))
    end
    if Host.testDriver and Input.subject then
      local ok,err=coroutine.resume(Host.testDriver,Input.subject)
      if not ok then error(err) end
      if coroutine.status(Host.testDriver)=="dead" then love.event.quit(); Host.testDriver=nil end
    end
  end
  love.draw=function(...)
    Host.draws=Host.draws+1
    beginFrame()
    require("framevr.ViewSetup").report(Runtime,Panel)
    local source=Surface.capture(draw,...)
    if Runtime.isBridgeActive() and Runtime.shouldRender() and Runtime.frameViews() then
      if not Runtime.submit(source,source) then
        error("OpenXR display submission failed: "..tostring(Runtime.status().lastError),0)
      end
      Host.submits=Host.submits+1
      StartupFocus.submitted()
    end
    Surface.mirror(source)
  end
  local quit=love.quit
  love.quit=function(...)
    local result=quit and quit(...)
    if not result then Input.release(); Runtime.shutdown(); Surface.release() end
    return result
  end
end

function Host.install()
  -- Cache-safe across official startup/self-updates; inactive until XR is live.
  require("framevr.WindowMode").install(Runtime)
  Surface.install(Runtime)
  Input.install(Runtime,Panel)
  mountRoms()
  local originalRun=love.run
  love.run=function()
    trace("official-run-enter")
    local step=originalRun() -- official startup, update handoff and pacing setup
    trace("official-run-ready")
    attachCallbacks()
    local ok,version=pcall(require,"src.core.Version")
    print("[frame-host] official="..tostring(ok and version.engine or "unknown").." host=focus-r15")
    trace("callbacks-attached")
    local test=os.getenv("FRAME_TEST_DRIVER")
    if test then Host.testDriver=coroutine.create(assert(loadfile(test))()) end
    if test then
      love.errorhandler=function(message)
        local f=assert(io.open(os.getenv("FRAME_TEST_OUTPUT").."/outer-error.txt","wb"))
        f:write(tostring(message),"\n",debug.traceback()); f:close()
        return function() return 1 end
      end
    end
    if Runtime.isEnabled() then
      require("framevr.ViewSetup").prepare(Runtime)
      Runtime.start(love.graphics.getDimensions())
      if os.getenv("POKEPORT_VR_REQUIRED")=="1" and not Runtime.isBridgeActive() then
        local status=Runtime.status()
        error("Steam Frame OpenXR could not start: "..tostring(status.bridgeError or status.lastError),0)
      end
    end
    return function()
      -- XR owns session focus. SDL desktop focus can differ from headset focus.
      local focus,visible=love.focus,love.visible
      Host.focusCallback=focus
      Host.visibleCallback=visible
      local windowVisible=love.window.isVisible
      local windowFocus=love.window.hasFocus
      local graphicsActive=love.graphics.isActive
      Host.desktopVisible,Host.desktopFocused,Host.desktopActive=Host.desktopState(windowVisible,windowFocus,graphicsActive)
      if Runtime.isBridgeActive() then
        love.focus=function() end; love.visible=function() end
        love.window.isVisible=function() return true end
        love.window.hasFocus=function() return Runtime.shouldSimulate() end
        -- SDL mirror visibility must not suppress a valid offscreen XR draw.
        -- Never synthesize shouldRender, focus, or views when XR is in standby.
        love.graphics.isActive=function()
          return Host.desktopActive or (Runtime.shouldRender() and Runtime.frameViews()~=nil)
        end
        if love.window.setVSync then love.window.setVSync(0) end
      end
      local ok,result=xpcall(step,debug.traceback)
      love.focus,love.visible=focus,visible
      love.window.isVisible=windowVisible
      love.window.hasFocus=windowFocus
      love.graphics.isActive=graphicsActive
      closeFrame()
      if not ok then
        local out=os.getenv("FRAME_TEST_OUTPUT")
        if out and os.getenv("FRAME_TEST_DRIVER") then
          local f=io.open(out.."/test-error.txt","wb"); if f then f:write(result); f:close() end
          return 1
        end
        error(result,0)
      end
      return result
    end
  end
end
return Host

