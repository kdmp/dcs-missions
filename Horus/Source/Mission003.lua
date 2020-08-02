---
-- @module Mission

--- @type Mission
Mission = {
  m_playerGroup = nil
}

local _gameLoopInterval = 1
local _playerOnline = false
local _winLoseDone = false
local _soundCounter = 1
local _playerGroup = "Dodge"
local _messageTimeShort = 10
local _messageTimeLong = 100

local _transportMaxCount = 3 -- easy to run out of fuel with >3
local _transportSeparation = 300
local _transportVariation = .5
local _transportMinLife = 30
local _transportSpawnCount = 0
local _transportSpawnStart = 10

local _migsSpawnStart = 60
local _migsSpawnerMax = 3 -- 3 airfields
local _migsPerSpawner = 2 -- 2 per airfield = 6
local _migsSpawnSeparation = 700
local _migsSpawnVariation = .5
local _migsSpawnCount = 0
local _migsDestroyed = 0

---
-- @param #Mission self
function Mission:Setup()
  Global:Trace(1, "Setup begin")
  
  --BASE:TraceOnOff(true)
  BASE:TraceAll(true)
  BASE:TraceLevel(3)
  
  Global:SetTraceOn(true)
  Global:SetTraceLevel(3)
  Global:SetAssert(true)
  
  local nalchikParkZone = ZONE:FindByName("Nalchik Park")
  
  local transportSpawn = SPAWN:New("Transport")
  Global:AddSpawner(transportSpawn, _transportMaxCount)
  Mission:SpawnTransport(transportSpawn)
  
  local playerGroup = GROUP:FindByName(_playerGroup)
  self.m_playerGroup = playerGroup
  Global:AddGroup(playerGroup)
  
  Mission:SetupMenu(transportSpawn)
  Mission:SetupEvents()
  Mission:SpawnEnemies()
  
  SCHEDULER:New(nil,
    function() Mission:GameLoop(nalchikParkZone, transportSpawn, playerGroup) end, 
    {}, 0, _gameLoopInterval)
  
  Global:PlaySound(Sound.MissionLoaded)
  
  MESSAGE:New("Welcome to Mission 3", _messageTimeShort):ToAll()
  MESSAGE:New("Please read the brief", _messageTimeShort):ToAll()
  Global:Trace(1, "Setup done")
  
end

---
-- @param #Mission self
function Mission:PlayEnemyDeadSound(delay)
  if not delay then
    delay = 0
  end
  
  local sounds = {
    Sound.ForKingAndCountry,
    Sound.KissItByeBye,
    Sound.ShakeItBaby
  }
  
  Global:PlaySound(Sound.TargetDestoyed, delay)
  Global:PlaySound(sounds[_soundCounter], delay + 2)
  
  _soundCounter = _inc(_soundCounter)
  if _soundCounter > #sounds then
    _soundCounter = 1
  end
end

---
-- @param #Mission self
function Mission:SpawnEnemies()
  Global:Trace(2, "Spawning enemy MiGs")
  
  for i = 1, _migsSpawnerMax do
  
    local spawn = SPAWN:New("MiG " .. i)
    Global:AddSpawner(spawn, _migsPerSpawner)
    
    -- using a manual scheduler because Moose's SpawnScheduled/InitLimit isn't reliable,
    -- as it often spawns 1 less than you ask for.
    SCHEDULER:New(nil, function()
      local migsMaxCount = _migsSpawnerMax * _migsPerSpawner
      if (_migsSpawnCount < migsMaxCount) then
        spawn:Spawn()
      end
    end, {}, _migsSpawnStart, _migsSpawnSeparation, _migsSpawnVariation)
    
  end
end

---
-- @param #Mission self
-- @param Core.Spawn#SPAWN transportSpawn
function Mission:SpawnTransport(transportSpawn)

  -- using a manual scheduler because Moose's SpawnScheduled/InitLimit isn't reliable,
  -- as it often spawns 1 less than you ask for. 
  SCHEDULER:New(nil, function()
    if (_transportSpawnCount < _transportMaxCount) then
      transportSpawn:Spawn()
    end
  end, {}, _transportSpawnStart, _transportSeparation)
end

---
-- @param #Mission self
function Mission:SetupEvents()
  Global:HandleEvent(Event.Spawn, function(unit) Mission:OnUnitSpawn(unit) end)
  Global:HandleEvent(Event.Damaged, function(unit) Mission:OnUnitDamaged(unit) end)
  Global:HandleEvent(Event.Dead, function(unit) Mission:OnUnitDead(unit) end)
end

