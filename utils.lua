--[[==========================================================================
  FILE        : magfarm/utils.lua
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial documented foundation.

  WHAT  : Low-level helpers for chat output, commands, time, value conversion,
          and simple table operations.
  WHY   : Centralizes repeated MacroQuest plumbing so policy modules remain
          readable and future edits have one safe command/logging path.
  WHERE : Required by every MagFarm module except runtime.lua.
  HOW   : Wraps the mq API and exposes small pure Lua helper functions.
  WHEN  : Loaded once at package startup and used throughout the run.
==========================================================================]]--

local mq = require('mq') -- MacroQuest Lua API.
local utils = {} -- Module export table.

-- WHAT : Chat prefix for all MagFarm output.
-- WHY  : Distinguishes package messages in a busy multi-box chat window.
-- WHERE: Used by echo and debug.
-- HOW  : MacroQuest color-code string.
-- WHEN : Prepended to every package message.
local PREFIX = '\aw[\aoMagFarm\aw]\ax ' -- Stable visible package label.

-- WHAT : Function returning whether Debug is enabled.
-- WHY  : Avoids a utils-to-config require cycle.
-- WHERE: Replaced by config.load through bindDebugFlag.
-- HOW  : Stored closure defaults to false.
-- WHEN : Checked whenever debug is called.
local debugSource = function() return false end -- Quiet until configuration loads.

--[[--------------------------------------------------------------------------
  utils.bindDebugFlag(fn)

  WHAT  : Supplies the live Debug setting reader.
  WHY   : Lets utils.debug honor configuration without requiring config.lua.
  WHERE : Called by config.load.
  HOW   : Stores a zero-argument function or a safe false default.
  WHEN  : Once at startup and after any future settings reload.
----------------------------------------------------------------------------]]
function utils.bindDebugFlag(fn)
    debugSource = fn or function() return false end -- Preserve a safe callable predicate.
end

--[[--------------------------------------------------------------------------
  utils.echo(fmt, ...)

  WHAT  : Prints a formatted MagFarm message to the EQ chat window.
  WHY   : Gives every module consistent, filterable operator feedback.
  WHERE : Called by all modules for normal information and warnings.
  HOW   : Formats optional values, prefixes the result, then sends /echo.
  WHEN  : Whenever an operator-visible event occurs.
----------------------------------------------------------------------------]]
function utils.echo(fmt, ...)
    local text = select('#', ...) > 0 and string.format(fmt, ...) or tostring(fmt) -- Format only when arguments exist.
    mq.cmd('/echo ' .. PREFIX .. text) -- Send the final message to EverQuest.
end

--[[--------------------------------------------------------------------------
  utils.debug(fmt, ...)

  WHAT  : Prints a formatted message only while Debug is enabled.
  WHY   : Provides diagnostic detail without flooding normal chat.
  WHERE : Called by decision points in every policy module.
  HOW   : Checks the injected predicate, then delegates to utils.echo.
  WHEN  : During scans, state transitions, and command decisions.
----------------------------------------------------------------------------]]
function utils.debug(fmt, ...)
    if not debugSource() then return end -- Keep normal operation quiet.
    local text = select('#', ...) > 0 and string.format(fmt, ...) or tostring(fmt) -- Build text after the gate.
    utils.echo('\aoDBG\ax %s', text) -- Mark debug output clearly.
end

--[[--------------------------------------------------------------------------
  utils.cmd(fmt, ...)

  WHAT  : Sends one formatted slash command to MacroQuest.
  WHY   : Gives future command-producing modules one debug-trace choke point.
  WHERE : Used by state, pet, mercenary, follow, and acquisition modules.
  HOW   : Formats the command, logs it when debugging, and calls mq.cmd.
  WHEN  : Only after a policy module has validated the action.
----------------------------------------------------------------------------]]
function utils.cmd(fmt, ...)
    local line = select('#', ...) > 0 and string.format(fmt, ...) or tostring(fmt) -- Construct the command once.
    utils.debug('cmd> %s', line) -- Make outbound actions inspectable.
    mq.cmd(line) -- Dispatch to MacroQuest.
end

--[[--------------------------------------------------------------------------
  utils.clamp(value, low, high)

  WHAT  : Restricts a numeric value to an inclusive range.
  WHY   : Keeps hand-edited settings inside ranges supported by the package.
  WHERE : Used by config validation and future UI controls.
  HOW   : Compares the value to both boundaries.
  WHEN  : During settings load, save, and edit.
----------------------------------------------------------------------------]]
function utils.clamp(value, low, high)
    local number = tonumber(value) or low -- Convert invalid input to the lower safe bound.
    if number < low then return low end -- Enforce minimum.
    if number > high then return high end -- Enforce maximum.
    return number -- Value already fits the allowed interval.
end

--[[--------------------------------------------------------------------------
  utils.toBool(value)

  WHAT  : Converts common saved/string values into a Lua boolean.
  WHY   : Lua treats the string "false" as true, which would invert settings.
  WHERE : Used by config.load and config.validate.
  HOW   : Normalizes supported truthy tokens.
  WHEN  : Whenever boolean settings are read or repaired.
----------------------------------------------------------------------------]]
function utils.toBool(value)
    if type(value) == 'boolean' then return value end -- Preserve native booleans.
    local text = tostring(value or ''):lower() -- Normalize input safely.
    return text == 'true' or text == '1' or text == 'yes' or text == 'on' -- Recognize explicit truth values.
end

--[[--------------------------------------------------------------------------
  utils.deepCopy(value)

  WHAT  : Returns a recursive independent copy of a Lua value/table.
  WHY   : Prevents DEFAULTS nested tables from becoming shared live state.
  WHERE : Used by config.load while merging saved settings.
  HOW   : Copies non-table values directly and recurses through table pairs.
  WHEN  : Once at settings load for missing default values.
----------------------------------------------------------------------------]]
function utils.deepCopy(value)
    if type(value) ~= 'table' then return value end -- Scalars already copy by value.
    local output = {} -- Create a fresh destination table.
    for key, child in pairs(value) do output[key] = utils.deepCopy(child) end -- Clone every nested member.
    return output -- Return independent data.
end

--[[--------------------------------------------------------------------------
  utils.now()

  WHAT  : Returns a monotonic-ish process time used for throttles.
  WHY   : Avoids using wall-clock time for short in-session status intervals.
  WHERE : Used by runtime logs and future polling guards.
  HOW   : Delegates to os.clock.
  WHEN  : Whenever elapsed-time comparison is needed.
----------------------------------------------------------------------------]]
function utils.now()
    return os.clock() -- Lua process CPU clock is sufficient for current local throttles.
end

return utils -- Export shared helpers.

--[[==========================================================================
  END OF FILE : magfarm/utils.lua

  EXPORTS
    bindDebugFlag(fn)  Inject Debug predicate.
    echo(fmt,...)      Print prefixed chat output.
    debug(fmt,...)     Print Debug-gated chat output.
    cmd(fmt,...)       Dispatch a traced MacroQuest command.
    clamp(v,lo,hi)     Restrict numeric values.
    toBool(v)          Convert values to booleans.
    deepCopy(v)        Copy nested tables safely.
    now()              Return process time for throttling.

  DEPENDENCIES : mq.

  HOW TO EDIT SAFELY
    - Do not require config.lua here; config already requires utils.lua.
    - Use utils.cmd for outbound game commands so Debug trace remains complete.
==========================================================================]]--
