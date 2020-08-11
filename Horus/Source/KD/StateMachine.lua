dofile(baseDir .. "KD/Events.lua")

---
-- @module KD.StateMachine

--- 
-- @type StateMachine
-- @extends KD.Events#Events
StateMachine = {
  className = "StateMachine",
  
  current = nil
}

--- 
-- @type State
-- @extends KD.Event#Event
State = { }

---
-- @function [parent=#StateMachine] New
-- @param #StateMachine self
-- @return #StateMachine

---
-- @param #StateMachine self
function StateMachine:StateMachine()

  --- @field #table<#State, #boolean> onceStates
  self.onceStates = {}
  
  --- @field #table<#State, #function> triggers
  self.triggers = {}
  
end

--- Register a trigger which changes the state and fires an action.
-- @param #StateMachine self
function StateMachine:TriggerOnce(state, trigger, action)
  self:Assert(state, "Arg `state` was nil")
  self:Assert(trigger, "Arg `trigger` was nil")
  self:Assert(action, "Arg `action` was nil")
  
  self.onceStates[state] = false
  self.triggers[state] = trigger
  self:HandleEvent(state, action)
  
end

--- Register an action that happens the first time `Change` is called.
-- @param #StateMachine self
function StateMachine:ActionOnce(state, action)
  self:Assert(state, "Arg `state` was nil")
  self:Assert(action, "Arg `action` was nil")
  
  self.onceStates[state] = false
  self:HandleEvent(state, action)
end

--- Changes the state to change which fires the registered action.
-- @param #StateMachine self
-- @param #State state
function StateMachine:Change(state)
  self:Assert(state, "Arg `state` was nil")
  
  if (self.onceStates[state] ~= nil) then
    if (self.onceStates[state] == false) then
      self.current = state
      self:FireEvent(state)
      self.onceStates[state] = true
      return true
    else
      self:Trace(3, "Once state already called, state=" .. state)
    end
  end
  
  return false
end

function StateMachine:CheckTriggers()

  for state, trigger in pairs(self.triggers) do
    
    -- check trigger only up until we need to change to the state 
    if ((self.onceStates[state] ~= nil) and (self.onceStates[state] == false)) then
    
      if (trigger()) then
        local changed = self:Change(state)
        if not changed then
          self:Trace(3, "Change could not be triggered, state=" .. state)
        end
      end
      
    end
    
  end
  
end

StateMachine = createClass(Events, StateMachine)
