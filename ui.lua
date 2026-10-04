--[[==========================================================================
  FILE        : magfarm/ui.lua
  PACKAGE     : MagFarm Lua  (MacroQuest / EverQuest)
  VERSION     : 0.1.0
  CHANGES     : 0.1.0  Initial non-blocking control/status window.

  WHAT  : Renders MagFarm's ImGui controls, live status, spell roles, settings,
          Spell Acquisition preview, and rolling log.
  WHY   : Operators need visible, explainable automation states and safe controls
          without putting game jobs or waits inside an ImGui callback.
  WHERE : Registered by init.lua through mq.imgui.init.
  HOW   : Reads runtime/config/module status and requests actions through state.
  WHEN  : Every client frame while the window is visible.
==========================================================================]]--

local mq = require('mq') -- Current character/zone display TLOs.
local ImGui = require('ImGui') -- MacroQuest immediate-mode UI library.
local config = require('magfarm.config') -- Persistent settings fields.
local runtime = require('magfarm.runtime') -- State, status, and log.
local state = require('magfarm.state') -- Requested actions only.
local spells = require('magfarm.spells') -- Role display.
local assist = require('magfarm.assist') -- Group/Main Assist display.
local pet = require('magfarm.pet') -- Pet display.
local merc = require('magfarm.merc') -- Mercenary display.
local follow = require('magfarm.follow') -- Follow display.
local acquisition = require('magfarm.spell_acquisition') -- Acquisition preview display.
local ui = {} -- Module export table.

-- WHAT : Window visibility flag.
-- WHY  : Closing window should not stop package work or lose state.
-- WHERE: Read by ui.render and command toggle.
-- HOW  : Passed to ImGui.Begin and returned by it.
-- WHEN  : Toggled by UI close control or `/magfarm`.
ui.open = true -- Show window on first run.

--[[--------------------------------------------------------------------------
  ui.tooltip(text)

  WHAT  : Shows hover help for the most recently drawn control.
  WHY   : Settings need future-proof explanation at their point of use.
  WHERE : Called after controls in this file.
  HOW   : Opens a wrapped tooltip only while the item is hovered.
  WHEN  : Every render frame when a control is hovered.
----------------------------------------------------------------------------]]
function ui.tooltip(text)
    if not text or text == '' or not ImGui.IsItemHovered() then return end -- Avoid empty/non-hover work.
    ImGui.BeginTooltip() -- Start tooltip scope.
    ImGui.PushTextWrapPos(ImGui.GetFontSize() * 28) -- Keep long explanations readable.
    ImGui.TextUnformatted(text) -- Render unformatted user-facing help.
    ImGui.PopTextWrapPos() -- Restore wrap setting.
    ImGui.EndTooltip() -- Close tooltip scope.
end

--[[--------------------------------------------------------------------------
  ui.drawControls()

  WHAT  : Draws Start/Stop/Pause/Resume/Camp/Save buttons.
  WHY   : Lifecycle actions should remain visible regardless of active tab.
  WHERE : Called by ui.render above the tab bar.
  HOW   : Buttons call state functions; no button waits or runs a job itself.
  WHEN  : Every visible frame.
----------------------------------------------------------------------------]]
function ui.drawControls()
    if runtime.running then -- Running state exposes Stop and Pause/Resume.
        if ImGui.Button('Stop') then state.stop('UI button') end -- Request safe stop.
        ImGui.SameLine() -- Keep controls compact.
        if runtime.state == runtime.STATE.PAUSED then if ImGui.Button('Resume') then state.resume() end else if ImGui.Button('Pause') then state.pause('UI button') end end -- Choose correct lifecycle action.
    else -- Idle state exposes Start.
        if ImGui.Button('Start') then state.start() end -- Request preflight/start.
        ImGui.SameLine() -- Keep next action adjacent.
        ImGui.BeginDisabled() ImGui.Button('Pause') ImGui.EndDisabled() -- Show unavailable pause transparently.
    end
    ImGui.SameLine() -- Put camp on same row.
    if ImGui.Button('Set Camp Here') then state.setCamp() end -- Capture explicit camp anchor.
    ui.tooltip('Save the current Y/X/Z location as the Camp mode anchor.') -- Explain camp capture.
    ImGui.SameLine() -- Keep save accessible.
    if ImGui.Button('Save Settings') then config.save() end -- Persist current settings.
