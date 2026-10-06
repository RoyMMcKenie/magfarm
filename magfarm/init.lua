--[[==========================================================================
  FILE        : magfarm/init.lua
  PACKAGE     : MagFarm (MacroQuest / EverQuest)
  VERSION     : 0.3.5

  WHAT  : MagFarm entry point. Registers the ImGui window and /magfarm command,
          then keeps the read-only monitor package alive until stopped.

  WHY   : MacroQuest runs a folder package through its init.lua file. Keeping
          startup, slash-command registration, and shutdown here prevents UI,
          state reading, and movement safety behavior from becoming tangled.

  WHERE : Place the magfarm folder in MacroQuest's active Lua scripts directory
          and start it with: /lua run magfarm

  HOW   : Requires the package modules through portable package names, binds
          /magfarm, registers ui.render with mq.imgui.init, then yields in a
          lightweight loop. The ImGui callback never waits.

  WHEN  : From /lua run magfarm until /lua stop magfarm, /magfarm quit, client
          exit, or leaving the in-game world.

  SAFETY:
    Version 0.3.5 is a monitor. It never starts travel, navigation, combat,
    targeting, pet commands, casting, looting, or inventory actions.
    Its only state-changing control is Stop All Movement.
==========================================================================]]--

local mq = require('mq')
local ui = require('magfarm.ui')
local config = require('magfarm.config')

--- Package version shown in the startup message and UI footer.
local VERSION = '0.3.5'

--- Controls the main loop lifetime.
local running = true

--[[--------------------------------------------------------------------------
  printHelp()

  WHAT  : Prints MagFarm's available slash commands.
  WHY   : Lets the user discover the monitor controls without opening README.
  WHERE : Called by /magfarm help and unrecognized /magfarm subcommands.
  HOW   : Writes a short list to MacroQuest chat with mq.cmd.
  WHEN  : On explicit help request or bad command input.
----------------------------------------------------------------------------]]
local function printHelp()
    mq.cmd('/echo [MagFarm] /magfarm - toggle the monitor window')
    mq.cmd('/echo [MagFarm] /magfarm show - show the monitor window')
    mq.cmd('/echo [MagFarm] /magfarm hide - hide the monitor window')
    mq.cmd('/echo [MagFarm] /magfarm stop - stop travel, navigation, and sticking')
    mq.cmd('/echo [MagFarm] /magfarm quit - stop the MagFarm Lua package')
    mq.cmd('/echo [MagFarm] /magfarm help - show this command list')
end

--[[--------------------------------------------------------------------------
  onCommand(...)

  WHAT  : Handles the /magfarm slash command.
  WHY   : Provides keyboard/hotkey access to the monitor and the verified
          Stop All Movement safety action without requiring the window.
  WHERE : Registered by startup() through mq.bind.
  HOW   : Parses the first supplied word and changes only UI visibility,
          requests a verified movement stop, prints help, or ends the package.
  WHEN  : Whenever the user types /magfarm.
----------------------------------------------------------------------------]]
local function onCommand(...)
    local args = { ... }
    local subcommand = (args[1] or ''):lower()

    if subcommand == '' then
        ui.open = not ui.open

    elseif subcommand == 'show' then
        ui.open = true

    elseif subcommand == 'hide' then
        ui.open = false

    elseif subcommand == 'stop' then
        ui.requestStopAllMovement()

    elseif subcommand == 'quit' then
        running = false

    elseif subcommand == 'help' then
        printHelp()

    else
        printHelp()
    end
end

--[[--------------------------------------------------------------------------
  startup()

  WHAT  : Performs one-time MagFarm initialization.
  WHY   : The slash command and ImGui callback must exist before the main loop
          yields, so users can immediately see or control the monitor.
  WHERE : Called once below before the main loop.
  HOW   : Binds /magfarm, registers the ImGui callback, loads character display settings, and prints a startup
          message describing the deliberately limited version scope.
  WHEN  : Once at /lua run magfarm.
----------------------------------------------------------------------------]]
local function startup()
config.initialize()
    mq.bind('/magfarm', onCommand)
    mq.imgui.init('magfarm', ui.render)

    mq.cmdf(
        '/echo [MagFarm] v%s loaded. Read-only monitor active. Use /magfarm help.',
        VERSION
    )
end

--[[--------------------------------------------------------------------------
  shutdown()

  WHAT  : Releases MagFarm's slash-command binding.
  WHY   : A stale binding can point to an unloaded Lua package after restart.
  WHERE : Called after the main loop ends.
  HOW   : Flushes pending settings and removes the command registered during startup.
  WHEN  : On clean quit, leaving game world, or normal loop exit.
----------------------------------------------------------------------------]]
local function shutdown()
config.flush()
    mq.unbind('/magfarm')
    mq.cmd('/echo [MagFarm] unloaded.')
end

startup()

--[[==========================================================================
  MAIN LOOP

  WHAT  : Keeps the package alive and processes queued UI safety requests.
  WHY   : ImGui renders through its callback, but the package needs a normal
          Lua loop to process actions away from the render callback.
  WHERE : This file only.
  HOW   : Calls ui.tick(), verifies the client remains in-game, then yields for
          100 milliseconds. No game automation happens in this version.
  WHEN  : Continuously after startup until running becomes false.
==========================================================================]]--
while running do
    ui.tick()

    if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then
        mq.cmd('/echo [MagFarm] Left the game world; unloading.')
        break
    end

    mq.delay(100)
end

shutdown()

--[[==========================================================================
  FOOTER : magfarm/init.lua

  STARTUP
    /lua run magfarm

  COMMANDS
    /magfarm
    /magfarm show
    /magfarm hide
    /magfarm stop
    /magfarm quit
    /magfarm help

  SAFETY SCOPE
    - Reads character, pet, target, casting, and spell-gem status.
    - Can stop already-active travel/navigation/sticking.
    - Does not start movement, cast spells, command pets, change targets,
      attack, loot, or perform any autonomous gameplay action.

  DEPENDENCIES
    mq
    magfarm.ui
==========================================================================]]--