-- TODO: implement own birth event, pretty sure this is unreliable
---
-- @param #Mission self
-- @param Wrapper.Unit#UNIT unit
function Mission:OnUnitSpawn(unit)

  Global:CheckType(unit, UNIT)
  Global:Trace(2, "Unit spawned: " .. unit:GetName())
  
  if (string.match(unit:GetName(), "Transport")) then
    _transportSpawnCount = _inc(_transportSpawnCount)
    Global:Trace(1, "New transport spawned, alive: " .. tostring(_transportSpawnCount))
    
    MESSAGE:New(
      "Transport #".. tostring(_transportSpawnCount) .." of " .. 
      tostring(_transportMaxCount) .. " arrived, inbound to Nalchik", _messageTimeShort
    ):ToAll()
    
    Global:PlaySound(Sound.ReinforcementsHaveArrived, 2)
  end
  
  if (string.match(unit:GetName(), "MiG")) then
    _migsSpawnCount = _inc(_migsSpawnCount)
    Global:Trace(1, "New enemy spawned, alive: " .. tostring(_migsSpawnCount))
    MESSAGE:New("Enemy MiG #" .. tostring(_migsSpawnCount) .. " incoming, inbound to Nalchik", _messageTimeShort):ToAll()
    Global:PlaySound(Sound.EnemyApproching)
  end
end


---
-- @param #Mission self
-- @param Core.Spawn#SPAWN transportSpawn
function Mission:SetupMenu(transportSpawn)
  local menu = MENU_COALITION:New(coalition.side.BLUE, "Debug")
  MENU_COALITION_COMMAND:New(
    coalition.side.BLUE, "Kill transport", menu,
    function() Mission:KillTransport(transportSpawn) end)
end

---
-- @param #Mission self
-- @param Wrapper.Unit#UNIT unit
function Mission:OnUnitDead(unit)
  if (string.match(unit:GetName(), _playerGroup)) then
    Mission:OnPlayerDead(unit)
  end
  if (string.match(unit:GetName(), "Transport")) then
    Mission:OnTransportDead(unit)
  end
  if (string.match(unit:GetName(), "MiG")) then
    Mission:OnEnemyDead(unit)
  end
end

---
-- @param #Mission self
-- @param Wrapper.Unit#UNIT unit
function Mission:OnTransportDead(unit)
  Global:CheckType(unit, UNIT)
  Global:Trace(1, "Transport destroyed: " .. unit:GetName())
  MESSAGE:New("Transport destroyed!", _messageTimeShort):ToAll()
  Global:PlaySound(Sound.UnitLost)
  
  if (not _winLoseDone) then
    Mission:AnnounceLose(2)
  end
end

---
-- @param #Mission self
-- @param Wrapper.Unit#UNIT unit
function Mission:OnPlayerDead(unit)
  Global:CheckType(unit, UNIT)
  Global:Trace(1, "Player is dead: " .. unit:GetName())
  MESSAGE:New("Player is dead!", _messageTimeShort):ToAll()
  Global:PlaySound(Sound.UnitLost)
  
  if (not _winLoseDone) then
    Mission:AnnounceLose(2)
  end
end

---
-- @param #Mission self
-- @param Wrapper.Unit#UNIT unit
function Mission:OnEnemyDead(unit)
  Global:CheckType(unit, UNIT)
  Global:Trace(1, "Enemy MiG is dead: " .. unit:GetName())
  
  Mission:PlayEnemyDeadSound()
  
  _migsDestroyed = _inc(_migsDestroyed)
  local remain = (_migsSpawnerMax * _migsPerSpawner) - _migsDestroyed
  
  if (remain > 0) then
    MESSAGE:New("Enemy MiG is dead! Remaining: " .. remain, _messageTimeShort):ToAll()
  else
    Global:PlaySound(Sound.FirstObjectiveMet, 2)
    MESSAGE:New("All enemy MiGs are dead!", _messageTimeShort):ToAll()
    MESSAGE:New("Land at Nalchik and park for tasty Nal-chicken dinner! On nom nom", _messageTimeLong):ToAll()    
    Mission:LandTestPlayers(self.m_playerGroup)
  end
end

---
-- @param #Mission self
function Mission:AnnounceWin(soundDelay)
  if not soundDelay then
    soundDelay = 0
  end
  
  Global:Trace(1, "Mission accomplished")
  MESSAGE:New("Mission accomplished!", _messageTimeLong):ToAll()
  Global:PlaySound(Sound.MissionAccomplished, soundDelay)
  Global:PlaySound(Sound.BattleControlTerminated, soundDelay + 2)
  _winLoseDone = true
end

---
-- @param #Mission self
function Mission:AnnounceLose(soundDelay)
  if not soundDelay then
    soundDelay = 0
  end
  
  Global:Trace(1, "Mission failed")
  MESSAGE:New("Mission failed!", _messageTimeLong):ToAll()
  Global:PlaySound(Sound.MissionFailed, soundDelay)
  Global:PlaySound(Sound.BattleControlTerminated, soundDelay + 2)
  _winLoseDone = true
end

