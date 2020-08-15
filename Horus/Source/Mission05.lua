dofile(baseDir .. "KD/Mission.lua")

---
-- @module Horus.Mission05

--- 
-- @type Mission05
-- @extends KD.Mission#Mission
Mission05 = {
  className = "Mission05",

  traceLevel = 2
}

---
-- @param #Mission05 self
function Mission05:Mission05()

  self:LoadPlayer()
  
  self.state:ActionOnce(
    Mission.State.MissionFailed,
    function() self:AnnounceLose(2) end
  )
  
  self.state:SetFinal(Mission.State.MissionAccomplished)
  self.state:SetFinal(Mission.State.MissionFailed)
  
  self:SetupMenu()
  
end

---
-- @param #Mission05 self
function Mission05:SetupMenu()

  local menu = MENU_COALITION:New(coalition.side.BLUE, "Debug")
  
  MENU_COALITION_COMMAND:New(
    coalition.side.BLUE, "Kill players", menu,
    function() self:SelfDestructGroup(self.playerGroup, 100, 1, 1) end)
    
end
---
-- @param #Mission05 self
function Mission05:OnStart()
  
  self:MessageAll(MessageLength.Long, "Mission 5: Sneak-attack on Beslan")
  self:MessageAll(MessageLength.Long, "Read the mission brief before takeoff")
  
end

---
-- @param #Mission05 self
function Mission05:OnGameLoop()
  
end

Mission05 = createClass(Mission05, Mission)
