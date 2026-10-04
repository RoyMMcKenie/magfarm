--[[==========================================================================
  FILE        : magfarm/state.lua
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial state-machine control foundation.

  WHAT  : Owns Start, Pause, Resume, Stop, mode preparation, status refresh,
          camp capture, and Spell Acquisition scan transitions.
  WHY   : Explicit state makes behavior visible, pausable, and extensible
          without nested macro loops or hidden goto control flow.
  WHERE : Called by init.lua's main loop and requested by ui.lua/commands.
  HOW   : Dispatches one short handler per state; handlers never run combat or
          unverified movement/mercenary/vendor commands in version 0.1.
  WHEN  : Once per main-loop pass while loaded.
==========================================================================]]--

local mq = require('mq') -- Character/location TLO access.
local config = require('magfarm.config') -- Mode and policy settings.
local runtime = require('magfarm.runtime') -- Live state and log.
local utils = require('magfarm.utils') -- Operator output.
local spells = require('magfarm.spells') -- Spellbook scan.
local assist = require('magfarm.assist') -- Group/Main Assist status.
local pet = require('magfarm.pet') -- Pet status.
local merc = require('magfarm.merc') -- Mercenary status.
local follow = require('magfarm.follow') -- Follow-leader validation.
local acquisition = require('magfarm.spell_acquisition') -- Spell Acquisition preview.
local state = {} -- Module export table.

--[[--------------------------------------------------------------------------
  state.refreshStatus()

  WHAT  : Refreshes read-only module status in a consistent dependency order.
  WHY   : Pet policy depends on assist group status, and UI needs current facts.
  WHERE : Called by prepare and every active-state tick.
  HOW   : Refreshes assist first, then pet/merc/follow conditionally.
  WHEN  : At startup, state transitions, and active loop updates.
----------------------------------------------------------------------------]]
function state.refreshStatus()
    assist.refresh() -- Group ownership must be current before pet policy calculates.
    pet.refresh() -- Pet policy reads assist status.
    merc.refresh() -- Mercenary status is independent but shown alongside pet.
    if runtime.mode == 'follow' then follow.refresh() end -- Follow roster check only matters in Follow mode.
end

--[[--------------------------------------------------------------------------
  state.start()

  WHAT  : Starts the configured operating mode after resetting volatile state.
  WHY   : UI and slash commands must share one reliable run entry point.
  WHERE : Called by ui.lua and init.lua command handler.
  HOW   : Prevents duplicate starts, resets run data, marks running, and enters
          PREPARE where preflight can pause visibly on failure.
  WHEN  : On explicit operator Start request.
----------------------------------------------------------------------------]]
function state.start()
    if runtime.running then utils.echo('\ayMagFarm is already running.') return end -- Refuse duplicate run initialization.
    runtime.resetRun() -- Remove stale target/pull/emergency facts.
    runtime.mode = config.settings.mode -- Adopt persisted selected mode.
    runtime.running = true -- Allow state.tick to dispatch work.
    runtime.setState(runtime.STATE.PREPARE, 'Running preflight checks.') -- Make startup visible.
end

--[[--------------------------------------------------------------------------
  state.stop(reason)

  WHAT  : Stops current activity safely and returns to Idle.
  WHY   : Operators need immediate control without unloading the UI/package.
  WHERE : Called by UI, slash commands, and future safety handlers.
  HOW   : Clears running/pause intent and transitions to IDLE; command-producing
          modules are not active in 0.1, so no external stop command is needed.
  WHEN  : On explicit Stop or future unrecoverable safety event.
----------------------------------------------------------------------------]]
function state.stop(reason)
    runtime.running = false -- Prevent further active handler dispatch.
    runtime.resumeState = nil -- Stop is final, unlike Pause.
    runtime.setState(runtime.STATE.IDLE, reason or 'Stopped by operator.') -- Publish idle state and rationale.
    utils.echo('\ayMagFarm stopped%s.', reason and (': ' .. reason) or '') -- Give immediate chat confirmation.
