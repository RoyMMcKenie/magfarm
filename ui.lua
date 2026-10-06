--[[
==============================================================================
FILE    : ui.lua
PACKAGE : MagFarm
VERSION : 0.3.5

WHAT :
Displays the monitor, independent stacked group roles, configurable resource
colours, and a button-accessible persistent Options window.

WHY :
Group roles must be flexible. Resource thresholds must be configurable through
one settings source rather than scattered constants.

WHERE :
Registered by the existing magfarm/init.lua.
Requires magfarm.config, magfarm.state, and magfarm.movement.

HOW :
Captures one snapshot per visible frame. Displays a content-sized roster table.
Options edits configuration only. Explicit manual actions dispatch in tick().

WHEN :
render() runs in ImGui frames; tick() runs in the package loop.

ROLE ORDER :
Leader, Main Tank, Main Assist, Puller, Mark NPC, Master Looter, You.

RESOURCE POLICY :
Known HP/Mana values turn red when strictly below their respective thresholds.
Defaults are 35%. Exactly 35% is not red with a 35% threshold.
Absent or unknown resource values display neutral --.
Remote mana colouring reflects group-reported data, not independent validation.

LAYOUT :
No ScrollX/ScrollY flags or fixed roster-row heights.
Each member row grows only to fit its actual cell contents.

OPTIONS :
Persistent display settings only; writes occur in tick(), not rendering.
Future behavior settings will use separate categories and explicit permissions.

SAFETY :
Only existing explicit Stop All Movement, Pet Back Off, and Pet Follow commands.
No role assignment, automatic engagement, casting, targeting, or Raid TLO reads.
==============================================================================
]]--

local mq = require('mq')
local ImGui = require('ImGui')
local movement = require('magfarm.movement')
local state = require('magfarm.state')
local config = require('magfarm.config')

local ui = {}
ui.open = true

--- Window/session state, separate from game observations.
local optionsOpen = false
local readinessSpell = 'Spear of Molten Arcronite'
local lastAction = 'Monitor active. No automation is enabled.'
local VERSION = '0.3.5'

--- Explicit manual requests consumed by tick().
local stopAllRequested = false
local petBackOffRequested = false
local petFollowRequested = false

--- Bounded history of explicit manual actions and settings diagnostics.
local LOG_MAX = 20
local activityLog = {}

--- Display-only colours.
local COLOR_GOOD = { 0.35, 0.85, 0.40, 1.0 }
local COLOR_WARN = { 0.95, 0.80, 0.30, 1.0 }
local COLOR_BAD = { 1.00, 0.40, 0.35, 1.0 }
local COLOR_INFO = { 0.70, 0.70, 0.70, 1.0 }

--- Role metadata follows the operator's requested display order.
local ROLE_ORDER = {
    { key = 'mainTank', label = 'Main Tank' },
    { key = 'mainAssist', label = 'Main Assist' },
    { key = 'puller', label = 'Puller' },
    { key = 'markNpc', label = 'Mark NPC' },
    { key = 'masterLooter', label = 'Master Looter' },
}

--[[
------------------------------------------------------------------------------
FUNCTION : textColored(color, text)
WHAT : Draws coloured text.
WHY : Centralizes RGBA handling.
WHERE : Status and resource rendering.
HOW : Calls ImGui.TextColored with explicit components.
WHEN : During visible rendering.
------------------------------------------------------------------------------
]]
local function textColored(color, text)
    ImGui.TextColored(color[1], color[2], color[3], color[4], text)
end

--[[
------------------------------------------------------------------------------
FUNCTION : tooltip(text)
WHAT : Explains the preceding item on hover.
WHY : Keeps detail out of the main layout.
WHERE : Buttons, resources, and Options controls.
HOW : Calls ImGui.SetItemTooltip.
WHEN : Immediately after the relevant item.
------------------------------------------------------------------------------
]]
local function tooltip(text)
    ImGui.SetItemTooltip(text)
end

