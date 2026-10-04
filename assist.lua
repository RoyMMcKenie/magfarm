--[[==========================================================================
  FILE        : magfarm/assist.lua
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial group/Main Assist status foundation.

  WHAT  : Reports group status and provides a conservative Main Assist warning
          foundation without guessing a Main Assist from leader or class.
  WHY   : Group target ownership is a safety boundary; unverified API guesses
          must never cause offensive behavior.
  WHERE : Required by state.lua and ui.lua.
  HOW   : Detects group membership through Group.Member and exposes a clear
          unresolved warning until the exact Main Assist TLO path is verified.
  WHEN  : Refreshed during state ticks and status display.
==========================================================================]]--

local mq = require('mq') -- Group TLO access.
local config = require('magfarm.config') -- Group-assist policy settings.
local runtime = require('magfarm.runtime') -- Status/log storage.
local utils = require('magfarm.utils') -- Debug output.
local assist = {} -- Module export table.

-- WHAT : Cached Main Assist/group status descriptor.
-- WHY  : UI needs one stable explainable status object.
-- WHERE: Set by assist.refresh and read by ui/state.
-- HOW  : Plain table with grouped, valid, name, and warning fields.
-- WHEN  : Rebuilt periodically/on demand.
assist.status = { grouped = false, valid = true, name = '', warning = '' } -- Safe solo default.

--[[--------------------------------------------------------------------------
  assist.memberCount()

  WHAT  : Counts populated non-self group-member slots.
  WHY   : A group policy should only apply when another member actually exists.
  WHERE : Called by assist.refresh.
  HOW   : Inspects Group.Member indices 1 through 5 for valid IDs.
  WHEN  : Each assist-status refresh.
----------------------------------------------------------------------------]]
function assist.memberCount()
    local count = 0 -- Start empty.
    for index = 1, 5 do -- MacroQuest group slots other than self/leader semantics vary; valid IDs are authoritative here.
        local member = mq.TLO.Group.Member(index) -- Obtain live slot handle.
        if member and (member.ID() or 0) > 0 then count = count + 1 end -- Count actual populated members only.
    end
    return count -- Return partner count.
end

--[[--------------------------------------------------------------------------
  assist.refresh()

  WHAT  : Rebuilds conservative group/Main Assist status.
  WHY   : Version 0.1 must warn safely rather than guess an unsupported MA API.
  WHERE : Called by state.tick, state.prepare, and ui status rendering.
  HOW   : Detects grouping; solo is valid, grouped requires verified MA support
          before offense can ever be enabled in a later milestone.
  WHEN  : At startup and throttled state/UI refreshes.
----------------------------------------------------------------------------]]
function assist.refresh()
    local grouped = assist.memberCount() > 0 -- A populated member means group behavior applies.
    if not grouped then -- Solo needs no Main Assist.
        assist.status = { grouped = false, valid = true, name = '', warning = '' } -- Publish safe solo status.
        return assist.status -- Return immediately.
    end
    local warning = 'Main Assist verification is pending client API validation; group offense remains disabled.' -- Conservative foundation warning.
    assist.status = { grouped = true, valid = false, name = '', warning = warning } -- Never guess leader/tank as MA.
    if config.settings.useGroupAssist and config.settings.requireMainAssist then runtime.status = warning end -- Surface the important lockout.
    utils.debug('Grouped without verified Main Assist accessor; offense remains locked.') -- Explain intentional behavior in Debug.
    return assist.status -- Let caller render current condition.
end

--[[--------------------------------------------------------------------------
  assist.canOffend()

  WHAT  : Returns whether group offensive behavior would be permitted.
  WHY   : Makes the safety boundary explicit for future combat modules.
  WHERE : Future combat/pet/merc modules will call it before hostile actions.
  HOW   : Solo returns true; grouped requires a verified valid Main Assist when
          Main Assist policy is enabled.
  WHEN  : Any time offensive action is considered.
----------------------------------------------------------------------------]]
function assist.canOffend()
    if not assist.status.grouped then return true end -- Solo is not governed by group MA ownership.
    if not config.settings.useGroupAssist then return false end -- 0.1 remains conservative without explicit later policy.
    return assist.status.valid == true -- Future verified accessor will control this result.
end

return assist -- Export group-assist status services.

--[[==========================================================================
  END OF FILE : magfarm/assist.lua

  EXPORTS
    status            Latest grouped/Main Assist status descriptor.
    memberCount()     Count populated group-member slots.
    refresh()         Rebuild conservative group status.
    canOffend()       Group-offense permission gate.

  DEPENDENCIES : mq, magfarm.config, magfarm.runtime, magfarm.utils.

  HOW TO EDIT SAFELY
    - Do not infer Main Assist from group leader, class, or follow leader.
    - Replace the temporary warning only after testing the exact supported
      Main Assist accessor on the operator's MacroQuest build.
==========================================================================]]--
