--[[
FILE: magfarm/config.lua
PACKAGE: MagFarm
VERSION: 0.3.5 reset-persistence correction
WHAT: Validated display thresholds with server/character persistence.
WHY: Preserve edits and explicit default resets across Lua restarts.
WHERE: Required by UI and initialized by the v0.3.5 entry point.
HOW: Parse schema-1 text; queue writes for tick; use temporary and backup files.
WHEN: Load at startup; save from tick and clean shutdown, never rendering.
SAFETY: Identity reads and settings-file writes only; no gameplay commands.
]]
local mq = require('mq')
local config = {}
local definitions = {
    hpRedBelow = {default=35, minimum=0, maximum=100},
    manaRedBelow = {default=35, minimum=0, maximum=100},
}
local values = {hpRedBelow=35, manaRedBelow=35}
local path, dirty, blocked = nil, false, false
local statusText = 'Not initialized'

--[[
FUNCTION: readIdentity()
WHAT: Reads server and character
WHY: Resolve storage identity
WHERE: initialize protected call
HOW: Read EverQuest.Server and Me.CleanName
WHEN: At startup
]]
local function readIdentity()
    return mq.TLO.EverQuest.Server(), mq.TLO.Me.CleanName()
end

--[[
FUNCTION: encodeByte(c)
WHAT: Encodes one unsafe filename byte
WHY: Avoid filename ambiguity
WHERE: encode replacement callback
HOW: Use hexadecimal escape
WHEN: On a non-safe byte
]]
local function encodeByte(c)
    return string.format('_%02X', string.byte(c))
end

--[[
FUNCTION: encode(text)
WHAT: Makes identity filename-safe
WHY: Separate characters without path injection
WHERE: initialize filename construction
HOW: Escape non-alphanumeric/non-hyphen bytes
WHEN: At startup
]]
local function encode(text)
    return (text:gsub('[^%w%-]', encodeByte))
end

--[[
FUNCTION: saveFailure(err)
WHAT: Records a failed save
WHY: Avoid silent failure and repeated frame-loop retries
WHERE: flush error paths
HOW: Clear pending flag; retain in-memory values and report error
WHEN: After a write/rename failure
]]
local function saveFailure(err)
    dirty = false
    statusText = 'Save failed: ' .. tostring(err)
    return false, statusText
end

--[[
FUNCTION: get(key)
WHAT: Returns a setting
WHY: Hide internal storage
WHERE: UI resource and Options rendering
HOW: Look up the key
WHEN: Whenever a consumer reads configuration
]]
function config.get(key)
    return values[key]
end

--[[
FUNCTION: set(key, value)
WHAT: Validates and queues a setting edit
WHY: Reject invalid numbers and persist changes
WHERE: Options and startup loading
HOW: Clamp finite input and round; mark changed values dirty
WHEN: When a setting changes
]]
function config.set(key, value)
    local definition = definitions[key]
    if not definition then return false, 'Unknown setting' end
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then
        return false, 'Expected a finite number'
    end
    number = math.floor(math.max(definition.minimum, math.min(definition.maximum, number)) + 0.5)
    if values[key] ~= number then values[key] = number; dirty = true end
    return true
end

--[[
FUNCTION: reset()
WHAT: Restores defaults and queues their save
WHY: Reset must persist, not only alter the display
WHERE: Options reset button
HOW: Copy defaults and always mark dirty
WHEN: On explicit operator reset
]]
function config.reset()
    for key, definition in pairs(definitions) do values[key] = definition.default end
    dirty = true
end

--[[
FUNCTION: initialize()
WHAT: Loads this server and character settings
WHY: Keep character preferences independent
WHERE: Entry-point startup
HOW: Read identity and parse non-executable schema-1 text
WHEN: Before UI registration
]]
function config.initialize()
    local ok, server, character = pcall(readIdentity)
    if not ok or not server or server == '' or not character or character == '' or not mq.configDir then
        statusText = 'Persistence unavailable: identity or config directory missing'
        return false, statusText
    end
    path = mq.configDir .. '/MagFarm_' .. encode(server) .. '_' .. encode(character) .. '.settings'
    blocked = false
    for key, definition in pairs(definitions) do values[key] = definition.default end
    dirty = false
    local handle = io.open(path, 'r')
    if not handle then
        statusText = 'Defaults active; settings will be created on edit'
        return true
    end
    local content = handle:read('*a')
    handle:close()
    if not content then statusText = 'Load failed; defaults active'; blocked = true; return false, statusText end
    local parsed = {}
    for line in content:gmatch('[^\r\n]+') do
        local key, value = line:match('^([%w]+)=([^\r\n]+)$')
        if key then parsed[key] = value end
    end
    if tonumber(parsed.schemaVersion) ~= 1 then
        blocked = true
        statusText = 'Unsupported settings schema; defaults active; file preserved'
        return false, statusText
    end
    for key in pairs(definitions) do if parsed[key] then config.set(key, parsed[key]) end end
    dirty = false
    statusText = 'Loaded: ' .. path
    return true
end

--[[
FUNCTION: flush()
WHAT: Saves pending edits including resets
WHY: Keep file I/O outside rendering and retain the previous file
WHERE: Main-loop tick and shutdown
HOW: Write a temporary file; back up existing data; replace or restore on failure
WHEN: When dirty settings are pending
]]
function config.flush()
    if not dirty then return true end
    if not path or blocked then return false, statusText end
    local temporary, backup = path .. '.tmp', path .. '.bak'
    local handle, err = io.open(temporary, 'w')
    if not handle then return saveFailure(err) end
    local written, writeError = handle:write(string.format(
        'schemaVersion=1\nhpRedBelow=%d\nmanaRedBelow=%d\n', values.hpRedBelow, values.manaRedBelow))
    local closed, closeError = handle:close()
    if not written or not closed then os.remove(temporary); return saveFailure(writeError or closeError) end
    local existing = io.open(path, 'r')
    if existing then
        existing:close()
        os.remove(backup)
        local moved, moveError = os.rename(path, backup)
        if not moved then os.remove(temporary); return saveFailure(moveError) end
    end
    local saved, saveError = os.rename(temporary, path)
    if not saved then
        local rollbackError
        if existing then
            local restored
            restored, rollbackError = os.rename(backup, path)
            if restored then rollbackError = nil end
        end
        os.remove(temporary)
        return saveFailure(tostring(saveError) .. (rollbackError and '; rollback failed: ' .. tostring(rollbackError) or ''))
    end
    dirty = false
    statusText = 'Saved: ' .. path
    return true
end

--[[
FUNCTION: status()
WHAT: Returns load/save status
WHY: Expose persistence results and failures
WHERE: Options status line
HOW: Return status text
WHEN: During visible rendering
]]
function config.status()
    return statusText
end

return config
--[[
FOOTER: magfarm/config.lua
EXPORTS: get, set, reset, initialize, flush, status
DEFAULTS: hpRedBelow=35; manaRedBelow=35. Comparison remains strictly below.
FORMAT: schemaVersion=1; compatible with existing v0.3.5 .settings files.
RESET FIX: reset always sets dirty=true; the next tick saves 35/35.
ERRORS: In-memory changes survive save failure; edit/reset to retry.
Unknown schemas remain untouched. Backup recovery after a crash is manual.
DOCUMENTATION: Every function describes what, why, where, how and when.
END OF FILE
]]