--[[
------------------------------------------------------------------------------
FUNCTION : percentText(value)
WHAT : Formats known percentages or returns --.
WHY : Unknown data must not be rendered as zero.
WHERE : Resource, pet, and target displays.
HOW : Formats numeric values without substituting a numeric fallback.
WHEN : Each resource display.
------------------------------------------------------------------------------
]]
local function percentText(value)
    if type(value) ~= 'number' then
        return '--'
    end
    return string.format('%.0f%%', value)
end

--[[
------------------------------------------------------------------------------
FUNCTION : drawResource(value, key, prefix)
WHAT : Displays a percentage with configurable low-resource colour.
WHY : Local and roster displays must use identical threshold rules.
WHERE : Character HP/Mana and group HP/Mana cells.
HOW : Uses config.get(key); red only for known values strictly below threshold.
WHEN : Each visible resource item.
NOTE : Prefix is optional. Missing values are neutral --.
------------------------------------------------------------------------------
]]
local function drawResource(value, key, prefix)
    local text = (prefix or '') .. percentText(value)

    if type(value) ~= 'number' then
        textColored(COLOR_INFO, text)
    elseif value < config.get(key) then
        textColored(COLOR_BAD, text)
    else
        ImGui.Text(text)
    end
end

--[[
------------------------------------------------------------------------------
FUNCTION : logEvent(message)
WHAT : Records one timestamped manual-action event.
WHY : Provides a bounded audit trail.
WHERE : Request functions and tick().
HOW : Appends using mq.gettime() and trims oldest entries.
WHEN : Manual actions are queued or dispatched.
------------------------------------------------------------------------------
]]
local function logEvent(message)
    table.insert(activityLog, string.format('[%d] %s', mq.gettime(), message))
    while #activityLog > LOG_MAX do
        table.remove(activityLog, 1)
    end
end

--[[
------------------------------------------------------------------------------
FUNCTION : ui.requestStopAllMovement()
WHAT : Queues manual movement cancellation.
WHY : Separates request handling from commands.
WHERE : Safety button and existing slash binding.
HOW : Sets a flag and logs the request.
WHEN : Explicit operator initiation only.
------------------------------------------------------------------------------
]]
function ui.requestStopAllMovement()
    stopAllRequested = true
    lastAction = 'Stop All Movement queued.'
    logEvent('Stop All Movement queued by operator.')
end

--[[
------------------------------------------------------------------------------
FUNCTION : ui.requestPetBackOff()
WHAT : Queues manual pet back-off.
WHY : Provides operator-controlled recovery.
WHERE : Pet button.
HOW : Sets a flag and logs the request.
WHEN : Explicit operator initiation only.
------------------------------------------------------------------------------
]]
function ui.requestPetBackOff()
    petBackOffRequested = true
    lastAction = 'Pet Back Off queued.'
    logEvent('Pet Back Off queued by operator.')
end

--[[
------------------------------------------------------------------------------
FUNCTION : ui.requestPetFollow()
WHAT : Queues manual pet follow.
WHY : Provides recovery without automated movement decisions.
WHERE : Pet button.
HOW : Sets a flag and logs the request.
WHEN : Explicit operator initiation only.
------------------------------------------------------------------------------
]]
function ui.requestPetFollow()
    petFollowRequested = true
    lastAction = 'Pet Follow queued.'
    logEvent('Pet Follow queued by operator.')
end

