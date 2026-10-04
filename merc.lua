--[[==========================================================================
  FILE        : magfarm/merc.lua
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial read-only mercenary status foundation.

  WHAT  : Detects the local mercenary and publishes a future pull-discipline
          policy explanation without issuing unverified mercenary commands.
  WHY   : Damage/healer mercs must not engage ordinary pulls before camp, but
          client command/stance paths must be verified before automation.
  WHERE : Required by state.lua and ui.lua.
  HOW   : Reads Me.Mercenary fields when available and maps package state to a
          desired future behavior.
  WHEN  : Refreshed with status updates.
==========================================================================]]--

local mq = require('mq') -- Mercenary TLO access.
local config = require('magfarm.config') -- Mercenary settings.
local runtime = require('magfarm.runtime') -- Current package state.
local merc = {} -- Module export table.

-- WHAT : Cached mercenary descriptor.
-- WHY  : UI needs clear facts and intended policy without command side effects.
-- WHERE: Set by merc.refresh and read by ui.lua.
-- HOW  : Plain table with existence/type/name/policy fields.
-- WHEN  : Rebuilt during status refresh.
merc.status = { exists = false, name = '', class = '', policy = 'No mercenary' } -- Safe default.

--[[--------------------------------------------------------------------------
  merc.refresh()

  WHAT  : Detects current mercenary facts and desired future policy.
  WHY   : Separates reliable observation from unverified active stance control.
  WHERE : Called by state.tick and ui.lua.
  HOW   : Reads Me.Mercenary fields defensively, then labels normal pull policy.
  WHEN  : At status refresh intervals.
----------------------------------------------------------------------------]]
function merc.refresh()
    local mercTLO = mq.TLO.Me.Mercenary -- Obtain current mercenary handle.
    local exists = (mercTLO.ID() or 0) > 0 -- A live mercenary reports a valid ID.
    if not exists then -- No mercenary has no policy work.
        merc.status = { exists = false, name = '', class = '', policy = 'No mercenary active' } -- Publish absence.
        return merc.status -- Stop safely.
    end
    local policy = 'Observed only; merc command path not yet verified' -- Version 0.1 never issues merc commands.
    if config.settings.manageMercenary and runtime.state == runtime.STATE.CAMP_IDLE then policy = 'Future camp policy: hold during pull return, release at camp or emergency' end -- Explain intended future behavior.
    merc.status = { exists = true, name = mercTLO.CleanName() or mercTLO.Name() or 'Mercenary', class = mercTLO.Class.ShortName() or mercTLO.Class.Name() or '', hp = mercTLO.PctHPs() or 0, policy = policy } -- Publish facts.
    return merc.status -- Return fresh descriptor.
end

return merc -- Export mercenary status service.

--[[==========================================================================
  END OF FILE : magfarm/merc.lua

  EXPORTS
    status        Latest mercenary descriptor.
    refresh()     Read mercenary facts and intended policy.

  DEPENDENCIES : mq, magfarm.config, magfarm.runtime.

  HOW TO EDIT SAFELY
    - Verify exact stance/passive/assist commands on the target client first.
    - Keep damage/healer pull discipline in this module, not scattered in state.
==========================================================================]]--