end

--[[--------------------------------------------------------------------------
  ui.drawStatus()

  WHAT  : Draws state, mode, character, zone, camp, and safety summary lines.
  WHY   : Operators need an immediate answer to “what is it doing and why?”.
  WHERE : Called by ui.render under the controls.
  HOW   : Reads cached module/runtime facts; does not issue game commands.
  WHEN  : Every visible frame.
----------------------------------------------------------------------------]]
function ui.drawStatus()
    ImGui.Text(string.format('State: %s', runtime.state)) -- Show exact state-machine label.
    ImGui.SameLine() ImGui.TextDisabled(string.format('Mode: %s', runtime.mode)) -- Show requested mode.
    ImGui.Text(string.format('Character: %s (%s)  Level: %d', mq.TLO.Me.CleanName() or '?', mq.TLO.Me.Class.ShortName() or '?', mq.TLO.Me.Level() or 0)) -- Show key context.
    ImGui.Text(string.format('Zone: %s', mq.TLO.Zone.Name() or '?')) -- Show current zone.
    if runtime.camp then ImGui.Text(string.format('Camp: Y %.1f X %.1f Z %.1f', runtime.camp.y, runtime.camp.x, runtime.camp.z)) else ImGui.TextDisabled('Camp: not set') end -- Show explicit camp status.
    ImGui.TextWrapped('Status: ' .. (runtime.status or '')) -- Explain current behavior/failure.
    if assist.status.grouped and not assist.status.valid then ImGui.TextColored(1.0, 0.35, 0.25, 1.0, 'GROUP WARNING: ' .. assist.status.warning) end -- Emphasize group safety lockout.
end

--[[--------------------------------------------------------------------------
  ui.drawModeTab()

  WHAT  : Draws mode and follow-leader configuration controls.
  WHY   : Movement/camp intent must be explicit and visible.
  WHERE : Called from ui.render tab bar.
  HOW   : Uses radio buttons and text input bound to config.settings.
  WHEN  : Every frame while Mode tab is active.
----------------------------------------------------------------------------]]
function ui.drawModeTab()
    if not ImGui.BeginTabItem('Mode') then return end -- Skip inactive tab work.
    ImGui.Text('Operating mode') -- Tab heading.
    for _, mode in ipairs({ 'manual', 'camp', 'follow' }) do -- Render supported choices.
        if ImGui.RadioButton(mode:sub(1,1):upper() .. mode:sub(2), config.settings.mode == mode) then state.setMode(mode) end -- Update selected mode.
        ImGui.SameLine() -- Put choices on one row.
    end
    ImGui.NewLine() -- End radio row cleanly.
    ImGui.SetNextItemWidth(220) -- Give leader field practical width.
    local leader, changed = ImGui.InputText('Follow leader', config.settings.followLeader or '') -- Read editable leader name.
    if changed then config.settings.followLeader = leader end -- Store current text.
    ui.tooltip('Clean name of a current group member. Follow movement remains preview-only until MQ2Nav command behavior is verified.') -- Explain staging.
    ImGui.SetNextItemWidth(160) -- Size numeric field.
    local desired, desiredChanged = ImGui.SliderInt('Desired follow distance', config.settings.followDistance, 5, 200) -- Edit future follow spacing.
    if desiredChanged then config.settings.followDistance = desired config.validate() end -- Validate related thresholds.
    ImGui.SetNextItemWidth(160) -- Size numeric field.
    local repath, repathChanged = ImGui.SliderInt('Repath distance', config.settings.followRepathDistance, 5, 400) -- Edit future repath boundary.
    if repathChanged then config.settings.followRepathDistance = repath config.validate() end -- Preserve hysteresis.
    ImGui.Separator() -- Divide settings from live facts.
    ImGui.Text(string.format('Follow status: %s', follow.status.reason or '')) -- Explain current leader resolution.
    if follow.status.name ~= '' then ImGui.Text(string.format('Leader: %s  Distance: %.0f', follow.status.name, follow.status.distance or -1)) end -- Show resolved leader.
    ImGui.EndTabItem() -- Close active tab.
