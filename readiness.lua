--[[
FILE: readiness.lua
PACKAGE: MagFarm
VERSION: 0.3.6 startup-readiness candidate
WHAT: Inspect runtime bindings and optional movement plugins; queue manual loads.
WHY: Missing plugins must not be guessed available or stop the read-only monitor.
WHERE: Initialized by init.lua; ticked and rendered by ui.lua; read by movement.lua.
HOW: Protected Plugin(name).IsLoaded reads, cached rows, bounded transition events.
WHEN: Startup, a one-second poll, an explicit refresh or an operator load request.
SAFETY: No automatic plugin loading/unloading and no gameplay automation.
Plugin loading is allowed only for three named movement plugins after a click.
Loading may execute the plugin's own initialization; it is not proof of readiness.
SOURCES: Official MacroQuest Plugin TLO and /plugin command documentation.
]]--
local mq = require('mq')
local readiness = {}
local definitions = {
    {name='MQ2Lua', purpose='Required Lua runtime; already executing this package.'},
    {name='MQ2EasyFind', purpose='Optional /travelto stop component.', loadable=true},
    {name='MQ2Nav', purpose='Optional /nav stop component.', loadable=true},
    {name='MQ2MoveUtils', purpose='Optional /stick off component.', loadable=true},
    {name='MQ2Melee', purpose='Observation only: loaded does not mean active or conflicting.'},
}
local rows, lookup, events, loadRequests = {}, {}, {}, {}
local refreshRequested, lastRefresh = true, nil
local bindingsAvailable, bindingsError = false, nil
for _, definition in ipairs(definitions) do
    local row = {name=definition.name, purpose=definition.purpose,
        loadable=definition.loadable == true, label='Unknown', known=false}
    table.insert(rows, row)
    lookup[row.name] = row
end

--[[
FUNCTION: record(message)
WHAT: Queue one readiness event
WHY: Make status transitions and explicit requests visible without tick spam
WHERE: refresh and request processing
HOW: Timestamp text and retain at most 20 unconsumed entries
WHEN: A result changes or an operator requests an action
]]
local function record(message)
    table.insert(events, '[' .. os.date('%Y-%m-%d %H:%M:%S') .. '] Readiness: ' .. message)
    while #events > 20 do table.remove(events, 1) end
end

--[[
FUNCTION: readLoaded(name)
WHAT: Read the documented plugin loaded flag
WHY: Keep the protected-call target named and isolated
WHERE: refresh through pcall
HOW: Invoke mq.TLO.Plugin(name).IsLoaded()
WHEN: A readiness sample is collected
]]
local function readLoaded(name)
    return mq.TLO.Plugin(name).IsLoaded()
end

--[[
FUNCTION: loadBindings()
WHAT: Resolve the documented ImGui Lua module
WHY: ImGui is a Lua binding, not an invented separate plugin dependency
WHERE: initialize through pcall
HOW: Require ImGui and let the Lua module cache retain it
WHEN: Before requiring the monitor UI
]]
local function loadBindings()
    return require('ImGui')
end

--[[
FUNCTION: readiness.refresh()
WHAT: Update cached loaded/missing/unknown rows
WHY: Missing optional plugins must degrade their controls only
WHERE: Startup, periodic tick, explicit refresh and before a stop dispatch
HOW: Protected reads; accept native booleans only; log changed labels once
WHEN: Outside the render callback
]]
function readiness.refresh()
    for _, row in ipairs(rows) do
        local ok, value = pcall(readLoaded, row.name)
        local label = 'Unknown'
        if ok and value == true then label = 'Loaded' end
        if ok and value == false then label = 'Not loaded' end
        row.known = ok and (value == true or value == false)
        row.loaded = row.known and value == true or false
        row.detail = (not ok) and tostring(value) or
            ((not row.known) and 'No Boolean result; availability not assumed.' or '')
        if row.label ~= label or lastRefresh == nil then
            record(row.name .. ': ' .. label)
        end
        row.label = label
    end
    lastRefresh = mq.gettime()
    refreshRequested = false
end

--[[
FUNCTION: readiness.initialize()
WHAT: Verify ImGui bindings and collect startup plugin status
WHY: Explain a missing core binding before UI loading fails generically
WHERE: init.lua immediately before its UI require
HOW: Protected require and plugin refresh; return binding success and error
WHEN: Once per package start
]]
function readiness.initialize()
    local ok, result = pcall(loadBindings)
    bindingsAvailable = ok and result ~= nil and result ~= false
    if bindingsAvailable then bindingsError = nil else bindingsError = tostring(result) end
    record(bindingsAvailable and 'ImGui Lua bindings available.' or
        ('ImGui Lua bindings unavailable: ' .. tostring(bindingsError)))
    readiness.refresh()
    return bindingsAvailable, bindingsError
end

--[[
FUNCTION: readiness.getRows()
WHAT: Return cached plugin rows
WHY: Rendering must not repeatedly inspect or change plugins
WHERE: Startup Readiness UI panel
HOW: Return the read-only-by-convention cached array
WHEN: Visible panel rendering
]]
function readiness.getRows()
    return rows
