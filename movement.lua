--[[==========================================================================
  FILE        : magfarm/movement.lua
  PACKAGE     : MagFarm (MacroQuest / EverQuest)
  VERSION     : 0.2.0

  WHAT  : Owns MagFarm's explicit manual safety and recovery commands:
          Stop All Movement, Pet Back Off, and Pet Follow.

  WHY   : The first interactive MagFarm controls must improve operator safety
          without creating target selection, combat, navigation, or casting
          automation. Each exported command is user-clicked or user-typed.

  WHERE : Called by ui.tick() after the operator requests an action through
          a MagFarm button or slash command.

  HOW   : Sends only commands verified live on 112 MAG and summoned pet:
          /travelto stop, /nav stop, /stick off, /pet back off, and /pet follow.

  WHEN  : Only after an explicit operator request. Version 0.2.0 never decides
          to issue these commands automatically.

  SAFETY:
    - Never starts travel, navigation, stick, combat, targeting, or casting.
    - Never issues /pet attack.
    - Pet commands are strictly manual safety/recovery actions.
==========================================================================]]--

local mq = require('mq')

local movement = {}

--[[--------------------------------------------------------------------------
  movement.stopAll()

  WHAT  : Stops EasyFind travel, MQ2Nav navigation, and MQ2MoveUtils sticking.

  WHY   : A single obvious emergency action should leave the character as still
          as the installed movement tools allow, even if one system handed off
          to another.

  WHERE : Called from ui.tick after a user requests Stop All Movement.

  HOW   : Sends the three independently verified stop commands in a fixed
          defensive order: travel, navigation, then sticking.

  WHEN  : Only when the operator explicitly requests the action.
----------------------------------------------------------------------------]]
function movement.stopAll()
    mq.cmd('/travelto stop')
    mq.cmd('/nav stop')
    mq.cmd('/stick off')

    mq.cmd('/echo [MagFarm] Stop All Movement requested: travel, nav, stick.')
end

--[[--------------------------------------------------------------------------
  movement.petBackOff()

  WHAT  : Tells the current pet to stop attacking its active target.

  WHY   : Gives the operator a fast recovery control when the pet has been sent
          to a target manually or was drawn into an encounter.

  WHERE : Called from ui.tick after the operator clicks Pet Back Off.

  HOW   : Issues the live-verified /pet back off command.

  WHEN  : Only after an explicit operator request. MagFarm never sends this
          command automatically in version 0.2.0.
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
          command automatically in version 0.2.0.
----------------------------------------------------------------------------]]
function movement.petFollow()
    mq.cmd('/pet follow')
    mq.cmd('/echo [MagFarm] Pet Follow requested.')
end

return movement

--[[==========================================================================
  FOOTER : magfarm/movement.lua

  EXPORTS
    stopAll()      Stop EasyFind, MQ2Nav, and MQ2MoveUtils movement.
    petBackOff()   Tell the current pet to stop attacking.
    petFollow()    Tell the current pet to follow its owner.

  VERIFIED COMMANDS
    /travelto stop
    /nav stop
    /stick off
    /pet back off
    /pet follow

  SAFETY
    This module never starts travel, navigation, stick, combat, pet attack,
    targeting, casting, loot, or inventory actions.
==========================================================================]]--
