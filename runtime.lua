--[[==========================================================================
  FILE        : magfarm/runtime.lua
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial documented foundation.

  WHAT  : Owns volatile runtime state, visible status, camp coordinates, and
          the rolling operator log.
  WHY   : Runtime facts must not be confused with saved configuration choices.
  WHERE : Required by state, UI, and status/policy modules.
  HOW   : Exposes one shared table plus reset, state, note, and camp helpers.
  WHEN  : Lives only while MagFarm is loaded; it is never persisted.
==========================================================================]]--

local runtime = {} -- Module export table.

-- WHAT : Legal high-level states for the 0.1 foundation and future milestones.
-- WHY  : Keeps state names centralized and visible to UI/documentation.
-- WHERE: Used by state.lua and ui.lua.
-- HOW  : Plain immutable-looking string table.
-- WHEN  : Read on every state transition and UI frame.
runtime.STATE = { -- State constants avoid misspelled string literals.
    IDLE = 'IDLE', -- Script loaded but intentionally inactive.
    PREPARE = 'PREPARE', -- Running preflight before a selected mode begins.
    MANUAL = 'MANUAL', -- Operator-controlled mode with no automatic combat.
    CAMP_IDLE = 'CAMP_IDLE', -- Reserved foundation state for later camp pulling.
    FOLLOW = 'FOLLOW', -- Follow-policy mode; movement control remains preview-safe in 0.1.
    PAUSED = 'PAUSED', -- Automation intentionally suspended.
    ACQUISITION_SCAN = 'ACQUISITION_SCAN', -- Spell Acquisition preview scan.
    ACQUISITION_REVIEW = 'ACQUISITION_REVIEW', -- Waiting for operator review.
} -- Future states are added here before their handlers are created.

-- WHAT : Maximum retained log lines.
-- WHY  : Keeps UI log memory bounded during long play sessions.
-- WHERE: Used by runtime.note.
-- HOW  : Fixed conservative number.
-- WHEN  : Enforced whenever a new note is recorded.
runtime.LOG_MAX = 150 -- Enough context without unbounded growth.

-- WHAT : Whether an operator-started run is active.
-- WHY  : Lets main-loop code stay idle without losing window visibility.
-- WHERE: Read by state.tick and UI controls.
-- HOW  : Plain boolean.
-- WHEN  : Changed by state.start and state.stop.
runtime.running = false -- Idle until operator starts.

-- WHAT : Current named package state.
-- WHY  : Makes behavior observable and dispatchable.
-- WHERE: Read by state.lua and ui.lua.
-- HOW  : One of runtime.STATE strings.
-- WHEN  : Updated through runtime.setState.
runtime.state = runtime.STATE.IDLE -- Safe initial state.

-- WHAT : State to restore after Pause.
-- WHY  : Pause should preserve operator context rather than restart work.
-- WHERE: Written by state.pause and read by state.resume.
-- HOW  : State string or nil.
-- WHEN  : Exists only during a pause cycle.
runtime.resumeState = nil -- No paused origin while idle.

-- WHAT : Current requested operating mode.
-- WHY  : Separates operator intent from current transient state.
-- WHERE: Read by state.prepare and UI.
-- HOW  : 'manual', 'camp', or 'follow'.
-- WHEN  : Changed by user command or UI selection.
runtime.mode = 'manual' -- Lowest-risk default mode.

-- WHAT : Last human-readable status sentence.
-- WHY  : Gives the operator one quick explanation without opening logs.
-- WHERE: Rendered by ui.lua and written by modules.
-- HOW  : Plain string.
-- WHEN  : Updated on meaningful state/policy changes.
runtime.status = 'Loaded; awaiting Start.' -- Startup status.

-- WHAT : Bounded history of important decisions and events.
-- WHY  : Makes later diagnosis possible after chat scrolls away.
-- WHERE: Rendered by ui.lua.
-- HOW  : Append-only array trimmed to LOG_MAX.
-- WHEN  : Written through runtime.note.
runtime.log = {} -- Fresh session log.

-- WHAT : Saved camp coordinates for future Camp mode.
-- WHY  : Camp pulling needs an explicit stable reference point.
-- WHERE: Written by state.setCamp and displayed by ui.lua.
-- HOW  : Plain coordinate table or nil.
-- WHEN  : Set only by an explicit operator action in 0.1.
runtime.camp = nil -- No camp is implied automatically.

-- WHAT : Temporary emergency location reserved for future fallback behavior.
-- WHY  : Documents where rooted/low-HP defense data will live.
-- WHERE: Future safety.lua and UI.
-- HOW  : Coordinate/reason table or nil.
-- WHEN  : Unused in 0.1 by design.
runtime.emergencyCamp = nil -- Placeholder for later defensive milestone.

