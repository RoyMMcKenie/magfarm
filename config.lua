--[[==========================================================================
  FILE        : magfarm/config.lua
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial documented foundation.

  WHAT  : Defines, loads, validates, and saves all persistent MagFarm settings.
  WHY   : A Magician alt, server, and play style need independent remembered
          settings without hardcoding behavior into policy modules.
  WHERE : Required by init, state, UI, and all decision modules.
  HOW   : Merges a character/server Lua settings file with DEFAULTS and repairs
          ranges/relationships before exposing config.settings.
  WHEN  : Loaded at startup, saved on demand and clean shutdown.
==========================================================================]]--

local mq = require('mq') -- MacroQuest config directory and character TLOs.
local utils = require('magfarm.utils') -- Conversion, copying, logging helpers.
local config = {} -- Module export table.

-- WHAT : Complete persisted settings schema.
-- WHY  : One documented location defines every operator-configurable behavior.
-- WHERE: Merged into config.settings by config.load and rendered by UI.
-- HOW  : Plain Lua table with comments grouped by operating concern.
-- WHEN  : Read during load, validation, UI drawing, and save.
config.DEFAULTS = {
    debug = false, -- Print detailed decision trace.
    mode = 'manual', -- Default operator mode: manual, camp, or follow.
    followLeader = '', -- Clean name of preferred follow leader.
    followDistance = 25, -- Desired leader distance for later follow navigation.
    followRepathDistance = 35, -- Distance that would trigger a later repath.
    useGroupAssist = true, -- Respect Main Assist when grouped.
    requireMainAssist = true, -- Disable group offense if no Main Assist resolves.
    assistAtPct = 95, -- Target HP threshold before group assist engages.
    managePetTaunt = true, -- Future role-based pet taunt management.
    tauntWhenSolo = true, -- Desired future solo pet taunt policy.
    tauntWhenMainAssist = true, -- Desired future Magician-Main-Assist taunt policy.
    emergencyPetTaunt = false, -- Optional future Main Assist emergency exception.
    emergencyTauntAtPct = 30, -- Future emergency taunt activation threshold.
    emergencyTauntReleasePct = 50, -- Future emergency taunt recovery threshold.
    manageMercenary = true, -- Enable later mercenary policy when verified.
    damageMercHoldDuringPull = true, -- Future damage-merc pull discipline.
    healerMercHoldDuringPull = true, -- Future healer-merc pull discipline.
    releaseHealerOnSelfDefense = true, -- Future healer emergency release.
    enableSelfHpDefense = true, -- Future active-pull self-defense gate.
    selfDefenseAtPct = 40, -- Future low-HP activation threshold.
    selfDefenseReleasePct = 60, -- Future low-HP recovery threshold.
    campReturnTolerance = 15, -- Future distance at which Magician is back at camp.
    campEngageRadius = 35, -- Future target distance from camp before offense.
    pullSearchRadius = 245, -- Future maximum target search radius.
    spellOverrides = {}, -- Per-role explicit spell names; blank means auto.
    spellGemMap = { primaryNuke = 1, secondaryNuke = 2, fastNuke = 3, debuff = 4 }, -- Future preferred gem map.
    acquisitionMinLevel = 1, -- Spell Acquisition vendor scan lower level bound.
    acquisitionMaxLevel = 0, -- Zero means current character level.
    acquisitionMaxSpendPlat = 250, -- Future execution hard spending cap.
    acquisitionPreviewOnly = true, -- 0.1 safety gate; prevents buy/scribe execution.
} -- New settings must be added here with a comment.

-- WHAT : Live merged settings table.
-- WHY  : All modules need one immediate source of current operator choices.
-- WHERE: Read throughout package after config.load.
-- HOW  : Replaced as a whole on each successful load.
-- WHEN  : Valid after startup.
config.settings = {} -- Empty until config.load runs.

