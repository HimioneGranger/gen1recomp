-- Synthetic OpenXR boundary only. Actual LOVE launcher, wrapper and canvases run.
local B={frames=0,submits=0,aborts=0,focused=true,render=true,actions={a=false,b=false,start=false,select=false,move={x=0,y=0}}}
local function hand(x)
 return{valid=true,trigger=0,grip=0,gripActive=true,position={x=x,y=1.2,z=-.4},orientation={x=0,y=0,z=0,w=1},
 gripPose={valid=true,position={x=x,y=1.2,z=-.4},orientation={x=0,y=0,z=0,w=1}}}
end
function B.create()return true end
function B.capabilities()return{api=2,grips=true,gripPoses=true,look=true,haptics=true}end
function B.status()return{available=true,ready=true,focused=B.focused,shouldRender=B.render,
 effectiveShouldRender=B.render,beginCount=B.frames,predictedDisplayTime=1e12+B.frames*11111111,predictedDisplayPeriod=11111111,quitRequested=false}end
function B.beginFrame()
 B.frames=B.frames+1
 local function eye(x)return{position={x=x,y=1.6,z=0},orientation={x=0,y=0,z=0,w=1},
 width=480,height=480,poseUsable=true,positionValid=true,orientationValid=true,syntheticPose=false,
 fov={left=-.8,right=.8,up=.8,down=-.8}}end
 return eye(-.032),eye(.032),B.render
end
function B.pollActions()
 local a={available=true,look={x=0,y=0,active=true},scrollY=0,hands={left=hand(-.2),right=hand(.2)}}
 for k,v in pairs(B.actions)do a[k]=v end
 return{actions=a}
end
function B.submitCanvases(left,right)
 assert(left~=right,'host must submit distinct GPU eye canvases')
 B.submits=B.submits+1
 if B.capture then
  for _,item in ipairs{{left,'left'},{right,'right'}}do
   local im=item[1]:newImageData();local bytes=im:encode('png')
   local f=assert(io.open(assert(os.getenv('FRAME_TEST_OUTPUT'))..'/'..B.capture..'-'..item[2]..'.png','wb'));f:write(bytes:getString());f:close();im:release();bytes:release()
  end
  B.capture=nil
 end
 return true
end
function B.pulse(side,amp,ms)assert(side=='left' and amp==.2 and ms==100);B.pulses=(B.pulses or 0)+1;return true end
function B.abortFrame()B.aborts=B.aborts+1 end
function B.destroy()B.destroyed=true end
return B
