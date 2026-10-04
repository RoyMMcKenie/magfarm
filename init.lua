--[[==========================================================================
  FILE        : magfarm/init.lua
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial documented foundation.

  WHAT  : Package entry point, slash-command handler, startup/shutdown owner,
          ImGui registration point, and non-blocking outer loop.
  WHY   : MacroQuest loads init.lua for `/lua run magfarm`; centralizing lifecycle
          makes future behavior traceable and cleanup predictable.
  WHERE : <MacroQuest>/lua/magfarm/init.lua.
  HOW   : Loads settings, scans spells, binds `/magfarm`, registers UI, calls
          state.tick every 100 ms, and saves/unbinds during clean shutdown.
  WHEN  : From `/lua run magfarm` until `/magfarm quit` or `/lua stop magfarm`.
==========================================================================]]--

local mq = require('mq') -- MacroQuest runtime API.
local config = require('magfarm.config') -- Persistent settings lifecycle.
local runtime = require('magfarm.runtime') -- Live state/log.
local utils = require('magfarm.utils') -- Chat helpers.
local spells = require('magfarm.spells') -- Initial spellbook scan.
local state = require('magfarm.state') -- State-machine control.
local ui = require('magfarm.ui') -- ImGui rendering callback.
local running = true -- Clean-quit loop flag.

--[[--------------------------------------------------------------------------
  printHelp()

  WHAT  : Prints supported MagFarm slash commands.
  WHY   : Provides command discoverability without requiring the window.
  WHERE : Called for `/magfarm help` and unknown command input.
  HOW   : Emits concise usage lines through utils.echo.
  WHEN  : On operator request or invalid command.
----------------------------------------------------------------------------]]
local function printHelp()
    utils.echo('/magfarm                         toggle the window') -- Bare command control.
    utils.echo('/magfarm start|stop|pause|resume run controls') -- Lifecycle reference.
    utils.echo('/magfarm camp                    set camp at current position') -- Camp capture reference.
    utils.echo('/magfarm mode manual|camp|follow choose start mode') -- Mode reference.
    utils.echo('/magfarm spells                  rescan spellbook roles') -- Spell scan reference.
    utils.echo('/magfarm acquire scan            scan-only spell acquisition preview') -- Acquisition reference.
    utils.echo('/magfarm status                  print current status') -- Status reference.
    utils.echo('/magfarm quit                    save and end cleanly') -- Clean shutdown reference.
end

--[[--------------------------------------------------------------------------
  onCommand(...)

  WHAT  : Handles words typed after `/magfarm`.
  WHY   : Lets hotkeys and the ImGui window use the same state-machine API.
  WHERE : Bound by startup.
  HOW   : Parses first/second words and delegates to state/spells/UI functions.
  WHEN  : Whenever the operator issues a MagFarm slash command.
----------------------------------------------------------------------------]]
local function onCommand(...)
    local args = { ... } -- Capture command words.
    local sub = (args[1] or ''):lower() -- Normalize primary command.
    local value = (args[2] or ''):lower() -- Normalize optional argument.
    if sub == '' then ui.open = not ui.open -- Toggle display on bare command.
    elseif sub == 'start' then state.start() -- Begin configured mode.
    elseif sub == 'stop' then state.stop('Slash command') -- Stop safely.
    elseif sub == 'pause' then state.pause('Slash command') -- Pause visibly.
    elseif sub == 'resume' then state.resume() -- Restore paused state.
    elseif sub == 'camp' then state.setCamp() -- Capture current location.
    elseif sub == 'mode' then if state.setMode(value) then config.save() end -- Persist valid mode choice.
    elseif sub == 'spells' then spells.detect() utils.echo('\agSpellbook roles refreshed.') -- Refresh roles on demand.
    elseif sub == 'acquire' and value == 'scan' then state.requestAcquisitionScan() -- Start safe preview scan.
    elseif sub == 'status' then utils.echo('State=%s Mode=%s Status=%s', runtime.state, runtime.mode, runtime.status) -- Print concise current state.
    elseif sub == 'quit' then running = false -- Exit through clean shutdown.
    else printHelp() end -- Explain any unrecognized request.