--[[
------------------------------------------------------------------------------
FUNCTION : ui.tick()
WHAT : Flushes settings, records their diagnostics, and dispatches manual requests.
WHY : Keeps command side effects outside rendering.
WHERE : Existing main loop.
HOW : Flushes, drains settings events once, then invokes queued movement helpers.
WHEN : Each package-loop pass.
SAFETY : No observed state can initiate an action.
------------------------------------------------------------------------------
]]
function ui.tick()
    config.flush()
    -- WHAT: Consume settings results once; WHY: make saves visible in the log.
    -- WHERE: Main-loop tick; HOW: drain the bounded queue; WHEN: after flush.
    for _, event in ipairs(config.drainEvents()) do
        logEvent(event)
    end
    if stopAllRequested then
        stopAllRequested = false
        movement.stopAll()
        lastAction = 'Stop All Movement sent.'
        logEvent('Stop All Movement commands sent.')
    end
    if petBackOffRequested then
        petBackOffRequested = false
        movement.petBackOff()
        lastAction = 'Pet Back Off sent: /pet back off.'
        logEvent('Pet Back Off command sent.')
    end
    if petFollowRequested then
        petFollowRequested = false
        movement.petFollow()
        lastAction = 'Pet Follow sent: /pet follow.'
        logEvent('Pet Follow command sent.')
    end
end

--[[
------------------------------------------------------------------------------
FUNCTION : drawOptions()
WHAT : Draws persistent resource settings in a separate window.
WHY : Establishes an Options UI without crowding the monitor.
WHERE : Called by render() independently of the main window.
HOW : Edits validated numeric settings; balances Begin/End.
WHEN : The operator has opened Options.
SAFETY : Edits display settings only; no game actions.
------------------------------------------------------------------------------
]]
local function drawOptions()
    if not optionsOpen then
        return
    end

    ImGui.SetNextWindowSize(420, 250, ImGuiCond.FirstUseEver)
    local show
    optionsOpen, show = ImGui.Begin('MagFarm Options##magfarm_options', optionsOpen)

    if show then
        ImGui.Text('Resource colours')
        ImGui.TextWrapped(
            'A known value turns red only when below its threshold. ' ..
            'Exactly equal is not red. Valid range: 0 to 100.'
        )

        ImGui.SetNextItemWidth(100)
        local hp = ImGui.InputInt('HP red below (%)', config.get('hpRedBelow'))
        if hp ~= config.get('hpRedBelow') then
            config.set('hpRedBelow', hp)
        end

        ImGui.SetNextItemWidth(100)
        local mana = ImGui.InputInt('Mana red below (%)', config.get('manaRedBelow'))
        if mana ~= config.get('manaRedBelow') then
            config.set('manaRedBelow', mana)
        end

        if ImGui.Button('Reset display defaults') then
            config.reset()
        end

        ImGui.Separator()
        -- WHAT: Show persistence status; WHY: expose failures; WHERE: Options.
        -- HOW: config.status(); WHEN: each visible Options frame.
        ImGui.TextWrapped(config.status())
        ImGui.TextWrapped(
            'Settings are saved per server and character. ' ..
            'Remote mana is group-reported and may be inaccurate. ' ..
            'These colours never trigger actions.'
        )
    end

    ImGui.End()
end

--[[
------------------------------------------------------------------------------
FUNCTION : roleLabels(member)
WHAT : Produces ordered active role labels and explicit unknown markers.
WHY : Supports overlapping roles without treating unknown reads as unassigned.
WHERE : Roles table cell.
HOW : Leader first, ordered role flags, then You; unknown readings get ? labels.
WHEN : Each visible member row.
------------------------------------------------------------------------------
]]
local function roleLabels(member)
    local labels = {}

    if member.isLeader == true then
        table.insert(labels, 'Leader')
    elseif member.isLeader == nil then
        table.insert(labels, 'Leader ?')
    end

    for _, definition in ipairs(ROLE_ORDER) do
        if not member.rolesKnown or
            member.rolesKnown[definition.key] ~= true then
            table.insert(labels, definition.label .. ' ?')
        elseif member.roles[definition.key] == true then
            table.insert(labels, definition.label)
        end
    end

    if member.isSelf then
        table.insert(labels, 'You')
    end

    if #labels == 0 then
        table.insert(labels, '--')
    end

    return labels
end

