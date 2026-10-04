--[[==========================================================================
  FILE        : magfarm/spell_acquisition.lua
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Scan-only, attributed foundation.

  BASED ON    : scribe.mac by Sym (September 4, 2012).
  SOURCE UPDATE CREDITS RECORDED IN scribe.mac:
                Chatwiththisname (2018), Lemons (2020 emulator support),
                Sic (2021 duplicate-purchase correction).

  WHAT  : Builds a read-only preview of eligible spell-scroll activity from an
          open merchant and current inventory.
  WHY   : Provides a safe first integration of credited scribe.mac workflow
          before client-specific purchase/scribe UI controls are enabled.
  WHERE : Required by state.lua and ui.lua.
  HOW   : Checks merchant visibility, spellbook state, configured level range,
          and reports preview limitations; execution is deliberately disabled.
  WHEN  : On /magfarm acquire scan or the UI Scan button.
==========================================================================]]--

local mq = require('mq') -- Merchant and character TLO access.
local config = require('magfarm.config') -- Level/spending/preview settings.
local runtime = require('magfarm.runtime') -- Job state and log.
local spells = require('magfarm.spells') -- Spellbook checks and post-scan refresh.
local acquisition = {} -- Module export table.

-- WHAT : Latest scan plan descriptor.
-- WHY  : UI needs one safe result object independent of merchant command logic.
-- WHERE: Set by acquisition.scan and read by ui.lua.
-- HOW  : Plain table with plan counts/messages.
-- WHEN  : Replaced for every explicit scan.
acquisition.plan = { merchantOpen = false, buy = {}, scribe = {}, skipped = {}, message = 'No scan performed.' } -- Safe initial display.

--[[--------------------------------------------------------------------------
  acquisition.maxLevel()

  WHAT  : Resolves configured maximum spell level, where zero means Me.Level.
  WHY   : Mirrors scribe.mac convenience while retaining explicit settings.
  WHERE : Called by acquisition.scan.
  HOW   : Uses setting when positive, otherwise reads character level.
  WHEN  : Each acquisition scan.
----------------------------------------------------------------------------]]
function acquisition.maxLevel()
    if (config.settings.acquisitionMaxLevel or 0) > 0 then return config.settings.acquisitionMaxLevel end -- Honor explicit cap.
    return mq.TLO.Me.Level() or 1 -- Default to current character level.
end

--[[--------------------------------------------------------------------------
  acquisition.scan()

  WHAT  : Creates a scan-only merchant/inventory acquisition preview.
  WHY   : Lets the operator inspect environment and planned workflow safely
          before spending platinum or consuming scrolls is enabled.
  WHERE : Called by state.requestAcquisitionScan and UI/command actions.
  HOW   : Detects merchant state, records configured bounds, refreshes spells,
          and emits a clearly non-executing plan result.
  WHEN  : Only on explicit operator request.
----------------------------------------------------------------------------]]
function acquisition.scan()
    local merchantOpen = mq.TLO.Merchant.Open() == true -- Read current merchant window state.
    local plan = { merchantOpen = merchantOpen, buy = {}, scribe = {}, skipped = {}, minLevel = config.settings.acquisitionMinLevel, maxLevel = acquisition.maxLevel(), spendCap = config.settings.acquisitionMaxSpendPlat, previewOnly = true } -- Build safe fresh plan.
    if merchantOpen then plan.message = string.format('Merchant "%s" detected. Scan-only preview is ready; purchase execution is disabled in 0.1.', mq.TLO.Merchant.Name() or 'unknown') else plan.message = 'No merchant window open. Inventory/spellbook preview only; open a vendor before a vendor scan.' end -- Explain exact environment.
    spells.detect() -- Refresh known spells so later plan logic starts current.
    table.insert(plan.skipped, 'Vendor purchase and inventory scribing are intentionally disabled until client UI paths are verified in-game.') -- Keep scope visible.
    acquisition.plan = plan -- Publish UI result.
    runtime.note('Spell Acquisition scan: merchant %s, levels %d-%d, preview only.', merchantOpen and 'open' or 'closed', plan.minLevel, plan.maxLevel) -- Preserve scan audit trail.
    return plan -- Let caller inspect immediate result.
end

return acquisition -- Export acquisition scan service.

--[[==========================================================================
  END OF FILE : magfarm/spell_acquisition.lua

  EXPORTS
    plan          Latest scan-preview descriptor.
    maxLevel()    Resolve configured max level.
    scan()        Build scan-only acquisition preview.

  DEPENDENCIES : mq, magfarm.config, magfarm.runtime, magfarm.spells.

  HOW TO EDIT SAFELY
    - Keep attribution above when extending this adapted feature.
    - Add buy/scribe execution only after vendor rows, cursor behavior, scroll
      scribing, and confirmation dialogs are tested on the target client.
==========================================================================]]--
