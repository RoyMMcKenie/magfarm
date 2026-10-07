--[[==========================================================================
  FILE        : movement.lua
  PACKAGE     : MagFarm (MacroQuest / EverQuest)
  VERSION     : 0.3.6

  WHAT  : Owns MagFarm's explicit manual safety and recovery commands:
          Stop All Movement, Pet Back Off, and Pet Follow.

  WHY   : The first interactive MagFarm controls must improve operator safety
          without creating target selection, combat, navigation, or casting
          automation. Each exported command is user-clicked or user-typed.

  WHERE : Called by ui.tick() after the operator requests an action through
          a MagFarm button or slash command.

  HOW   : Sends cancellation/recovery commands tested with a 112 MAG
          and its summoned pet:
          /travelto stop, /nav stop, /stick off, /pet back off, and /pet follow.

  WHEN  : Only after an explicit operator request. Version 0.3.6 never decides
          to issue these commands automatically.

  SAFETY:
    - Never starts travel, navigation, stick, combat, targeting, or casting.
    - Never issues /pet attack.
    - Pet commands are strictly manual safety/recovery actions.
==========================================================================]]--

local mq = require('mq')
local readiness = require('magfarm.readiness')

local movement = {}

--[[
FUNCTION: sendStop(command)
WHAT: Send one existing movement-cancellation command
WHY: Give each component a protected dispatch so another can still be attempted
WHERE: movement.stopAll through pcall
HOW: Invoke mq.cmd with one fixed, source-defined command
WHEN: Only after an explicit operator stop request and a confirmed dependency
]]
local function sendStop(command)
    mq.cmd(command)
end

--[[--------------------------------------------------------------------------
  movement.stopAll()

  WHAT  : Stops EasyFind travel, MQ2Nav navigation, and MQ2MoveUtils sticking.

  WHY   : A single obvious emergency action should leave the character as still
          as the installed movement tools allow, even if one system handed off
          to another.

  WHERE : Called from ui.tick after a user requests Stop All Movement.

  HOW   : Checks readiness and sends only available stop components in fixed
          order: travel, navigation, then sticking; reports partial dispatch.

  WHEN  : Only when the operator explicitly requests the action.
----------------------------------------------------------------------------]]
function movement.stopAll()
    readiness.refresh()
    local components = {
        {name='MQ2EasyFind', command='/travelto stop'},
        {name='MQ2Nav', command='/nav stop'},
        {name='MQ2MoveUtils', command='/stick off'},
    }
    local sent, skipped, failed = 0, {}, {}
    for _, component in ipairs(components) do
        if readiness.isLoaded(component.name) then
            local ok = pcall(sendStop, component.command)
            if ok then sent = sent + 1 else table.insert(failed, component.name) end
        else
            table.insert(skipped, component.name)
        end
    end
    local message = string.format('Stop request: %d/3 commands dispatched.', sent)
    if #skipped > 0 then message = message .. ' Skipped (missing/unknown): ' .. table.concat(skipped, ', ') .. '.' end
    if #failed > 0 then message = message .. ' Dispatch failed: ' .. table.concat(failed, ', ') .. '.' end
    mq.cmd('/echo [MagFarm] ' .. message)
    return message
end

--[[--------------------------------------------------------------------------
  movement.petBackOff()

  WHAT  : Tells the current pet to stop attacking its active target.

  WHY   : Gives the operator a fast recovery control when the pet has been sent
          to a target manually or was drawn into an encounter.

  WHERE : Called from ui.tick after the operator clicks Pet Back Off.

  HOW   : Issues the live-verified /pet back off command.

  WHEN  : Only after an explicit operator request. MagFarm never sends this
          command automatically in version 0.3.6.
----------------------------------------------------------------------------]]
function movement.petBackOff()
    mq.cmd('/pet back off')
    mq.cmd('/echo [MagFarm] Pet Back Off requested.')
end

--[[--------------------------------------------------------------------------
  movement.petFollow()

  WHAT  : Tells the current pet to follow its owner.

  WHY   : Lets the operator restore normal pet positioning after backing off,
          manual movement, or a completed encounter.

  WHERE : Called from ui.tick after the operator clicks Pet Follow.

  HOW   : Issues the live-verified /pet follow command.

  WHEN  : Only after an explicit operator request. MagFarm never sends this
          command automatically in version 0.3.6.
----------------------------------------------------------------------------]]
function movement.petFollow()
    mq.cmd('/pet follow')
    mq.cmd('/echo [MagFarm] Pet Follow requested.')
end

return movement

--[[==========================================================================
  FOOTER : movement.lua

  EXPORTS
    stopAll()      Best-effort cancellation for confirmed available components.
                   Returns dispatch summary; not proof all movement stopped.
    petBackOff()   Tell the current pet to stop attacking.
    petFollow()    Tell the current pet to follow its owner.

  VERIFIED COMMANDS
    /travelto stop
    /nav stop
    /stick off
    /pet back off
    /pet follow

  READINESS
    Missing/unknown components are skipped; available commands are attempted.
    Native follow, other automation and unlisted movement systems are not covered.

  SAFETY
    This module never starts travel, navigation, stick, combat, pet attack,
    targeting, casting, loot, or inventory actions.
==========================================================================]]--
