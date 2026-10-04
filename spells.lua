--[[==========================================================================
  FILE        : magfarm/spells.lua
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial role detection and recommendation foundation.

  WHAT  : Scans the Magician spellbook, selects known spells for documented
          roles, honors manual overrides, and reports upgrade candidates.
  WHY   : Any-level support must select only spells the character actually knows
          rather than rely on the level-106 names in the historical macro.
  WHERE : Required by state.lua, spell_acquisition.lua, and ui.lua.
  HOW   : Each role has a best-first candidate list; first known spell wins
          unless a valid saved override exists.
  WHEN  : At startup, /magfarm spells, and after spell acquisition scans.
==========================================================================]]--

local mq = require('mq') -- Spellbook TLO access.
local config = require('magfarm.config') -- Role overrides and future gem settings.
local runtime = require('magfarm.runtime') -- Operator log/status.
local utils = require('magfarm.utils') -- Debug and safe helpers.
local spells = {} -- Module export table.

-- WHAT : Best-first known-name candidates per Magician role.
-- WHY  : Curated roles are safer than guessing spell purpose from a name/effect.
-- WHERE: Read by spells.detect through spells.pick.
-- HOW  : Add future/new-server spell names above older candidates.
-- WHEN  : Evaluated on each spellbook scan.
spells.CATALOG = {
    primaryNuke = { 'Volley of Sand', 'Bolt of Skyfire', 'Meteoric Bolt Rk. II' }, -- Historical source examples retained as initial placeholders.
    secondaryNuke = { 'Meteoric Bolt Rk. II', 'Bolt of Skyfire', 'Volley of Sand' }, -- Separate role enables later curated rotation refinement.
    fastNuke = {}, -- Intentionally empty until verified Magician family data is added.
    debuff = { 'Malosinata' }, -- Historical resist-debuff example.
    petHaste = { 'Burnout XIII' }, -- Historical pet-haste example.
    petWeapon = { 'Iceflame Armaments' }, -- Historical pet armament example.
    petDefense = { 'Arcane Distillect' }, -- Historical pet defense example.
    selfDefense = { 'Shieldstone Bodyguard Rk. II', 'Praetorian Guardian Rk. II' }, -- Historical self-defense examples.
    waterPet = { 'Convocation of Water' }, -- Historical selected pet example.
} -- This is deliberately conservative until live spellbook validation expands it.

-- WHAT : Current selected spell names by role.
-- WHY  : UI and policy modules need cached scan results without scanning every frame.
-- WHERE: Set by spells.detect and read by ui/state.
-- HOW  : Plain role-keyed table.
-- WHEN  : Replaced each scan.
spells.selected = {} -- Empty until first detection.

-- WHAT : Detected better candidates compared to prior selected values.
-- WHY  : Makes newly scribed configured spells visible without silent rotation changes.
-- WHERE: Set by spells.detect and displayed by UI.
-- HOW  : Plain role-keyed table of recommendation descriptors.
-- WHEN  : Rebuilt each scan.
spells.recommendations = {} -- No recommendations before first scan.

--[[--------------------------------------------------------------------------
  spells.inBook(name)

  WHAT  : Returns true when a nonempty exact spell name is currently scribed.
  WHY   : Every role and override decision must use only spells actually known.
  WHERE : Called by pick and override validation.
  HOW   : Uses Me.Book exact-name lookup with a protected nil-safe predicate.
  WHEN  : During spellbook scans.
----------------------------------------------------------------------------]]
function spells.inBook(name)
    return name and name ~= '' and mq.TLO.Me.Book(name)() ~= nil -- MacroQuest returns a book slot when scribed.
end

--[[--------------------------------------------------------------------------
  spells.pick(role)

  WHAT  : Selects one current spell for a role and reports its selection source.
  WHY   : Manual operator intent must override automatic candidate ordering.
  WHERE : Called by spells.detect for every catalog role.
  HOW   : Valid override wins; otherwise first known best-first candidate wins.
  WHEN  : Each spellbook scan.
----------------------------------------------------------------------------]]
function spells.pick(role)
    local override = config.settings.spellOverrides[role] or '' -- Read optional operator-selected name.
    if override ~= '' and spells.inBook(override) then return override, 'override' end -- Keep valid explicit choice.
    for _, name in ipairs(spells.CATALOG[role] or {}) do -- Walk preferred candidates in order.
        if spells.inBook(name) then return name, 'auto' end -- First known candidate is current best configured choice.
    end
    return nil, 'none' -- Absence is valid for low-level or incomplete spellbooks.
end

--[[--------------------------------------------------------------------------
  spells.detect()

  WHAT  : Rebuilds current role selections and recommendation status.
  WHY   : A new scribed spell or changed override must become visible immediately.
  WHERE : Called by state preflight, slash command, acquisition scan, and UI.
  HOW   : Picks every catalog role, compares to prior result, stores metadata,
          and logs selection-source changes.
  WHEN  : On demand; never every UI frame.
----------------------------------------------------------------------------]]
function spells.detect()
    local previous = spells.selected -- Preserve prior scan for recommendation comparison.
    local selected = {} -- Build a fresh role result table.
    local recommendations = {} -- Build a fresh recommendation table.
    for role, _ in pairs(spells.CATALOG) do -- Process every supported documented role.
        local name, source = spells.pick(role) -- Resolve current valid spell.
        selected[role] = { name = name, source = source } -- Store UI-friendly descriptor.
        local prior = previous[role] and previous[role].name or nil -- Find prior selected spell safely.
        if prior and prior ~= name and name and source == 'auto' then recommendations[role] = { from = prior, to = name } end -- Surface an auto-detected upgrade/change.
    end
    spells.selected = selected -- Publish current scan result.
    spells.recommendations = recommendations -- Publish changes for review.
    runtime.note('Spellbook scanned: %d role(s), %d recommendation(s).', (function() local n=0 for _ in pairs(selected) do n=n+1 end return n end)(), (function() local n=0 for _ in pairs(recommendations) do n=n+1 end return n end)()) -- Preserve scan summary.
    utils.debug('Spellbook role scan completed.') -- Optional trace.
    return selected -- Let callers inspect immediate results.
end

--[[--------------------------------------------------------------------------
  spells.summary()

  WHAT  : Returns current role descriptors for UI/status consumers.
  WHY   : Keeps callers from depending on internal table shape later.
  WHERE : Called by ui.lua and state status commands.
  HOW   : Returns selected and recommendations tables.
  WHEN  : Whenever display needs current spell data.
----------------------------------------------------------------------------]]
function spells.summary()
    return spells.selected, spells.recommendations -- Expose current cached scan results.
end

return spells -- Export spellbook services.

--[[==========================================================================
  END OF FILE : magfarm/spells.lua

  EXPORTS
    CATALOG                     Best-first spell candidates by role.
    selected/recommendations    Last scan results.
    inBook(name)                Exact scribed-spell test.
    pick(role)                  Select one role using override/auto policy.
    detect()                    Rescan all roles.
    summary()                   Return cached display data.

  DEPENDENCIES : mq, magfarm.config, magfarm.runtime, magfarm.utils.

  HOW TO EDIT SAFELY
    - Add verified spell names above older names in the correct CATALOG role.
    - Do not add AE, group, or situational spells to a single-target role only
      because they are newer; role suitability matters more than level.
==========================================================================]]--