end

--[[--------------------------------------------------------------------------
  ui.drawSpellsTab()

  WHAT  : Shows role selections, overrides, recommendations, and acquisition scan.
  WHY   : Spell changes should be transparent and operator-controlled.
  WHERE : Called from ui.render tab bar.
  HOW   : Renders CATALOG roles, per-role text overrides, and scan buttons.
  WHEN  : Every frame while Spells tab is active.
----------------------------------------------------------------------------]]
function ui.drawSpellsTab()
    if not ImGui.BeginTabItem('Spells') then return end -- Skip inactive tab work.
    if ImGui.Button('Refresh Spells') then spells.detect() end -- Request explicit book scan.
    ImGui.SameLine() -- Keep acquisition action nearby.
    if ImGui.Button('Scan Vendor and Inventory') then state.requestAcquisitionScan() end -- Start safe preview workflow.
    ui.tooltip('Pauses normal workflow and creates a scan-only Spell Acquisition preview in version 0.1.') -- Explain no-spend safety.
    ImGui.Separator() -- Separate actions from role list.
    for role, descriptor in pairs(spells.selected) do -- Render each current role.
        local label = role:gsub('(%l)(%u)', '%1 %2') -- Make camelCase readable.
        ImGui.Text(string.format('%s: %s (%s)', label, descriptor.name or 'none found', descriptor.source)) -- Show current selection/source.
        ImGui.SameLine() -- Put override field beside selection.
        ImGui.SetNextItemWidth(220) -- Give override field space.
        local override, changed = ImGui.InputText('##override_' .. role, config.settings.spellOverrides[role] or '') -- Read hidden-ID override input.
        if changed then config.settings.spellOverrides[role] = override end -- Store typed override.
        ui.tooltip('Leave blank for best-first auto detection. A typed override must be scribed to be selected.') -- Explain override precedence.
        local recommendation = spells.recommendations[role] -- Look for an auto-detected change.
        if recommendation then ImGui.SameLine() ImGui.TextColored(0.95, 0.80, 0.25, 1.0, string.format('recommended: %s', recommendation.to)) end -- Surface review item.
    end
    ImGui.Separator() -- Separate roles from acquisition preview.
    ImGui.Text('Spell Acquisition preview') -- Attribution-related feature section heading.
    ImGui.TextWrapped(acquisition.plan.message or '') -- Explain most recent scan result.
    ImGui.Text(string.format('Merchant open: %s | Range: %d-%d | Spending cap: %d pp', acquisition.plan.merchantOpen and 'yes' or 'no', acquisition.plan.minLevel or 0, acquisition.plan.maxLevel or 0, acquisition.plan.spendCap or 0)) -- Show plan context.
    for _, item in ipairs(acquisition.plan.skipped or {}) do ImGui.TextDisabled('• ' .. item) end -- Show intentional/explained skips.
    ImGui.TextDisabled('Credits: scribe.mac by Sym; source updates credited to Chatwiththisname, Lemons, and Sic. See ATTRIBUTION.md.') -- Preserve visible provenance.
    ImGui.EndTabItem() -- Close active tab.
end