end

--[[--------------------------------------------------------------------------
  state.pause(reason)

  WHAT  : Pauses current activity while retaining its resume destination.
  WHY   : Maintenance, review, and safety checks should not discard context.
  WHERE : Called by UI, slash commands, acquisition, and future safety logic.
  HOW   : Stores current state once and transitions to PAUSED.
  WHEN  : On explicit Pause or a visible preflight/safety issue.
----------------------------------------------------------------------------]]
function state.pause(reason)
    if runtime.state ~= runtime.STATE.PAUSED then runtime.resumeState = runtime.state end -- Preserve first meaningful origin.
    runtime.setState(runtime.STATE.PAUSED, reason or 'Paused by operator.') -- Publish paused state.
    utils.echo('\ayMagFarm paused: %s', runtime.status) -- Make pause reason clear in chat.
end

--[[--------------------------------------------------------------------------
  state.resume()

  WHAT  : Restores the state saved by Pause when safe to do so.
  WHY   : Pause should not force a full restart or hide the original context.
  WHERE : Called by UI and slash commands.
  HOW   : Uses saved state or PREPARE fallback, then clears the saved value.
  WHEN  : Only while currently PAUSED.
----------------------------------------------------------------------------]]
function state.resume()
    if runtime.state ~= runtime.STATE.PAUSED then utils.echo('\ayMagFarm is not paused.') return end -- Reject invalid resume requests.
    local nextState = runtime.resumeState or runtime.STATE.PREPARE -- Choose preserved origin or safe preflight.
    runtime.resumeState = nil -- Consume one-time resume context.
    runtime.setState(nextState, 'Resumed by operator.') -- Publish resumed state.
end

--[[--------------------------------------------------------------------------
  state.setMode(mode)

  WHAT  : Changes the requested operator mode and persists it in live settings.
  WHY   : Mode is an operator choice, while current runtime state is transient.
  WHERE : Called by UI and slash commands.
  HOW   : Validates three supported names, updates config, and logs result.
  WHEN  : While idle/paused; active behavior adopts it on next Start.
----------------------------------------------------------------------------]]
function state.setMode(mode)
    local value = tostring(mode or ''):lower() -- Normalize command/UI input.
    if value ~= 'manual' and value ~= 'camp' and value ~= 'follow' then utils.echo('\arUnknown mode: %s', value) return false end -- Reject unsupported modes.
    config.settings.mode = value -- Store future-start preference.
    runtime.mode = value -- Update immediate UI display.
    runtime.note('Mode selected: %s', value) -- Record operator decision.
    return true -- Signal UI command success.
end

--[[--------------------------------------------------------------------------
  state.setCamp()

  WHAT  : Saves the Magician's current coordinates as camp.
  WHY   : Camp behavior must never infer a location without explicit operator intent.
  WHERE : Called by UI and `/magfarm camp`.
  HOW   : Reads Me.Y/X/Z and delegates storage to runtime.setCamp.
  WHEN  : On explicit operator request.
----------------------------------------------------------------------------]]
function state.setCamp()
    runtime.setCamp(mq.TLO.Me.Y() or 0, mq.TLO.Me.X() or 0, mq.TLO.Me.Z() or 0) -- Capture current in-zone location.
    utils.echo('\agCamp recorded.') -- Confirm the operator action.
end

--[[--------------------------------------------------------------------------
  state.requestAcquisitionScan()

  WHAT  : Starts the scan-only Spell Acquisition maintenance workflow.
  WHY   : Acquisition must pause normal behavior and stay operator-controlled.
  WHERE : Called by UI and `/magfarm acquire scan`.
  HOW   : Pauses an active run if needed, marks running, and enters scan state.
  WHEN  : Only by explicit operator request.
----------------------------------------------------------------------------]]
function state.requestAcquisitionScan()
    if runtime.running and runtime.state ~= runtime.STATE.PAUSED then state.pause('Spell Acquisition requested.') end -- Preserve active context before maintenance.
    runtime.running = true -- Permit acquisition state dispatch when launched from idle.
    runtime.setState(runtime.STATE.ACQUISITION_SCAN, 'Scanning spell acquisition environment.') -- Show job start.
