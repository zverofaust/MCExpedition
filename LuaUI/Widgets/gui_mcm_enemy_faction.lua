--------------------------------------------------------------------------------
-- MCM optional radial enemy faction selector
-- Authors: zvero + ChatGPT
--------------------------------------------------------------------------------
function widget:GetInfo()
 return {name="MCM Enemy Faction Wheel",desc="Select enemy faction before deployment; /enemyfaction with cheats",author="zvero + ChatGPT",date="2026-10-11",license="GPL v2",layer=1100,enabled=true}
end
local ownership=VFS.Include("LuaRules/Configs/mcl_mode_gadgets.lua")
if ownership.GetMode()~="mercs" then return end
local choices={{"RANDOM","Random"},{"FS","Federated Suns"},{"LA","Lyran Alliance"},{"DC","Draconis Combine"},{"CC","Capellan Confederation"},{"FW","Free Worlds League"}}
local visible=false
local finished=false
local initialWindow=true
local elapsed=0
local timeout=15
local ready=false
local visibleFrames=0
local cx,cy,inner,outer=0,0,75,235
local hovered=nil
local function Geometry()
 local w,h=Spring.GetViewGeometry()
 cx,cy=w/2,h/2
 local s=math.max(0.75,math.min(1.35,h/1080))
 inner,outer=75*s,235*s
end
local function Hover(x,y)
 local dx,dy=x-cx,y-cy
 local radius=math.sqrt(dx*dx+dy*dy)
 if radius<inner or radius>outer then return nil end
 local angle=math.atan2(dy,dx)
 local start=math.pi/2-math.pi/#choices
 local a=(angle-start)%(math.pi*2)
 return math.floor(a/(math.pi*2/#choices))+1
end
local function Choose(key)
 initialWindow=false
 Spring.SendLuaRulesMsg("MCMENEMYFACTION|"..key)
 visible=false
 finished=true
 WG.MCMEnemyFactionSelectionComplete=true
 Spring.Echo('[MCM Enemy Faction] Selected '..key)
end
function widget:Initialize()
 if Spring.GetSpectatingState() or Spring.IsReplay() then widgetHandler:RemoveWidget(widget) return end
 Geometry()
 WG.MCMEnemyFactionSelectionComplete=false
 visible=false
end
function widget:ViewResize() Geometry() end
function widget:Update(dt)
 if not ready then
  if Spring.GetGameRulesParam("mcl_mode")~="mercs" then return end
  ready=true
  if Spring.GetGameRulesParam("mcm_contract_active")==1 or Spring.GetGameRulesParam("mcm_lance_ready")==1 then
   finished=true
   WG.MCMEnemyFactionSelectionComplete=true
  else
   visible=true
   elapsed=0
   visibleFrames=0
   Spring.Echo('[MCM Enemy Faction] Initial wheel opened')
  end
 end
 if not visible then return end
 -- Do not dismiss the initial wheel on contract-state changes: only an
 -- explicit selection or the full timeout can complete the startup handshake.
 -- Count only reasonable frame deltas, guarding against an oversized first Update.
 elapsed=elapsed+math.min(math.max(dt or 0,0),0.25)
 visibleFrames=visibleFrames+1
 if elapsed>=timeout and visibleFrames>=30 and initialWindow then Choose("RANDOM") end
end
function widget:DrawScreen()
 if not visible then return end
 local x,y=Spring.GetMouseState()
 hovered=Hover(x,y)
 gl.Color(0,0,0,0.12)
 local w,h=Spring.GetViewGeometry()
 gl.Rect(0,0,w,h)
 gl.Text("SELECT ENEMY FACTION",cx,cy+outer+35,24,"oc")
 gl.Text("Random selected automatically in "..math.max(0,math.ceil(timeout-elapsed)).."s",cx,cy-outer-38,14,"oc")
 for i=1,#choices do
  local angle=math.pi/2+(i-1)*math.pi*2/#choices
  local half=math.pi/#choices
  local x1,y1=cx+inner*math.cos(angle-half),cy+inner*math.sin(angle-half)
  local x2,y2=cx+outer*math.cos(angle-half),cy+outer*math.sin(angle-half)
  local x3,y3=cx+outer*math.cos(angle+half),cy+outer*math.sin(angle+half)
  local x4,y4=cx+inner*math.cos(angle+half),cy+inner*math.sin(angle+half)
  local alpha=hovered==i and 0.43 or 0.14
  gl.Color(0.55,0.6,0.68,alpha)
  gl.BeginEnd(GL.QUADS,function()
   gl.Vertex(x1,y1);gl.Vertex(x2,y2);gl.Vertex(x3,y3);gl.Vertex(x4,y4)
  end)
  gl.Color(1,1,1,hovered==i and 1 or 0.8)
  gl.Text(choices[i][2],cx+((inner+outer)/2)*math.cos(angle),cy+((inner+outer)/2)*math.sin(angle),13,"oc")
 end
 gl.Color(1,1,1,1)
 gl.Text("ENEMY",cx,cy+5,18,"oc")
 gl.Text("FACTION",cx,cy-16,15,"oc")
end
function widget:MousePress(x,y,button)
 if not visible then return false end
 if button==1 then
  local i=Hover(x,y)
  if i then Choose(choices[i][1]) end
 end
 return true
end
function widget:KeyPress(key)
 if not visible then return false end
 if key==27 then Choose("RANDOM") end
 return true
end
function widget:TextCommand(command)
 if not tostring(command or ""):match("^%s*enemyfaction%s*$") then return false end
 if not (Spring.IsCheatingEnabled and Spring.IsCheatingEnabled()) then
  Spring.Echo("[MCM Enemy Faction] /enemyfaction requires /cheat")
  return true
 end
 finished=false
 initialWindow=false
 ready=true
 visible=true
 elapsed=0
 return true
end
function widget:IsAbove() return visible end