--[[--------------------------------------------------------------------------
  ui.drawPolicyTab()

  WHAT  : Displays live group, pet, and mercenary policy status.
  WHY   : The operator must see why offense/taunt/merc behavior is constrained.
  WHERE : Called from ui.render tab bar.
  HOW   : Renders cached descriptors with no command side effects.
  WHEN  : Every frame while Policy tab is active.
----------------------------------------------------------------------------]]
function ui.drawPolicyTab()
    if not ImGui.BeginTabItem('Policy') then return end -- Skip inactive tab work.
    ImGui.Text('Group / Main Assist') -- Group section heading.
    ImGui.Text(string.format('Grouped: %s', assist.status.grouped and 'yes' or 'no')) -- Show group condition.
    ImGui.Text(string.format('Main Assist valid: %s', assist.status.valid and 'yes' or 'no')) -- Show safe MA status.
    if assist.status.warning ~= '' then ImGui.TextWrapped('Warning: ' .. assist.status.warning) end -- Explain lockout.
    ImGui.Separator() -- Divide pet status.
    ImGui.Text('Pet') -- Pet heading.
    ImGui.Text(string.format('Pet: %s  HP: %d%%', pet.status.name ~= '' and pet.status.name or 'none', pet.status.hp or 0)) -- Show pet facts.
    local tauntText = pet.status.desiredTaunt == nil and 'unchanged' or (pet.status.desiredTaunt and 'ON' or 'OFF') -- Format nullable policy.
    ImGui.Text(string.format('Desired taunt: %s — %s', tauntText, pet.status.reason or '')) -- Explain desired policy.
    ImGui.Separator() -- Divide mercenary status.
    ImGui.Text('Mercenary') -- Merc heading.
    ImGui.Text(string.format('Merc: %s  Class: %s  HP: %d%%', merc.status.name ~= '' and merc.status.name or 'none', merc.status.class or '', merc.status.hp or 0)) -- Show merc facts.
    ImGui.TextWrapped('Policy: ' .. (merc.status.policy or '')) -- Explain staged merc behavior.
    ImGui.TextDisabled('Pet and mercenary commands are intentionally not issued in 0.1 until verified on this client/server.') -- Keep scope clear.
    ImGui.EndTabItem() -- Close active tab.
end

--[[--------------------------------------------------------------------------
  ui.drawSettingsTab()

  WHAT  : Draws core safety/settings controls needed in the foundation.
  WHY   : Makes defaults reviewable before later behavior is enabled.
  WHERE : Called from ui.render tab bar.
  HOW   : Uses checkboxes/sliders directly bound to config.settings and validates
          relationships after numeric changes.
  WHEN  : Every frame while Settings tab is active.
----------------------------------------------------------------------------]]
function ui.drawSettingsTab()
    if not ImGui.BeginTabItem('Settings') then return end -- Skip inactive tab work.
    local debug, changedDebug = ImGui.Checkbox('Debug trace', config.settings.debug == true) -- Edit debug setting.
    if changedDebug then config.settings.debug = debug end -- Persist in-memory value.
    local groupAssist, changedGroup = ImGui.Checkbox('Use group Main Assist policy', config.settings.useGroupAssist == true) -- Edit ownership policy.
    if changedGroup then config.settings.useGroupAssist = groupAssist end -- Store change.
    local requireMA, changedMA = ImGui.Checkbox('Require valid Main Assist when grouped', config.settings.requireMainAssist == true) -- Edit safety lockout.
    if changedMA then config.settings.requireMainAssist = requireMA end -- Store change.
    local petTaunt, changedPet = ImGui.Checkbox('Manage pet taunt policy', config.settings.managePetTaunt == true) -- Edit future pet control policy.
    if changedPet then config.settings.managePetTaunt = petTaunt end -- Store change.
    local mercManage, changedMerc = ImGui.Checkbox('Manage mercenary policy', config.settings.manageMercenary == true) -- Edit future merc policy.
    if changedMerc then config.settings.manageMercenary = mercManage end -- Store change.
    ImGui.SetNextItemWidth(160) -- Size assist gate slider.
    local assistPct, changedAssist = ImGui.SliderInt('Assist at target HP %', config.settings.assistAtPct, 1, 100) -- Edit future assist gate.
    if changedAssist then config.settings.assistAtPct = assistPct config.validate() end -- Store and validate.
    ImGui.SetNextItemWidth(160) -- Size self-defense slider.
    local defensePct, changedDefense = ImGui.SliderInt('Self-defense at my HP %', config.settings.selfDefenseAtPct, 1, 99) -- Edit future emergency gate.
    if changedDefense then config.settings.selfDefenseAtPct = defensePct config.validate() end -- Store and validate paired recovery.
    ImGui.SetNextItemWidth(160) -- Size release slider.
    local releasePct, changedRelease = ImGui.SliderInt('Self-defense recovery HP %', config.settings.selfDefenseReleasePct, 1, 100) -- Edit future release threshold.
    if changedRelease then config.settings.selfDefenseReleasePct = releasePct config.validate() end -- Preserve hysteresis.
    ImGui.Separator() -- Divide acquisition settings.
    ImGui.Text('Spell Acquisition') -- Acquisition heading.
    ImGui.SetNextItemWidth(160) -- Size spending cap field.
    local spend, changedSpend = ImGui.InputInt('Maximum platinum', config.settings.acquisitionMaxSpendPlat, 1, 100) -- Edit future hard cap.
    if changedSpend then config.settings.acquisitionMaxSpendPlat = spend config.validate() end -- Store safe cap.
    ImGui.TextDisabled('Execution remains disabled in 0.1 regardless of settings.') -- Reinforce version scope.
    ImGui.EndTabItem() -- Close active tab.