--[[
------------------------------------------------------------------------------
FUNCTION : rosterStatus(member)
WHAT : Selects reported member status and colour.
WHY : Keeps presence independent of resource warnings.
WHERE : Member Status cell.
HOW : Prioritizes death, explicit absence, unknown presence, then presence.
WHEN : Each member row.
------------------------------------------------------------------------------
]]
local function rosterStatus(member)
    if member.dead == true then
        return 'DEAD', COLOR_BAD
    end
    if member.present == false then
        return 'Not Present', COLOR_WARN
    end
    if member.present == nil then
        return 'Unknown', COLOR_WARN
    end
    if member.dead == nil then
        return 'Present; death ?', COLOR_WARN
    end
    return 'Present', COLOR_GOOD
end

--[[
------------------------------------------------------------------------------
FUNCTION : drawSummary(snapshot)
WHAT : Displays roster totals and exclusive availability counts.
WHY : Gives awareness with the detailed table collapsed.
WHERE : Below header.
HOW : Counts dead first, then known presence, otherwise unavailable; unknown
      presence is included in unavailable for this observational summary.
WHEN : Each visible frame.
------------------------------------------------------------------------------
]]
local function drawSummary(snapshot)
    local total, present, unavailable, dead = 0, 0, 0, 0

    for _, member in ipairs(snapshot.roster.members) do
        total = total + 1
        if member.dead == true then
            dead = dead + 1
        elseif member.present == true then
            present = present + 1
        else
            unavailable = unavailable + 1
        end
    end

    local color = COLOR_INFO
    if dead > 0 then
        color = COLOR_BAD
    elseif unavailable > 0 then
        color = COLOR_WARN
    elseif total > 0 then
        color = COLOR_GOOD
    end

    local leader = snapshot.roster.leaderName
    if leader == '' then leader = 'Unknown' end

    ImGui.PushStyleColor(ImGuiCol.Text, color[1], color[2], color[3], color[4])
    ImGui.TextWrapped(string.format(
        'Group: %d members | %d present | %d unavailable | %d dead | Leader: %s',
        total, present, unavailable, dead, leader
    ))
    ImGui.PopStyleColor()
end

--[[
------------------------------------------------------------------------------
FUNCTION : drawMember(member)
WHAT : Draws seven aligned member cells with stacked roles.
WHY : Preserves compact content-driven rows and independent resource colouring.
WHERE : Inside drawRoster() table.
HOW : Starts a row without explicit height; renders each cell once except roles.
WHEN : Each displayed member.
SAFETY : Read-only; remote red mana reflects reported data only.
------------------------------------------------------------------------------
]]
local function drawMember(member)
    local available = member.present == true
    local hp, mana, distance = nil, nil, '--'
    local class = '--'

    if available then
        hp = member.hpPct
        mana = member.manaPct
        class = member.classShortName or '--'
        if type(member.distance) == 'number' then
            distance = string.format('%.1f', member.distance)
        end
    end

    ImGui.TableNextRow()

    ImGui.TableSetColumnIndex(0)
    ImGui.Text(member.name)

    ImGui.TableSetColumnIndex(1)
    for _, label in ipairs(roleLabels(member)) do
        ImGui.Text(label)
    end

    ImGui.TableSetColumnIndex(2)
    ImGui.Text(class)

    ImGui.TableSetColumnIndex(3)
    drawResource(hp, 'hpRedBelow')

    ImGui.TableSetColumnIndex(4)
    drawResource(mana, 'manaRedBelow')
    if not member.isSelf then
        tooltip(
            'Group-reported mana. Earlier tests found an inaccurate zero ' ..
            'reading. Red means the reported value is below the configured ' ..
            'threshold, not independent confirmation of low mana.'
        )
    end

    ImGui.TableSetColumnIndex(5)
    ImGui.Text(distance)

    ImGui.TableSetColumnIndex(6)
    local text, color = rosterStatus(member)
    textColored(color, text)
end

