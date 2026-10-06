--[[
==============================================================================
FILE    : magfarm/state.lua
PACKAGE : MagFarm
VERSION : 0.3.4

WHAT :
Collects read-only character, local roster, group roles, pet, target, casting,
spell-readiness, and spell-gem snapshots.

WHY :
Rendering should consume data rather than perform game-state lookups.
Role assignments must be independent, and unknown data must not become a
false zero or an assumed unassigned role.

WHERE :
Required by magfarm/ui.lua. capture() is called once per visible frame.

HOW :
Scans numeric Group.Member slots 0 through 5.
Captures each verified role flag independently.
Preserves missing roster resources as nil and role validity separately.

WHEN :
Whenever ui.render() captures a monitor snapshot.

COMPATIBILITY :
Group.Members is not used as the roster length.
Name-indexed Group.Member lookup is not used.
Numeric slots are the validated roster source on the tested client.
Remote mana remains group-reported and has shown inconsistent readings.

ROLE MODEL :
member.roles contains true/false when known, nil when unknown.
member.rolesKnown distinguishes known readings from missing/failed readings.
Leader identity is captured separately through Group.Leader.Name.
No role is inferred from Main Assist, Main Tank, or another assignment.

RAID ROADMAP :
Roster records remain reusable. Raid data collection is not implemented.

SAFETY :
No commands, targeting, casting, movement, pet control, loot, inventory,
role assignments, or raid reads.
==============================================================================
]]--

local mq = require('mq')
local state = {}

--- Validated client profile limits, isolated in collection rather than the UI.
local FIRST_GROUP_SLOT = 0
local LAST_GROUP_SLOT = 5
local FIRST_SPELL_GEM = 1
local LAST_SPELL_GEM = 12

--- Stable role keys mapped to validated Group.Member Boolean members.
local ROLE_FIELDS = {
    { key = 'mainTank', field = 'MainTank' },
    { key = 'mainAssist', field = 'MainAssist' },
    { key = 'puller', field = 'Puller' },
    { key = 'markNpc', field = 'MarkNpc' },
    { key = 'masterLooter', field = 'MasterLooter' },
}

--[[
------------------------------------------------------------------------------
FUNCTION : normalize(value, fallback)
WHAT : Converts absent text values into a supplied fallback.
WHY : nil, empty strings, and NULL are normal absent TLO results.
WHERE : Snapshot collection helpers and capture().
HOW : Converts usable values to text and rejects empty/NULL text.
WHEN : Each optional string is collected.
------------------------------------------------------------------------------
]]
local function normalize(value, fallback)
    if value == nil then
        return fallback
    end

    local text = tostring(value)
    if text == '' or text:upper() == 'NULL' then
        return fallback
    end

    return text
end

--[[
------------------------------------------------------------------------------
FUNCTION : numberOr(value, fallback)
WHAT : Converts a numeric value while preserving the selected fallback.
WHY : Unknown roster resources must remain nil rather than become zero.
WHERE : Numeric snapshot fields.
HOW : Rejects missing and non-finite numeric results.
WHEN : Each numeric field is collected.
------------------------------------------------------------------------------
]]
local function numberOr(value, fallback)
    local number = tonumber(value)
    if not number or number ~= number or
        number == math.huge or number == -math.huge then
        return fallback
    end
    return number
end

--[[
------------------------------------------------------------------------------
FUNCTION : booleanValue(value)
WHAT : Converts supported Boolean forms to true/false, preserving unknowns.
WHY : Missing roles must not silently appear unassigned.
WHERE : Role, presence, and death reads.
HOW : Recognizes native Boolean values and TRUE/FALSE/1/0 text.
WHEN : Each Boolean field is collected.
RETURNS : true, false, or nil.
------------------------------------------------------------------------------
]]
local function booleanValue(value)
    if value == true or value == false then
        return value
    end

    if value == nil then
        return nil
    end

    local text = tostring(value):upper()
    if text == 'TRUE' or text == '1' then
        return true
    end
    if text == 'FALSE' or text == '0' then
        return false
    end
    return nil
end

--[[
------------------------------------------------------------------------------
FUNCTION : invokeMemberField(member, field)
WHAT : Invokes one dynamically selected member field.
WHY : Provides a named protected-call target without duplicating accessors.
WHERE : readMemberField().
HOW : Indexes the TLO member by validated field name and invokes it.
WHEN : Inside a protected read.
------------------------------------------------------------------------------
]]
local function invokeMemberField(member, field)
    return member[field]()
end

--[[
------------------------------------------------------------------------------
FUNCTION : readMemberField(member, field)
WHAT : Reads an optional member field without propagating an access error.
WHY : One unavailable field should not interrupt the entire roster.
WHERE : Role and resource collection.
HOW : Protects invokeMemberField() with pcall.
WHEN : Each optional member field is collected.
RETURNS : Raw result, or nil if access fails.
------------------------------------------------------------------------------
]]
local function readMemberField(member, field)
    local ok, value = pcall(invokeMemberField, member, field)
    if not ok then
        return nil
    end
    return value