end

--[[
FUNCTION: readiness.bindingsReady()
WHAT: Report the core ImGui initialization result
WHY: Display bindings separately from plugin inventory
WHERE: Startup Readiness panel
HOW: Return the protected require result
WHEN: Rendering after initialization
]]
function readiness.bindingsReady()
    return bindingsAvailable
end

--[[
FUNCTION: readiness.isLoaded(name)
WHAT: Return confirmed cached availability
WHY: Unknown telemetry must not authorize optional commands
WHERE: UI gating and movement cancellation dispatch
HOW: Require an allowlisted row with a known true loaded flag
WHEN: Before enabling or dispatching a dependent action
]]
function readiness.isLoaded(name)
    local row = lookup[name]
    return row ~= nil and row.known and row.loaded == true
end

--[[
FUNCTION: readiness.stopCount()
WHAT: Count available movement-cancellation components
WHY: Permit best-effort emergency stops even if one component is absent
WHERE: Stop All Movement button and readiness summary
HOW: Count the three confirmed optional plugins independently
WHEN: Rendering cached readiness
]]
function readiness.stopCount()
    local count = 0
    for _, row in ipairs(rows) do
        if row.loadable and readiness.isLoaded(row.name) then count = count + 1 end
    end
    return count
end

--[[
FUNCTION: readiness.requestRefresh()
WHAT: Queue a new read-only inventory sample
WHY: Keep plugin reads outside the ImGui callback
WHERE: Refresh readiness button
HOW: Set one request flag
WHEN: Only after an explicit operator click
]]
function readiness.requestRefresh()
    refreshRequested = true
end

--[[
FUNCTION: readiness.requestLoad(name)
WHAT: Queue an explicit allowlisted optional-plugin load
WHY: Provide documented recovery without automatic loading or arbitrary commands
WHERE: Load buttons in the readiness panel
HOW: Validate one of three loadable names; deduplicate requests; record intent
WHEN: Only after the corresponding operator click
]]
function readiness.requestLoad(name)
    local row = lookup[name]
    if not row or not row.loadable then return false end
    if readiness.isLoaded(name) or loadRequests[name] then return false end
    loadRequests[name] = true
    record('Operator requested /plugin ' .. name .. ' load noauto; result pending.')
    return true
end

--[[
FUNCTION: sendLoad(name)
WHAT: Dispatch the documented session-only load command
WHY: Separate actual side effects from rendering
WHERE: tick through pcall
HOW: Send /plugin <allowlisted name> load noauto
WHEN: Only for a queued operator request
]]
local function sendLoad(name)
    mq.cmd('/plugin ' .. name .. ' load noauto')
end

--[[
FUNCTION: readiness.tick()
WHAT: Dispatch queued loads and poll inventory
WHY: Keep side effects out of rendering and notice manual plugin changes
WHERE: ui.tick before processing manual safety actions
HOW: Consume queued names once; refresh after requests or at one-second intervals
WHEN: Every main-loop pass; no game-state condition queues a load
]]
function readiness.tick()
    local attempted = false
    for _, row in ipairs(rows) do
        if loadRequests[row.name] then
            loadRequests[row.name] = nil
            if not readiness.isLoaded(row.name) then
                local ok, err = pcall(sendLoad, row.name)
                record(ok and ('Load command dispatched for ' .. row.name .. '; see inventory for result.') or
                    ('Load command failed for ' .. row.name .. ': ' .. tostring(err)))
                attempted = true
            end
        end
    end
    if attempted or refreshRequested or lastRefresh == nil or mq.gettime() - lastRefresh >= 1000 then
        readiness.refresh()
    end
end

--[[
FUNCTION: readiness.drainEvents()
WHAT: Transfer and clear pending readiness history
WHY: Prevent repeated log entries on subsequent ticks
WHERE: ui.tick after readiness.tick
HOW: Return the bounded array and replace it with an empty queue
WHEN: Once per main-loop pass
]]
function readiness.drainEvents()
    local pending = events
    events = {}
    return pending
end

return readiness
--[[
FOOTER: readiness.lua
EXPORTS: initialize, refresh, getRows, bindingsReady, isLoaded, stopCount,
requestRefresh, requestLoad, tick, drainEvents.
HARD BINDING: mq runtime and ImGui Lua module; no fictitious ImGui plugin.
OPTIONAL STOP COMPONENTS: MQ2EasyFind, MQ2Nav, MQ2MoveUtils.
OBSERVATION: MQ2Melee presence is not proof of activity or an actual conflict.
BOUNDARIES: No mesh/path validation, automatic loading/unloading, movement start,
casting, targeting, combat or plugin configuration edits. noauto avoids changing
MacroQuest.ini's plugin autoload list; plugins may run their own initialization.
Unknown plugin results stay unknown and do not enable dependent stop commands.
VERSION: Candidate 0.3.6; local client testing is required before publishing.
END OF FILE
]]--