--[[
------------------------------------------------------------------------------
FUNCTION : drawRoster(snapshot)
WHAT : Draws the content-sized role-aware local-group table.
WHY : Keeps fields aligned and expands rows only for actual role content.
WHERE : Between Character and Pet panels.
HOW : Stable IDs, resizable columns, no scrolling table flags or fixed heights.
WHEN : Roster section is expanded.
NOTE : Roles may remain readable while resource telemetry is unavailable.
------------------------------------------------------------------------------
]]
local function drawRoster(snapshot)
    local roster = snapshot.roster
    local leader = roster.leaderName ~= '' and roster.leaderName or 'Unknown'
    local header = string.format(
        'Group Roster (%d) - Leader: %s###magfarm_group_roster',
        #roster.members, leader
    )

    if not ImGui.CollapsingHeader(header) then return end
    if #roster.members == 0 then
        ImGui.TextWrapped('No occupied local group slots were detected.')
        return
    end

    ImGui.TextWrapped('Roles stack independently. A ? means that role read is unknown.')

    local flags =
        ImGuiTableFlags.BordersInnerV +
        ImGuiTableFlags.RowBg +
        ImGuiTableFlags.Resizable +
        ImGuiTableFlags.SizingFixedFit

    if ImGui.BeginTable('magfarm_group_roster_table', 7, flags) then
        ImGui.TableSetupColumn('Name', ImGuiTableColumnFlags.WidthFixed, 85)
        ImGui.TableSetupColumn('Roles', ImGuiTableColumnFlags.WidthFixed, 105)
        ImGui.TableSetupColumn('Class', ImGuiTableColumnFlags.WidthFixed, 40)
        ImGui.TableSetupColumn('HP', ImGuiTableColumnFlags.WidthFixed, 42)
        ImGui.TableSetupColumn('Mana', ImGuiTableColumnFlags.WidthFixed, 42)
        ImGui.TableSetupColumn('Distance', ImGuiTableColumnFlags.WidthFixed, 65)
        ImGui.TableSetupColumn('Status', ImGuiTableColumnFlags.WidthFixed, 90)
        ImGui.TableHeadersRow()

        for _, member in ipairs(roster.members) do
            drawMember(member)
        end

        ImGui.EndTable()
    end
end

--[[
------------------------------------------------------------------------------
FUNCTION : drawHeader(snapshot)
WHAT : Displays identity, Options access, and manual movement stop.
WHY : Keeps key controls visible.
WHERE : First monitor panel.
HOW : Options toggles local window state; stop queues an explicit request.
WHEN : Each visible frame.
------------------------------------------------------------------------------
]]
local function drawHeader(snapshot)
    ImGui.Text('MagFarm v' .. VERSION .. ' - Read-Only Monitor')
    ImGui.SameLine()
    if ImGui.Button('Options') then
        optionsOpen = not optionsOpen
    end
    tooltip('Display settings only. Does not enable combat or change group roles.')

    textColored(COLOR_INFO, string.format(
        '%s - Level %d %s - %s',
        snapshot.character.name, snapshot.character.level,
        snapshot.character.class, snapshot.character.zone
    ))

    if ImGui.Button('Stop All Movement', 180, 0) then
        ui.requestStopAllMovement()
    end
    tooltip('Stops existing travel, navigation, and sticking. Never starts movement.')
    ImGui.SameLine()
    textColored(COLOR_WARN, lastAction)
    ImGui.Separator()
end

--[[
------------------------------------------------------------------------------
FUNCTION : drawCharacter(snapshot)
WHAT : Displays local resources, casting, and readiness.
WHY : Applies shared thresholds without introducing actions.
WHERE : Character panel.
HOW : Renders snapshot data and session-local readiness input.
WHEN : Each visible frame.
------------------------------------------------------------------------------
]]
local function drawCharacter(snapshot)
    ImGui.Text('Character')
    drawResource(snapshot.character.hp, 'hpRedBelow', 'HP: ')
    ImGui.SameLine()
    drawResource(snapshot.character.mana, 'manaRedBelow', 'Mana: ')

    if snapshot.casting.active then
        textColored(COLOR_WARN, string.format(
            'Casting: %s (ID %d)', snapshot.casting.name, snapshot.casting.id
        ))
    else
        textColored(COLOR_GOOD, 'Casting: None')
    end

    ImGui.SetNextItemWidth(280)
    local updated = ImGui.InputText('Readiness spell', readinessSpell)
    if updated ~= readinessSpell then
        readinessSpell = updated
        logEvent('Readiness spell changed to: ' .. readinessSpell)
    end
    tooltip('Read-only readiness query. Does not memorize or cast.')

    if snapshot.readiness.enabled then
        textColored(
            snapshot.readiness.ready and COLOR_GOOD or COLOR_WARN,
            snapshot.readiness.spell .. ' readiness: ' ..
            (snapshot.readiness.ready and 'READY' or 'NOT READY')
        )
    else
        textColored(COLOR_INFO, 'Spell readiness probe disabled.')
    end