end

--[[
------------------------------------------------------------------------------
FUNCTION : memberAt(slot)
WHAT : Resolves one numeric group slot.
WHY : Keeps numeric slot access isolated for protected collection.
WHERE : captureRoster().
HOW : Returns mq.TLO.Group.Member(slot).
WHEN : Each of the six supported slots is scanned.
------------------------------------------------------------------------------
]]
local function memberAt(slot)
    return mq.TLO.Group.Member(slot)
end

--[[
------------------------------------------------------------------------------
FUNCTION : memberClass(member)
WHAT : Reads a member's short class name.
WHY : Class is nested and may not be available when the member is absent.
WHERE : captureRoster(), through a protected call.
HOW : Invokes member.Class.ShortName().
WHEN : An occupied group slot is captured.
------------------------------------------------------------------------------
]]
local function memberClass(member)
    return member.Class.ShortName()
end

--[[
------------------------------------------------------------------------------
FUNCTION : leaderNameRead()
WHAT : Reads the current group leader name.
WHY : Leader identity must not be inferred from slot zero.
WHERE : captureRoster(), through a protected call.
HOW : Reads Group.Leader.Name().
WHEN : Each roster capture.
------------------------------------------------------------------------------
]]
local function leaderNameRead()
    return mq.TLO.Group.Leader.Name()
end

--[[
------------------------------------------------------------------------------
FUNCTION : captureRoles(member)
WHAT : Captures independently assigned group-role flags.
WHY : Roles can overlap, remain unassigned, or have unavailable telemetry.
WHERE : captureRoster().
HOW : Reads each validated role field and stores value and known-state maps.
WHEN : Each occupied member is captured.
RETURNS : roles, rolesKnown.
------------------------------------------------------------------------------
]]
local function captureRoles(member)
    local roles = {}
    local known = {}

    for _, definition in ipairs(ROLE_FIELDS) do
        local value = booleanValue(readMemberField(member, definition.field))
        roles[definition.key] = value
        known[definition.key] = value ~= nil
    end

    return roles, known
end

--[[
------------------------------------------------------------------------------
FUNCTION : captureRoster(character)
WHAT : Collects occupied local group slots and their independent roles.
WHY : Supplies a generic roster without relying on the observed count issue.
WHERE : state.capture().
HOW : Scans slots 0..5, retains valid names, protects optional reads, and uses
      Me-derived resources for the local character.
WHEN : Once per visible snapshot.
NOTE : Does not invent a synthetic solo row if Group provides no occupied slot.
------------------------------------------------------------------------------
]]
local function captureRoster(character)
    local leaderOk, rawLeader = pcall(leaderNameRead)
    local leader = leaderOk and normalize(rawLeader, '') or ''
    local members = {}

    for slot = FIRST_GROUP_SLOT, LAST_GROUP_SLOT do
        local ok, member = pcall(memberAt, slot)

        if ok and member then
            local name = normalize(readMemberField(member, 'Name'), '')

            if name ~= '' then
                local isSelf = name == character.name
                local classOk, rawClass = pcall(memberClass, member)
                local roles, rolesKnown = captureRoles(member)
                local reportedLeader =
                    booleanValue(readMemberField(member, 'Leader'))

                local isLeader = nil
                if leader ~= '' then
                    isLeader = name == leader
                elseif reportedLeader ~= nil then
                    isLeader = reportedLeader
                end

                local hp = numberOr(readMemberField(member, 'PctHPs'), nil)
                local mana = numberOr(readMemberField(member, 'PctMana'), nil)

                if isSelf then
                    hp = character.hp
                    mana = character.mana
                end

                table.insert(members, {
                    name = name,
                    classShortName =
                        classOk and normalize(rawClass, '--') or '--',
                    hpPct = hp,
                    manaPct = mana,
                    distance =
                        numberOr(readMemberField(member, 'Distance'), nil),
                    present =
                        booleanValue(readMemberField(member, 'Present')),
                    dead =
                        booleanValue(readMemberField(member, 'Dead')),
                    isSelf = isSelf,
                    isLeader = isLeader,
                    roles = roles,
                    rolesKnown = rolesKnown,
                    groupSlot = slot,
                    manaSource = isSelf and 'local' or 'group-reported',
                })
            end
        end
    end

    return {
        scope = 'group',
        leaderName = leader,
        memberCount = #members,
        source = {
            type = 'group',
            firstSlot = FIRST_GROUP_SLOT,
            lastSlot = LAST_GROUP_SLOT,
        },
        members = members,
    }
end

