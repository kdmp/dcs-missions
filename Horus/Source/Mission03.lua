dofile(baseDir .. "KD/Mission.lua")

---
-- @module Horus.Mission03

--- 
-- @type Mission03
-- @extends KD.Mission#Mission
Mission03 = {
  className = "Mission03",

  traceLevel = 1,
  
  transportMaxCount = 3, -- easy to run out of fuel with >3
  transportSeparation = 300,
  transportMinLife = 30,
  transportSpawnCount = 0,
  transportSpawnStart = 10,
  transportSpawnStarted = false,
  
  migsSpawnerMax = 3,
  migsPerPlayer = 4,
  migsSpawnDoneCount = 0,
  migsDestroyed = 0,
  migsSpawnStarted = false,
  migsGroupSize = 2, -- pairs in ME
  migsPrefix = "MiG",
}

---
-- @param #Mission03 self
function Mission03:Mission03()
  
  self.nalchikParkZone = ZONE:FindByName("Nalchik Park")
  self.transportSpawn = SPAWN:New("Transport")
  
end

---
-- @param #Mission03 self
function Mission03:OnStart()
  
  self:SetupMenu(self.transportSpawn)
  
  MESSAGE:New("Mission 3: Protect inbound transports to Nalchik", self.messageTimeShort):ToAll()
  MESSAGE:New("Read the mission brief before takeoff", self.messageTimeShort):ToAll()
  
end