end

--[[
------------------------------------------------------------------------------
FUNCTION : drawPet(snapshot)
WHAT : Displays pet telemetry and manual recovery controls.
WHY : Preserves operator-controlled pet safety.
WHERE : Pet panel.
HOW : Uses snapshot data and disables buttons when no pet exists.
WHEN : Each visible frame.
SAFETY : Never selects a target or sends pet attack.
------------------------------------------------------------------------------
]]
local function drawPet(snapshot)
    ImGui.Text('Pet')

    if snapshot.pet.exists then
        ImGui.Text(string.format(
            'Name: %s (ID %d)', snapshot.pet.name, snapshot.pet.id
        ))
        drawResource(snapshot.pet.hp, 'hpRedBelow', 'HP: ')
        ImGui.SameLine()
        ImGui.Text(string.format('Distance: %.2f', snapshot.pet.distance))
        textColored(
            snapshot.pet.targetId == 0 and COLOR_GOOD or COLOR_WARN,
            'State: ' .. snapshot.pet.state
        )
    else
        textColored(COLOR_BAD, 'Pet: None summoned')
    end

    ImGui.BeginDisabled(not snapshot.pet.exists)
    if ImGui.Button('Pet Back Off', 120, 0) then
        ui.requestPetBackOff()
    end
    tooltip('Manual pet back-off. No targeting or pet attack.')
    ImGui.SameLine()
    if ImGui.Button('Pet Follow', 120, 0) then
        ui.requestPetFollow()
    end
    tooltip('Manual pet follow. No travel initiation.')
    ImGui.EndDisabled()
end

--[[
------------------------------------------------------------------------------
FUNCTION : drawTarget(snapshot)
WHAT : Displays target telemetry and informational safety classification.
WHY : Selected targets must not imply action permission.
WHERE : Current Target panel.
HOW : Uses existing snapshot classifications and fields.
WHEN : Each visible frame.
SAFETY : No target changes, assists, attacks, or casts.
------------------------------------------------------------------------------
]]
local function drawTarget(snapshot)
    local target = snapshot.target
    ImGui.Text('Current Target')

    local color = COLOR_WARN
    if target.safetyKind == 'NPC' then color = COLOR_GOOD end
    if target.safetyKind == 'PC' then color = COLOR_BAD end
    if target.safetyKind == 'NONE' then color = COLOR_INFO end
    textColored(color, target.safetyText)

    if not target.exists then return end

    ImGui.Text(string.format('Name: %s (ID %d)', target.name, target.id))
    ImGui.Text(string.format(
        'Level: %d  HP: %s  Distance: %.2f',
        target.level, percentText(target.hp), target.distance
    ))
    ImGui.Text('Type: ' .. target.type)
    ImGui.Text('Aggro holder: ' .. target.aggroHolder)
end

--[[
------------------------------------------------------------------------------
FUNCTION : drawGems(snapshot)
WHAT : Displays all twelve supported spell slots.
WHY : Empty slots must remain visible.
WHERE : Spell Gems collapsible panel.
HOW : Iterates captured gem records.
WHEN : Expanded during visible rendering.
------------------------------------------------------------------------------
]]
local function drawGems(snapshot)
    if not ImGui.CollapsingHeader('Spell Gems (1-12)') then return end
    for slot = 1, 12 do
        local gem = snapshot.gems[slot]
        local text = string.format('Gem %d: %s', gem.slot, gem.name)
        if gem.empty then
            textColored(COLOR_INFO, text)
        else
            ImGui.Text(text)
        end
    end