---
-- @param #Mission self
-- @param Wrapper.Group#GROUP playerGroup
function Mission:LandTestPlayers(playerGroup)
  Global:Trace(1, "Landing test players")
  local airbase = AIRBASE:FindByName(AIRBASE.Caucasus.Nalchik)
  local land = airbase:GetCoordinate():WaypointAirLanding(300, airbase)
  local route = { land }
  playerGroup:Route(route)
end

---
-- @param #Mission self
-- @param Core.Spawn#SPAWN transportSpawn
function Mission:KillTransport(transportSpawn)
  Global:Trace(1, "Killing transport")
  local group = transportSpawn:GetGroupFromIndex(1)
  if group then
    unit = group:GetUnit(1)
    unit:Explode(100, 0)
    unit.selfDestructDone = true
  end
end

-- TODO: refactor into global class
---
-- @param #Mission self
-- @param Core.Spawn#SPAWN transportSpawn
function Mission:CheckTransportDamage(transportSpawn)
  Global:Trace(3, "Checking transport spawn groups for damage")
  for i = 1, _transportMaxCount do
    local group = transportSpawn:GetGroupFromIndex(i)
    if group then
      Global:Trace(3, "Checking group for damage: " .. group:GetName())
      
      local units = group:GetUnits()
      if units then
        for j = 1, #units do
          local unit = group:GetUnit(j)
          local life = unit:GetLife()
          
          Global:Trace(3, "Checking unit for damage: " .. unit:GetName() .. ", health " .. tostring(life))
          
          -- only kill the unit if it's alive, otherwise it'll never crash.
          -- explode transports below a certain live level, otherwise
          -- transports can land in a damaged and prevent other transports
          -- from landing
          if (unit:IsAlive() and (not unit.selfDestructDone) and (unit:GetLife() < _transportMinLife)) then
            Global:Trace(1, "Auto-kill " .. unit:GetName() .. ", health " .. tostring(life) .. "<" .. _transportMinLife)
            unit:Explode(100, 1)
            unit.selfDestructDone = true
          end
        end
      end
    end
  end
end

-- TODO: consider merging this with CheckTransportDamage
---
-- @param #Mission self
-- @param Core.Spawn#SPAWN transportSpawn
function Mission:GetAliveTransportCount(transportSpawn)
  Global:Trace(3, "Checking spawn groups for alive count")
  
  local count = 0
  for i = 1, _transportMaxCount do
    local group = transportSpawn:GetGroupFromIndex(i)
    if group then
      Global:Trace(3, "Checking group for alive count: " .. group:GetName())
      
      local units = group:GetUnits()
      if units then
        for j = 1, #units do
          local unit = group:GetUnit(j)
          Global:Trace(3, "Checking if unit is alive: " .. unit:GetName())
          
          if unit:IsAlive() then
            count = _inc(count)
          end
        end
      end
    end
  end
  return count
end

---
-- @param #Mission self
-- @param Core.Zone#ZONE nalchikParkZone
-- @param Core.Spawn#SPAWN transportSpawn
-- @param Wrapper.Group#GROUP playerGroup
function Mission:GameLoop(nalchikParkZone, transportSpawn, playerGroup)
  Global:CheckType(nalchikParkZone, ZONE)
  Global:CheckType(transportSpawn, SPAWN)
  
  Global:GameLoop()
  
  if (_winLoseDone) then
    return
  end

  -- if no players, then say all players are parked (not sure if this makes sense).
  local playersAreParked = ((not playerGroup) or Global:GroupIsParked(nalchikParkZone, playerGroup))
  local transportsAreParked = Global:SpawnGroupsAreParked(nalchikParkZone, transportSpawn, _transportMaxCount)
  local everyoneParked = (playersAreParked and transportsAreParked)
  
  Global:Trace(2, "Transports alive: " .. Mission:GetAliveTransportCount(transportSpawn))
  Global:Trace(2, (playersAreParked and "✔️ Players: All parked" or "❌ Players: Not all parked"), 1)
  Global:Trace(2, (transportsAreParked and "✔️ Transports: All parked" or "❌ Transports: Not all parked"), 1)
  Global:Trace(2, (everyoneParked and "✔️ Everyone: All parked" or "❌ Everyone: Not all parked"), 1)
  
  if (everyoneParked) then
    Mission:AnnounceWin()
  end
  
  -- no player group happens when no players are online yet
  if (playerGroup) then
  
    if (Global:GroupHasPlayer(playerGroup) and not _playerOnline) then
      Global:Trace(1, "Player is now online (in player group)")
      _playerOnline = true
    end
    
    -- keep alive only needed for AI player group (which is useful for testing).
    if (transportsAreParked and (not _playerOnline)) then
      Global:KeepAliveGroupIfParked(nalchikParkZone, playerGroup)
    end
    
  end
  
  Global:KeepAliveSpawnGroupsIfParked(nalchikParkZone, transportSpawn, _transportMaxCount)
  Mission:CheckTransportDamage(transportSpawn)
  
end

Mission:Setup()