-- WHAT : Current current target display facts.
-- WHY  : UI needs status without making targeting decisions.
-- WHERE: Updated by future targeting/assist modules.
-- HOW  : Small plain table.
-- WHEN  : Read each UI frame.
runtime.target = { id = 0, name = '', hp = 0 } -- Safe empty target descriptor.

-- WHAT : Current pull transaction placeholder for later Camp mode.
-- WHY  : Future pull states need explicit target ownership and phase tracking.
-- WHERE: Reserved for targeting/combat/safety modules.
-- HOW  : Plain table reset between pulls.
-- WHEN  : Not actioned in 0.1.
runtime.pull = { phase = 'idle', targetId = 0, targetName = '', reason = '' } -- Documented future boundary.

--[[--------------------------------------------------------------------------
  runtime.setState(nextState, reason)

  WHAT  : Changes the current state and records an operator-visible reason.
  WHY   : Centralizing transitions creates a durable audit trail.
  WHERE : Called by state.lua and future safety/acquisition handlers.
  HOW   : Stores the state, updates status, and writes a log entry.
  WHEN  : Every legal state transition.
----------------------------------------------------------------------------]]
function runtime.setState(nextState, reason)
    runtime.state = nextState -- Publish the new state first for readers.
    runtime.status = reason or nextState -- Give UI a concise explanation.
    runtime.note('State -> %s%s', nextState, reason and (': ' .. reason) or '') -- Preserve transition history.
end

--[[--------------------------------------------------------------------------
  runtime.note(fmt, ...)

  WHAT  : Appends one timestamped line to the rolling runtime log.
  WHY   : Gives UI and later debugging a bounded history of decisions.
  WHERE : Called by every module for meaningful events.
  HOW   : Formats text, adds elapsed time, inserts, and trims old entries.
  WHEN  : Whenever a state or policy event should be retained.
----------------------------------------------------------------------------]]
function runtime.note(fmt, ...)
    local text = select('#', ...) > 0 and string.format(fmt, ...) or tostring(fmt) -- Safely format optional values.
    table.insert(runtime.log, string.format('[%07.1f] %s', os.clock(), text)) -- Add chronological context.
    while #runtime.log > runtime.LOG_MAX do table.remove(runtime.log, 1) end -- Retain only the newest lines.
end

--[[--------------------------------------------------------------------------
  runtime.setCamp(y, x, z)

  WHAT  : Stores a camp position snapshot.
  WHY   : Camp mode must use an explicit operator-selected anchor.
  WHERE : Called by state.setCamp.
  HOW   : Stores numeric coordinates in Y/X/Z EverQuest order.
  WHEN  : On /magfarm camp or the Set Camp button.
----------------------------------------------------------------------------]]
function runtime.setCamp(y, x, z)
    runtime.camp = { y = tonumber(y) or 0, x = tonumber(x) or 0, z = tonumber(z) or 0 } -- Store a clean immutable-style snapshot.
    runtime.note('Camp set: Y %.1f X %.1f Z %.1f', runtime.camp.y, runtime.camp.x, runtime.camp.z) -- Record operator action.
end

--[[--------------------------------------------------------------------------
  runtime.resetRun()

  WHAT  : Clears per-run state without deleting selected mode or saved camp.
  WHY   : Start must not inherit stale targets, pull phases, or emergencies.
  WHERE : Called by state.start.
  HOW   : Replaces only volatile combat/pull fields.
  WHEN  : Once at each new run.
----------------------------------------------------------------------------]]
function runtime.resetRun()
    runtime.resumeState = nil -- A new run has no prior paused state.
    runtime.emergencyCamp = nil -- Do not carry an old emergency location forward.
    runtime.target = { id = 0, name = '', hp = 0 } -- Clear display-only target state.
    runtime.pull = { phase = 'idle', targetId = 0, targetName = '', reason = '' } -- Clear future pull transaction state.
end

return runtime -- Export shared runtime state.

--[[==========================================================================
  END OF FILE : magfarm/runtime.lua

  EXPORTS
    STATE              Legal state constants.
    LOG_MAX            Maximum retained log lines.
    running/state      Live execution flags.
    mode/status/log    Operator-visible runtime values.
    camp/emergencyCamp Camp anchors.
    target/pull        Current and future combat display data.
    setState(s,r)      Change state with logging.
    note(fmt,...)      Append a log entry.
    setCamp(y,x,z)     Save camp coordinates.
    resetRun()         Clear per-run volatile state.

  DEPENDENCIES : none.

  HOW TO EDIT SAFELY
    - Persisted options belong in config.lua, never here.
    - Add new behavior state names here before adding a state handler.
==========================================================================]]--
