-- luajit tests/quest/host_detection_test.lua; no graphics, ROM, native library or device.
package.path='./?.lua;./?/init.lua;'..package.path
love={system={getOS=function()return 'Windows'end}}
local Host=require('src.core.HostDisplay')
assert(Host.installPackagedBackend()==false,'desktop must remain inert')
assert(rawget(_G,'QUEST_PANEL_ACTIVE')==nil)
local native={update=function(self,dt)self.dt=dt end}
package.loaded['src.host.PackagedDisplay']={detect=function()return native end}
assert(Host.installPackagedBackend()==true)
Host.update(.25);assert(native.dt==.25)
Host.setBackend(nil);assert(Host.update(.25)==nil)
print('quest host detection: PASS (stock inert, optional fake provider)')
