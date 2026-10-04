--[[==========================================================================
  FILE        : magfarm/follow.lua
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial read-only follow-leader validation foundation.

  WHAT  : Validates a configured group follow leader and reports desired follow
          status without sending movement commands in version 0.1.
  WHY   : Follow should be observable and safe before MQ2Nav command paths are
          enabled in a live client test.
  WHERE : Required by state.lua and ui.lua.
  HOW   : Looks for configured clean name in group member slots and reports
          presence/distance when the TLO exposes them.
  WHEN  : Refreshed during FOLLOW state and UI display.
==========================================================================]]--

local mq = require('mq') -- Group-member TLO access.
local config = require('magfarm.config') -- Follow leader/distance settings.
local follow = {} -- Module export table.

-- WHAT : Cached follow validation descriptor.
-- WHY  : Avoids duplicate roster scans and gives UI one clear explanation.
-- WHERE: Set by follow.refresh and read by ui/state.
-- HOW  : Plain table.
-- WHEN  : Rebuilt during follow/status refresh.
follow.status = { valid = false, name = '', distance = -1, reason = 'No follow leader configured' } -- Safe default.

--[[--------------------------------------------------------------------------
  follow.refresh()

  WHAT  : Resolves the configured follow leader against the current group roster.
  WHY   : A follow mode must fail visibly when a leader is absent or not grouped.
  WHERE : Called by state.follow and ui.lua.
  HOW   : Searches Group.Member 1..5 by clean name, then records presence/range.
  WHEN  : During FOLLOW mode and status display.
----------------------------------------------------------------------------]]
function follow.refresh()
    local wanted = config.settings.followLeader or '' -- Read configured clean name.
    if wanted == '' then -- Empty selection cannot be followed.
        follow.status = { valid = false, name = '', distance = -1, reason = 'No follow leader configured' } -- Explain configuration gap.
        return follow.status -- Stop safely.
    end
    for index = 1, 5 do -- Search live group member slots.
        local member = mq.TLO.Group.Member(index) -- Get candidate handle.
        if member and (member.ID() or 0) > 0 and (member.CleanName() or ''):lower() == wanted:lower() then -- Match a real grouped member.
            local present = member.Present() ~= false -- Treat nil as unknown/optimistically present for display.
            follow.status = { valid = present, name = member.CleanName() or wanted, distance = member.Distance() or -1, reason = present and 'Follow preview active; movement commands not enabled in 0.1.' or 'Follow leader is not present in this zone.' } -- Publish status.
            return follow.status -- Leader found.
        end
    end
    follow.status = { valid = false, name = wanted, distance = -1, reason = 'Configured follow leader is not a current group member.' } -- Explain roster mismatch.
    return follow.status -- Return failed resolution.
end

return follow -- Export follow status service.

--[[==========================================================================
  END OF FILE : magfarm/follow.lua

  EXPORTS
    status        Latest follow-leader descriptor.
    refresh()     Validate configured leader against group roster.

  DEPENDENCIES : mq, magfarm.config.

  HOW TO EDIT SAFELY
    - Add MQ2Nav movement only after validating the desired command syntax.
    - Preserve desired/repath hysteresis from config when active follow is added.
==========================================================================]]--