end

--[[
------------------------------------------------------------------------------
FUNCTION : drawLog()
WHAT : Displays bounded manual-action and settings history.
WHY : Keeps package-originated actions auditable.
WHERE : Activity Log panel.
HOW : Uses a child region and always balances BeginChild/EndChild.
WHEN : Expanded during visible rendering.
------------------------------------------------------------------------------
]]
local function drawLog()
    if not ImGui.CollapsingHeader('MagFarm Activity Log') then return end
    if #activityLog == 0 then
        ImGui.TextWrapped('No MagFarm activity has been recorded this session.')
        return
    end

    local visible = ImGui.BeginChild('magfarm_activity_log', 0, 120, true)
    if visible then
        for _, line in ipairs(activityLog) do
            ImGui.TextWrapped(line)
        end
    end
    ImGui.EndChild()
end

--[[
------------------------------------------------------------------------------
FUNCTION : ui.render()
WHAT : Draws the monitor and optional settings window.
WHY : Provides the existing loader's callback entry point.
WHERE : Registered by init.lua.
HOW : Captures once, renders panels, balances Begin/End, then draws Options.
WHEN : Each ImGui frame; Options may remain open if the monitor is hidden.
SAFETY : Only explicit manual button requests can lead to game commands.
------------------------------------------------------------------------------
]]
function ui.render()
    if ui.open then
        ImGui.SetNextWindowSize(650, 800, ImGuiCond.FirstUseEver)
        local show
        ui.open, show = ImGui.Begin('MagFarm##magfarm', ui.open)

        if show then
            local snapshot = state.capture(readinessSpell)
            drawHeader(snapshot)
            drawSummary(snapshot)
            ImGui.Separator()
            drawCharacter(snapshot)
            ImGui.Separator()
            drawRoster(snapshot)
            ImGui.Separator()
            drawPet(snapshot)
            ImGui.Separator()
            drawTarget(snapshot)
            ImGui.Separator()
            drawGems(snapshot)
            ImGui.Separator()
            drawLog()
            ImGui.Separator()
            ImGui.TextWrapped(
                'v' .. VERSION .. ': Local-group monitoring and manual safety ' ..
                'controls only. No raid collection, automatic casting, combat, ' ..
                'pet attack, travel, targeting, or role assignment.'
            )
        end

        ImGui.End()
    end

    drawOptions()
end

return ui

--[[
==============================================================================
FOOTER : ui.lua
VERSION : 0.3.5

EXPORTS :
  open
  requestStopAllMovement()
  requestPetBackOff()
  requestPetFollow()
  tick()
  render()

ROLE ORDER :
  Leader
  Main Tank
  Main Assist
  Puller
  Mark NPC
  Master Looter
  You

LAYOUT :
  Content-sized rows; no fixed roster heights or table scrolling flags.
  Role cells stack labels independently.
  Unknown role readings display a question-mark label.

RESOURCE COLOURS :
  Character HP/Mana, roster HP/Mana, and pet HP use shared settings.
  Known values below the threshold are red.
  Unknown/unavailable values are neutral --.
  Target HP remains informational and does not use ally resource colouring.

OPTIONS :
  Button-accessible separate window.
  HP and Mana thresholds default to 35%.
  Values are persistent, validated, and clamped to 0..100.
  Persistence implemented; save time, values, counter and pending status shown.
  Activity Log receives edit, reset, load, save and failure events once per tick.
  Save counters and activity history reset when the Lua package restarts.
  No gameplay behavior controls added.

SAFETY :
  Existing explicit manual controls only.
  No role changes, automatic resource responses, or Raid TLO reads.

END OF FILE
==============================================================================
]]--