end

--[[--------------------------------------------------------------------------
  startup()

  WHAT  : Performs one-time package initialization.
  WHY   : Settings and spell state must exist before UI and commands read them.
  WHERE : Called once before mainLoop.
  HOW   : Loads config, validates class context, scans spells, binds command,
          registers ImGui, and records initial idle state.
  WHEN  : At `/lua run magfarm`.
----------------------------------------------------------------------------]]
local function startup()
    config.load() -- Must precede any configuration-dependent module work.
    runtime.mode = config.settings.mode -- Make saved choice visible immediately.
    spells.detect() -- Populate role status before first UI frame.
    mq.bind('/magfarm', onCommand) -- Register operator command.
    mq.imgui.init('magfarm', ui.render) -- Register non-blocking frame callback.
    runtime.setState(runtime.STATE.IDLE, 'Loaded; choose a mode and Start.') -- Publish safe initial state.
    utils.echo('\agMagFarm 0.1.0 loaded. Type /magfarm help for commands.') -- Confirm successful startup.
end

--[[--------------------------------------------------------------------------
  shutdown()

  WHAT  : Performs clean package teardown.
  WHY   : Saves settings and removes command binding so reloads do not leave
          stale commands behind.
  WHERE : Called after main loop ends.
  HOW   : Stops any active run, saves config, unbinds command, and logs exit.
  WHEN  : On `/magfarm quit`, `/lua stop`, or clean loop exit.
----------------------------------------------------------------------------]]
local function shutdown()
    if runtime.running then state.stop('Script unloading') end -- Return to a safe idle state first.
    config.save() -- Persist latest choices.
    mq.unbind('/magfarm') -- Remove stale command reference.
    utils.echo('MagFarm ended.') -- Final visible confirmation.
end

--[[--------------------------------------------------------------------------
  mainLoop()

  WHAT  : Runs the package's outer non-blocking work loop.
  WHY   : UI needs control to return frequently; state work must not live inside
          ImGui callbacks or long uninterruptible macro loops.
  WHERE : Called once after startup.
  HOW   : Pumps events, advances one state tick, checks game state, and yields.
  WHEN  : Continuously until clean quit or leaving the game world.
----------------------------------------------------------------------------]]
local function mainLoop()
    while running do -- Continue until operator requests clean exit.
        mq.doevents() -- Keep future chat/UI events responsive.
        state.tick() -- Advance one short state action.
        if mq.TLO.MacroQuest.GameState() ~= 'INGAME' then utils.echo('\ayLeft game world; ending MagFarm.') break end -- Avoid stale TLO actions at character select.
        mq.delay(100) -- Yield so client/UI remain responsive.
    end
end

startup() -- Initialize all runtime dependencies.
local ok, err = pcall(mainLoop) -- Ensure shutdown still runs after unexpected error.
if not ok then utils.echo('\arFatal MagFarm error: %s', tostring(err)) end -- Make unexpected error visible.
shutdown() -- Always release resources and persist settings.

--[[==========================================================================
  END OF FILE : magfarm/init.lua

  COMMANDS
    /magfarm
    /magfarm start|stop|pause|resume
    /magfarm camp
    /magfarm mode manual|camp|follow
    /magfarm spells
    /magfarm acquire scan
    /magfarm status
    /magfarm quit

  DEPENDENCIES : mq and all MagFarm foundation modules.

  HOW TO EDIT SAFELY
    - Keep the main loop delay short and never move waiting work into ui.lua.
    - Add a slash command in both onCommand and printHelp, then README.
    - Use `/magfarm quit` for clean save/unbind behavior.
==========================================================================]]--