end

--[[--------------------------------------------------------------------------
  state.prepare()

  WHAT  : Performs safe preflight and transitions into requested operating mode.
  WHY   : A bad class, absent camp, or unresolved follow leader should be visible
          before later automation can issue meaningful commands.
  WHERE : PREPARE handler.
  HOW   : Validates MAG class, scans spellbook, refreshes status, then routes to
          Manual, Camp Idle, or Follow; failures pause instead of stopping.
  WHEN  : At every Start and any Resume that returns to PREPARE.
----------------------------------------------------------------------------]]
function state.prepare()
    if (mq.TLO.Me.Class.ShortName() or '') ~= 'MAG' then state.pause('MagFarm is designed for MAG; no behavior started.') return end -- Enforce package scope.
    spells.detect() -- Build current role selections before status/UI needs them.
    state.refreshStatus() -- Build group/pet/merc/follow facts in correct order.
    if runtime.mode == 'camp' and not runtime.camp then state.pause('Camp mode requires Set Camp before Start.') return end -- Require explicit camp anchor.
    if runtime.mode == 'follow' and not follow.status.valid then state.pause(follow.status.reason) return end -- Refuse invisible/invalid follow behavior.
    if runtime.mode == 'manual' then runtime.setState(runtime.STATE.MANUAL, 'Manual mode active.') -- Enter inert manual state.
    elseif runtime.mode == 'camp' then runtime.setState(runtime.STATE.CAMP_IDLE, 'Camp foundation active; pulling is not enabled in 0.1.') -- Show intentionally staged scope.
    else runtime.setState(runtime.STATE.FOLLOW, 'Follow preview active; movement is not enabled in 0.1.') end -- Show intentionally staged scope.
end

--[[--------------------------------------------------------------------------
  state.manual()

  WHAT  : Services Manual mode with safe status refresh only.
  WHY   : Version 0.1 should be useful for monitoring without autonomous action.
  WHERE : MANUAL handler.
  HOW   : Refreshes group/pet/merc facts and returns immediately.
  WHEN  : Every active main-loop pass in Manual mode.
----------------------------------------------------------------------------]]
function state.manual()
    state.refreshStatus() -- Keep visible facts current without game actions.
end

--[[--------------------------------------------------------------------------
  state.campIdle()

  WHAT  : Services staged Camp mode without autonomous pulling in 0.1.
  WHY   : Preserves architecture and observability before pull commands are tested.
  WHERE : CAMP_IDLE handler.
  HOW   : Refreshes status and keeps a clear staged-feature message.
  WHEN  : Every active main-loop pass in Camp mode.
----------------------------------------------------------------------------]]
function state.campIdle()
    state.refreshStatus() -- Keep pet/merc/group facts current.
    runtime.status = 'Camp foundation active; autonomous pulling is deferred for client-tested milestone 0.2.' -- Make scope unambiguous.
end

--[[--------------------------------------------------------------------------
  state.follow()

  WHAT  : Services Follow preview mode without movement commands in 0.1.
  WHY   : Leader resolution should be tested before enabling MQ2Nav automation.
  WHERE : FOLLOW handler.
  HOW   : Refreshes status and pauses if leader becomes invalid.
  WHEN  : Every active main-loop pass in Follow mode.
----------------------------------------------------------------------------]]
function state.follow()
    state.refreshStatus() -- Refresh leader/pet/merc/group status.
    if not follow.status.valid then state.pause(follow.status.reason) return end -- Never follow an invalid leader.
    runtime.status = follow.status.reason -- Explain that 0.1 is observation-only.
end