--[[--------------------------------------------------------------------------
  config.path()

  WHAT  : Returns this server/character's settings-file path.
  WHY   : Prevents one Magician's options from changing another's behavior.
  WHERE : Called by config.load and config.save.
  HOW   : Combines mq.configDir with safe server and character names.
  WHEN  : Every settings file read/write.
----------------------------------------------------------------------------]]
function config.path()
    local server = (mq.TLO.EverQuest.Server() or 'server'):gsub('%s+', '') -- Remove unsafe whitespace from server identifier.
    local name = mq.TLO.Me.CleanName() or 'character' -- Use title-free character name.
    return string.format('%s/magfarm_%s_%s.lua', mq.configDir, server, name) -- Match MacroQuest's config-folder convention.
end

--[[--------------------------------------------------------------------------
  config.mergeDefaults(target, defaults)

  WHAT  : Adds any missing default values recursively to loaded settings.
  WHY   : Old saved files must gain new settings after package upgrades.
  WHERE : Called by config.load.
  HOW   : Walks defaults; nested tables merge while scalar gaps receive copies.
  WHEN  : Once per settings load.
----------------------------------------------------------------------------]]
function config.mergeDefaults(target, defaults)
    for key, defaultValue in pairs(defaults) do -- Inspect each supported setting.
        if target[key] == nil then target[key] = utils.deepCopy(defaultValue) -- Seed a missing value safely.
        elseif type(defaultValue) == 'table' and type(target[key]) == 'table' then config.mergeDefaults(target[key], defaultValue) end -- Preserve existing nested choices while adding new keys.
    end
end

--[[--------------------------------------------------------------------------
  config.validate()

  WHAT  : Repairs settings into supported ranges and compatible relationships.
  WHY   : Hand edits and old defaults must never create impossible runtime rules.
  WHERE : Called after load, before save, and after UI edits.
  HOW   : Coerces booleans, clamps numbers, normalizes mode, and enforces paired
          activation/recovery and camp-distance relationships.
  WHEN  : Every configuration lifecycle event.
----------------------------------------------------------------------------]]
function config.validate()
    local s = config.settings -- Short local reference for readable validation.
    s.debug = utils.toBool(s.debug) -- Normalize Debug flag.
    s.useGroupAssist = utils.toBool(s.useGroupAssist) -- Normalize group policy.
    s.requireMainAssist = utils.toBool(s.requireMainAssist) -- Normalize assist lockout policy.
    s.managePetTaunt = utils.toBool(s.managePetTaunt) -- Normalize future pet policy.
    s.manageMercenary = utils.toBool(s.manageMercenary) -- Normalize future merc policy.
    s.acquisitionPreviewOnly = utils.toBool(s.acquisitionPreviewOnly) -- Preserve 0.1 execution safety.
    if s.mode ~= 'manual' and s.mode ~= 'camp' and s.mode ~= 'follow' then s.mode = 'manual' end -- Reject unknown saved modes.
    s.followDistance = utils.clamp(s.followDistance, 5, 200) -- Keep future follow spacing practical.
    s.followRepathDistance = utils.clamp(s.followRepathDistance, s.followDistance, 400) -- Ensure repath threshold is never smaller than desired distance.
    s.assistAtPct = utils.clamp(s.assistAtPct, 1, 100) -- Valid target-health percentage.
    s.emergencyTauntAtPct = utils.clamp(s.emergencyTauntAtPct, 1, 99) -- Keep a recovery value possible.
    s.emergencyTauntReleasePct = utils.clamp(s.emergencyTauntReleasePct, s.emergencyTauntAtPct, 100) -- Enforce taunt hysteresis.
    s.selfDefenseAtPct = utils.clamp(s.selfDefenseAtPct, 1, 99) -- Keep recovery value possible.
    s.selfDefenseReleasePct = utils.clamp(s.selfDefenseReleasePct, s.selfDefenseAtPct, 100) -- Enforce self-defense hysteresis.
    s.campReturnTolerance = utils.clamp(s.campReturnTolerance, 3, 100) -- Supported future camp return range.
    s.campEngageRadius = utils.clamp(s.campEngageRadius, s.campReturnTolerance, 250) -- Target gate must not be smaller than return tolerance.
    s.pullSearchRadius = utils.clamp(s.pullSearchRadius, s.campEngageRadius, 1000) -- Search must reach at least the camp gate.
    s.acquisitionMinLevel = utils.clamp(s.acquisitionMinLevel, 1, 125) -- Safe level range for scan planning.
    s.acquisitionMaxLevel = utils.clamp(s.acquisitionMaxLevel, 0, 125) -- Zero keeps the current-level semantic.
    s.acquisitionMaxSpendPlat = utils.clamp(s.acquisitionMaxSpendPlat, 0, 10000000) -- Avoid nonsensical negative limits.
    if type(s.spellOverrides) ~= 'table' then s.spellOverrides = {} end -- Repair bad hand-edited role data.
    if type(s.spellGemMap) ~= 'table' then s.spellGemMap = utils.deepCopy(config.DEFAULTS.spellGemMap) end -- Repair gem map shape.