---
-- @param #Mission03 self
function Mission03:OnGameLoop()

  self:AssertType(self.nalchikParkZone, ZONE)
  self:AssertType(self.transportSpawn, SPAWN)
  
  local playersExist = (#self.players > 0)
  self:Trace(2, "Player count: " .. #self.players)
  self:Trace(2, "Players exist: " .. (playersExist and "true" or "false")) 
  
  local transportsExist = (self.transportSpawnCount > 0)
  self:Trace(2, "Transport count: " .. self.transportSpawnCount)
  self:Trace(2, "Transports exist: " .. (transportsExist and "true" or "false")) 
  
  if (self.state.finalState) then
    return
  end

  -- if no players, then say all players are parked (not sure if this makes sense).
  local playersAreParked = ((not playersExist) or self:UnitsAreParked(self.nalchikParkZone, self.players))
  local transportsAreParked = (transportsExist and self:SpawnGroupsAreParked(self.nalchikParkZone, self.transportSpawn))
  local everyoneParked = (playersAreParked and transportsAreParked)
  
  self:Trace(2, "Transports alive: " .. self:GetAliveUnitsFromSpawn(self.transportSpawn))
  self:Trace(2, (playersAreParked and "✔️ Players: All parked" or "❌ Players: Not all parked"), 1)
  self:Trace(2, (transportsAreParked and "✔️ Transports: All parked" or "❌ Transports: Not all parked"), 1)
  self:Trace(2, (everyoneParked and "✔️ Everyone: All parked" or "❌ Everyone: Not all parked"), 1)
  
  if (everyoneParked) then
    self.state:Change(MissionState.MissionAccomplished)
  end
  
  self:KeepAliveSpawnGroupsIfParked(self.nalchikParkZone, self.transportSpawn)
  self:SelfDestructDamagedUnits(self.transportSpawn, self.transportMinLife)
  
end

---
-- @param #Mission03 self
function Mission03:GetMaxMigs()
  return (self.playerCountMax * self.migsPerPlayer)
end

---
-- @param #Mission03 self
function Mission03:StartSpawnTransport()

  self:Assert(not self.transportSpawnStarted, "Transport spawner already started")
  self.transportSpawnStarted = true
  
  self:Trace(1, "Starting transport spawner")

  self:AddSpawner(self.transportSpawn, self.transportMaxCount)
  
  -- using a manual scheduler because Moose's SpawnScheduled/InitLimit isn't reliable,
  -- as it often spawns 1 less than you ask for. 
  SCHEDULER:New(nil, function()
    if (self.transportSpawnCount < self.transportMaxCount) then
      self.transportSpawn:Spawn()
    end
  end, {}, self.transportSpawnStart, self.transportSeparation)
end

---
-- @param #Mission03 self
-- @param Wrapper.Unit#UNIT unit
function Mission03:OnUnitSpawn(unit)
  
  if (string.match(unit:GetName(), "Transport")) then
    self.transportSpawnCount = self.transportSpawnCount + 1
    self:Trace(1, "New transport spawned, alive: " .. tostring(self.transportSpawnCount))
    
    MESSAGE:New(
      "Transport #".. tostring(self.transportSpawnCount) .." of " .. 
      tostring(self.transportMaxCount) .. " arrived, inbound to Nalchik", self.messageTimeShort
    ):ToAll()
    
    self:PlaySound(Sound.ReinforcementsHaveArrived, 2)
  end
  
  if (string.match(unit:GetName(), "MiG")) then
    self.migsSpawnDoneCount = self.migsSpawnDoneCount + 1
    self:Trace(1, "New enemy spawned, alive: " .. tostring(self.migsSpawnDoneCount))
    MESSAGE:New("Enemy MiG #" .. tostring(self.migsSpawnDoneCount) .. " incoming, inbound to Nalchik", self.messageTimeShort):ToAll()
    self:PlaySound(Sound.EnemyApproching)
  end
end

---
-- @param #Mission03 self
-- @param Wrapper.Unit#UNIT unit
function Mission03:OnPlayerSpawn(unit)
  if not self.transportSpawnStarted then
    self:StartSpawnTransport()
  end
  
  if not self.migsSpawnStarted then    
    self:Assert(not self.migsSpawnStarted, "MiG spawner already started")
    self.migsSpawnStarted = true
    self.migsSpawn = Spawn:_New(self, self.migsSpawnerMax, self.GetMaxMigs, self.migsGroupSize, self.migsPrefix)
    self.migsSpawn:CopyTrace(self)
    self.migsSpawn:StartSpawnEnemies()
  end
end

---
-- @param #Mission03 self
-- @param Core.Spawn#SPAWN transportSpawn
function Mission03:SetupMenu(transportSpawn)
  local menu = MENU_COALITION:New(coalition.side.BLUE, "Debug")
  MENU_COALITION_COMMAND:New(
    coalition.side.BLUE, "Kill transport", menu,
    function() self:SelfDestructGroupsInSpawn(transportSpawn, 100, 1) end)
end

---
-- @param #Mission03 self
-- @param Wrapper.Unit#UNIT unit
function Mission03:OnUnitDead(unit)
  if (string.match(unit:GetName(), "Transport")) then
    self:OnTransportDead(unit)
  end
  if (string.match(unit:GetName(), "MiG")) then
    self:OnEnemyDead(unit)
  end
end

---
-- @param #Mission03 self
-- @param Wrapper.Unit#UNIT unit
function Mission03:OnTransportDead(unit)
  self:AssertType(unit, UNIT)
  self:Trace(1, "Transport destroyed: " .. unit:GetName())
  MESSAGE:New("Transport destroyed!", self.messageTimeLong):ToAll()
  self:PlaySound(Sound.UnitLost)
  
  self.state:Change(MissionState.MissionFailed)
end

---
-- @param #Mission03 self
-- @param Wrapper.Unit#UNIT unit
function Mission03:OnEnemyDead(unit)
  self:AssertType(unit, UNIT)
  self:Trace(1, "Enemy MiG is dead: " .. unit:GetName())
  
  self:PlayEnemyDeadSound()
  
  self.migsDestroyed = self.migsDestroyed + 1
  local remain = self:GetMaxMigs() - self.migsDestroyed
  
  if (self.state.finalState) then
    return
  end
  
  if (remain > 0) then
    self:Trace(1, "MiGs remain: " .. remain)
    MESSAGE:New("Enemy MiG is dead! Remaining: " .. remain, self.messageTimeShort):ToAll()
  else
    self:Trace(1, "All MiGs are dead")
    self:PlaySound(Sound.FirstObjectiveMet, 2)
    MESSAGE:New("All enemy MiGs are dead!", self.messageTimeLong):ToAll()
    MESSAGE:New("Land at Nalchik and park for tasty Nal-chicken dinner! On nom nom", self.messageTimeLong):ToAll()    
    self:LandTestPlayers(self.playerGroup, AIRBASE.Caucasus.Nalchik, 300)
  end
end

Mission03 = createClass(Mission, Mission03)