--[[--------------------------------------------------------------------------
  state.acquisitionScan()

  WHAT  : Executes one safe Spell Acquisition preview scan.
  WHY   : Acquisition scans must occur on the main loop, never in ImGui.
  WHERE : ACQUISITION_SCAN handler.
  HOW   : Delegates to acquisition.scan then moves to review state.
  WHEN  : Once for every explicit acquisition scan request.
----------------------------------------------------------------------------]]
function state.acquisitionScan()
    acquisition.scan() -- Build attributed safe preview plan.
    runtime.setState(runtime.STATE.ACQUISITION_REVIEW, acquisition.plan.message) -- Wait for operator review.
end

--[[--------------------------------------------------------------------------
  state.acquisitionReview()

  WHAT  : Holds the completed preview plan for operator review.
  WHY   : Version 0.1 must never purchase or scribe automatically.
  WHERE : ACQUISITION_REVIEW handler.
  HOW   : Keeps state stable and refreshes status facts only.
  WHEN  : Until operator pauses/stops/resumes or requests another scan.
----------------------------------------------------------------------------]]
function state.acquisitionReview()
    state.refreshStatus() -- Keep supporting status current while reviewing plan.
end

-- WHAT : State-to-handler dispatch map.
-- WHY  : Makes missing behaviors obvious and keeps state.tick concise.
-- WHERE: Read by state.tick.
-- HOW  : Keys match runtime.STATE values.
-- WHEN : Every active loop pass.
local HANDLERS = { -- One handler per active state.
    [runtime.STATE.PREPARE] = state.prepare, -- Preflight route.
    [runtime.STATE.MANUAL] = state.manual, -- Read-only manual state.
    [runtime.STATE.CAMP_IDLE] = state.campIdle, -- Staged camp foundation.
    [runtime.STATE.FOLLOW] = state.follow, -- Staged follow foundation.
    [runtime.STATE.ACQUISITION_SCAN] = state.acquisitionScan, -- One-shot scan state.
    [runtime.STATE.ACQUISITION_REVIEW] = state.acquisitionReview, -- Review holding state.
} -- IDLE and PAUSED intentionally have no active handlers.

--[[--------------------------------------------------------------------------
  state.tick()

  WHAT  : Advances MagFarm by one short state-machine action.
  WHY   : One small action per main-loop pass keeps UI and operator controls responsive.
  WHERE : Called by init.lua main loop.
  HOW   : Returns in Idle/Paused/not-running states; otherwise executes mapped
          handler under pcall and pauses visibly on unexpected Lua errors.
  WHEN  : Roughly every 100 ms while package is loaded.
----------------------------------------------------------------------------]]
function state.tick()
    if not runtime.running then return end -- Idle packages need no work.
    if runtime.state == runtime.STATE.IDLE or runtime.state == runtime.STATE.PAUSED then return end -- Explicit inactive states stay inert.
    local handler = HANDLERS[runtime.state] -- Resolve active handler.
    if not handler then state.pause('No handler exists for state ' .. tostring(runtime.state)) return end -- Fail visibly rather than silently.
    local ok, err = pcall(handler) -- Contain module errors so UI remains usable.
    if not ok then state.pause('State error: ' .. tostring(err)) end -- Preserve error reason for operator review.
end

return state -- Export lifecycle controls.

--[[==========================================================================
  END OF FILE : magfarm/state.lua

  EXPORTS
    refreshStatus()             Refresh read-only module facts.
    start()/stop(reason)        Run lifecycle.
    pause(reason)/resume()      Suspend and restore state.
    setMode(mode)               Select Manual/Camp/Follow.
    setCamp()                   Save current position.
    requestAcquisitionScan()    Start safe acquisition preview.
    tick()                      Advance one state-machine action.

  DEPENDENCIES : mq, magfarm config/runtime/utils/spells/assist/pet/merc/follow/acquisition.

  HOW TO EDIT SAFELY
    - Add a runtime.STATE constant before adding a handler here.
    - Keep handlers short; long jobs must be decomposed into states.
    - UI must request actions through these functions, never duplicate logic.
==========================================================================]]--