end

--[[--------------------------------------------------------------------------
  config.load()

  WHAT  : Loads saved settings, merges defaults, validates them, and binds Debug.
  WHY   : Starts correctly on first run, after upgrades, and after safe recovery
          from a malformed user-edited settings file.
  WHERE : Called once by init.lua startup.
  HOW   : Runs loadfile under pcall, merges DEFAULTS, validates, then publishes.
  WHEN  : Before any module makes a configuration-dependent decision.
----------------------------------------------------------------------------]]
function config.load()
    local loaded = {} -- First-run fallback settings container.
    local chunk = loadfile(config.path()) -- Compile saved table file if it exists.
    if chunk then -- Existing file compiled successfully.
        local ok, data = pcall(chunk) -- Protect startup from runtime errors in hand edits.
        if ok and type(data) == 'table' then loaded = data else utils.echo('\aySettings file invalid; using defaults.') end -- Retain defaults on invalid content.
    end
    config.mergeDefaults(loaded, config.DEFAULTS) -- Add upgrade-time keys without overwriting choices.
    config.settings = loaded -- Publish before validation so helper calls read live data.
    config.validate() -- Repair all values and relationships.
    utils.bindDebugFlag(function() return config.settings.debug == true end) -- Inject Debug reader without a require cycle.
    utils.debug('Settings loaded from %s', config.path()) -- Trace load source when requested.
end

--[[--------------------------------------------------------------------------
  config.save()

  WHAT  : Persists current validated settings to the character/server file.
  WHY   : Operator choices must survive a reload or later play session.
  WHERE : Called by UI Save and init.lua clean shutdown.
  HOW   : Validates then serializes the table through mq.pickle under pcall.
  WHEN  : On explicit request and clean package exit.
----------------------------------------------------------------------------]]
function config.save()
    config.validate() -- Never save malformed settings.
    local ok, err = pcall(mq.pickle, config.path(), config.settings) -- Serialize safely through MacroQuest.
    if not ok then utils.echo('\arCould not save settings: %s', tostring(err)) else utils.debug('Settings saved to %s', config.path()) end -- Report failure only when necessary.
end

return config -- Export persistent configuration services.

--[[==========================================================================
  END OF FILE : magfarm/config.lua

  EXPORTS
    DEFAULTS                 Complete documented settings table.
    settings                 Live merged settings.
    path()                   Per-server/per-character file path.
    mergeDefaults(t,d)       Upgrade-safe default merge.
    validate()               Repair ranges and relationships.
    load() / save()          Persisted settings lifecycle.

  DEPENDENCIES : mq, magfarm.utils.

  HOW TO EDIT SAFELY
    - Add every new persistent option to DEFAULTS with a comment.
    - Add validation here before using numeric or related settings elsewhere.
    - Do not store transient target, pull, or UI state here; use runtime.lua.
==========================================================================]]--