end

--[[--------------------------------------------------------------------------
  ui.drawLogTab()

  WHAT  : Renders the bounded runtime activity log.
  WHY   : Lets future-you see decisions that happened while away from keyboard.
  WHERE : Called from ui.render tab bar.
  HOW   : Prints cached runtime lines in a scrollable child region.
  WHEN  : Every frame while Log tab is active.
----------------------------------------------------------------------------]]
function ui.drawLogTab()
    if not ImGui.BeginTabItem('Log') then return end -- Skip inactive tab work.
    if ImGui.BeginChild('magfarm_log', 0, 260, true) then -- Create scrollable log pane.
        for _, line in ipairs(runtime.log) do ImGui.TextWrapped(line) end -- Render chronological history.
        ImGui.EndChild() -- Close child pane.
    end
    if ImGui.Button('Clear Log') then runtime.log = {} end -- Allow operator cleanup.
    ImGui.SameLine() ImGui.TextDisabled(string.format('%d / %d lines', #runtime.log, runtime.LOG_MAX)) -- Show bounded capacity.
    ImGui.EndTabItem() -- Close active tab.
end

--[[--------------------------------------------------------------------------
  ui.render()

  WHAT  : Draws one complete MagFarm UI frame.
  WHY   : MacroQuest ImGui requires a single callback that returns quickly.
  WHERE : Registered by init.lua.
  HOW   : Opens window, draws controls/status/tabs, and always closes ImGui.Begin.
  WHEN  : Every frame while ui.open is true.
----------------------------------------------------------------------------]]
function ui.render()
    if not ui.open then return end -- Hidden window does not draw but package continues.
    ImGui.SetNextWindowSize(640, 620, ImGuiCond.FirstUseEver) -- Provide useful first-run dimensions.
    local draw -- Capture Begin's body-draw flag.
    draw, ui.open = ImGui.Begin('MagFarm##magfarm', ui.open) -- Begin stable-ID window.
    if draw then -- Draw contents only when not collapsed/clipped.
        ui.drawControls() -- Always-visible lifecycle controls.
        ImGui.Separator() -- Visual boundary.
        ui.drawStatus() -- Always-visible runtime explanation.
        ImGui.Separator() -- Visual boundary.
        if ImGui.BeginTabBar('magfarm_tabs') then -- Organize larger controls.
            ui.drawModeTab() -- Mode/follow settings.
            ui.drawSpellsTab() -- Spell roles/acquisition preview.
            ui.drawPolicyTab() -- Group/pet/merc policy facts.
            ui.drawSettingsTab() -- Foundation settings.
            ui.drawLogTab() -- History.
            ImGui.EndTabBar() -- Close tab bar.
        end
    end
    ImGui.End() -- Always match Begin, even when body was not drawn.
end

return ui -- Export ImGui callback module.

--[[==========================================================================
  END OF FILE : magfarm/ui.lua

  EXPORTS
    open            Window visibility.
    tooltip(text)   Hover help helper.
    render()        MacroQuest ImGui frame callback.

  DEPENDENCIES : mq, ImGui, and MagFarm state/config/runtime/status modules.

  HOW TO EDIT SAFELY
    - Never call mq.delay or execute a multi-step game job from this file.
    - Request actions through state.lua and display results from runtime/module caches.
    - Always match ImGui.Begin with ImGui.End.
==========================================================================]]--