--[[
------------------------------------------------------------------------------
FUNCTION : targetSafety(typeName, exists)
WHAT : Classifies the selected target for informational display.
WHY : Target selection must never imply permission to act.
WHERE : state.capture().
HOW : Maps absent, NPC, PC, and other target types to text classifications.
WHEN : Each snapshot.
------------------------------------------------------------------------------
]]
local function targetSafety(typeName, exists)
    if not exists then
        return 'NONE',
            'No target selected. Monitor only; no target will be acquired.'
    end
    if typeName == 'NPC' then
        return 'NPC',
            'NPC selected. Informational only; MagFarm will not attack or act.'
    end
    if typeName == 'PC' then
        return 'PC',
            'Player character selected. Never a valid combat target.'
    end
    return 'OTHER', string.format(
        '%s selected. Inspect manually; MagFarm will not act on this target.',
        typeName
    )
end

--[[
------------------------------------------------------------------------------
FUNCTION : state.capture(readinessSpell)
WHAT : Builds the complete read-only monitor snapshot.
WHY : Keeps TLO collection separate from rendering and configuration.
WHERE : ui.render().
HOW : Collects the existing character/pet/target/spell fields and local roster.
WHEN : Once per visible UI frame.
PARAMETER : readinessSpell is an optional read-only Me.SpellReady query.
------------------------------------------------------------------------------
]]
function state.capture(readinessSpell)
    local character = {
        name = normalize(mq.TLO.Me.Name(), 'Unknown'),
        level = numberOr(mq.TLO.Me.Level(), 0),
        class = normalize(mq.TLO.Me.Class.ShortName(), '?'),
        hp = numberOr(mq.TLO.Me.PctHPs(), nil),
        mana = numberOr(mq.TLO.Me.PctMana(), nil),
        zone = normalize(mq.TLO.Zone.Name(), 'Unknown'),
    }

    local petName = normalize(mq.TLO.Me.Pet.Name(), '')
    local petTarget = normalize(mq.TLO.Me.Pet.Target.CleanName(), '')
    local targetName = normalize(mq.TLO.Target.CleanName(), '')
    local targetType = normalize(mq.TLO.Target.Type(), 'None')
    local castingName = normalize(mq.TLO.Me.Casting.Name(), '')
    local targetExists = targetName ~= ''
    local safetyKind, safetyText = targetSafety(targetType, targetExists)

    local petState = 'No pet summoned'
    if petName ~= '' then
        petState = petTarget == '' and 'Idle' or 'Targeting ' .. petTarget
    end

    local gems = {}
    for slot = FIRST_SPELL_GEM, LAST_SPELL_GEM do
        local name = normalize(mq.TLO.Me.Gem(slot).Name(), '')
        gems[slot] = {
            slot = slot,
            name = name == '' and 'Empty' or name,
            empty = name == '',
        }
    end

    local selectedSpell = normalize(readinessSpell, '')
    local ready = false
    if selectedSpell ~= '' then
        ready = mq.TLO.Me.SpellReady(selectedSpell)() == true
    end

    return {
        character = character,
        roster = captureRoster(character),

        pet = {
            name = petName == '' and 'None' or petName,
            id = numberOr(mq.TLO.Me.Pet.ID(), 0),
            hp = numberOr(mq.TLO.Me.Pet.PctHPs(), nil),
            distance = numberOr(mq.TLO.Me.Pet.Distance(), 0),
            targetName = petTarget == '' and 'None' or petTarget,
            targetId = numberOr(mq.TLO.Me.Pet.Target.ID(), 0),
            state = petState,
            exists = petName ~= '',
        },

        target = {
            name = targetName == '' and 'None' or targetName,
            id = numberOr(mq.TLO.Target.ID(), 0),
            level = numberOr(mq.TLO.Target.Level(), 0),
            hp = numberOr(mq.TLO.Target.PctHPs(), nil),
            distance = numberOr(mq.TLO.Target.Distance(), 0),
            type = targetType,
            aggroHolder = normalize(mq.TLO.Target.AggroHolder.Name(), 'None'),
            exists = targetExists,
            safetyKind = safetyKind,
            safetyText = safetyText,
        },

        casting = {
            name = castingName == '' and 'None' or castingName,
            id = numberOr(mq.TLO.Me.Casting.ID(), 0),
            active = castingName ~= '',
        },

        readiness = {
            spell = selectedSpell,
            ready = ready,
            enabled = selectedSpell ~= '',
        },

        gems = gems,
    }
end

return state

--[[
==============================================================================
FOOTER : magfarm/state.lua

EXPORT :
  capture(readinessSpell)

GROUP ROLE FIELDS :
  Leader
  MainTank
  MainAssist
  Puller
  MarkNpc
  MasterLooter

UNKNOWN-DATA POLICY :
  Missing numeric resources remain nil.
  Missing role readings remain nil with rolesKnown[key] == false.
  Numeric zero is preserved as a reported value.
  No unsupported role is silently described as unassigned.

SAFETY :
  Read-only collection only.
  No commands, assignment changes, or Raid TLO access.

END OF FILE
==============================================================================
]]--