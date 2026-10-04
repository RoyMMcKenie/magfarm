--[[==========================================================================
  FILE        : magfarm/pet.lua
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial read-only pet status and policy foundation.

  WHAT  : Reports pet presence, health, and the desired future taunt policy.
  WHY   : Pet commands are client/server sensitive; status and policy are built
          first so later command control has one documented decision source.
  WHERE : Required by state.lua and ui.lua.
  HOW   : Reads Me.Pet and combines solo/group role policy into a descriptor.
  WHEN  : Refreshed on state/UI status updates.
==========================================================================]]--

local mq = require('mq') -- Character and pet TLO access.
local config = require('magfarm.config') -- Pet policy settings.
local runtime = require('magfarm.runtime') -- Current mode and state.
local assist = require('magfarm.assist') -- Group ownership status.
local pet = {} -- Module export table.

-- WHAT : Cached pet descriptor.
-- WHY  : UI needs pet facts without duplicating TLO reads across modules.
-- WHERE: Set by pet.refresh and read by UI.
-- HOW  : Plain table.
-- WHEN  : Refreshed on status ticks.
pet.status = { exists = false, name = '', hp = 0, desiredTaunt = nil, reason = 'No pet' } -- Safe absence default.

--[[--------------------------------------------------------------------------
  pet.refresh()

  WHAT  : Reads pet facts and determines desired role-based taunt policy.
  WHY   : Separates policy calculation from future pet command issuance.
  WHERE : Called by state.tick and ui.lua.
  HOW   : Detects pet ID/name/HP, then applies solo/group policy conservatively.
  WHEN  : At state/status refresh intervals.
----------------------------------------------------------------------------]]
function pet.refresh()
    local petTLO = mq.TLO.Me.Pet -- Obtain pet handle once per refresh.
    local exists = (petTLO.ID() or 0) > 0 -- Valid ID indicates a current summoned pet.
    if not exists then -- No summoned pet needs no taunt decision.
        pet.status = { exists = false, name = '', hp = 0, desiredTaunt = nil, reason = 'No pet summoned' } -- Publish absence.
        return pet.status -- Stop safely.
    end
    local desired = nil -- nil means policy management disabled.
    local reason = 'Automatic taunt management disabled' -- Default explanation.
    if config.settings.managePetTaunt then -- Only calculate when the operator allows management.
        if not assist.status.grouped and config.settings.tauntWhenSolo then desired, reason = true, 'Solo policy' -- Solo pet normally tanks.
        elseif assist.status.grouped and assist.status.valid and config.settings.tauntWhenMainAssist then desired, reason = true, 'Magician Main Assist policy' -- Future verified MA may allow this path.
        else desired, reason = false, 'Grouped assist policy' end -- Never compete with another group tank/assist.
    end
    pet.status = { exists = true, name = petTLO.CleanName() or petTLO.Name() or 'Pet', hp = petTLO.PctHPs() or 0, desiredTaunt = desired, reason = reason, state = runtime.state } -- Publish current facts/policy.
    return pet.status -- Let callers render result.
end

return pet -- Export pet status service.

--[[==========================================================================
  END OF FILE : magfarm/pet.lua

  EXPORTS
    status        Latest pet descriptor.
    refresh()     Read pet facts and desired taunt policy.

  DEPENDENCIES : mq, magfarm.config, magfarm.runtime, magfarm.assist.

  HOW TO EDIT SAFELY
    - Do not add `/pet` commands until each command path is tested in-game.
    - Later camp-pull and emergency rules should calculate desired state here,
      then issue commands through one documented adapter function.
==========================================================================]]--
