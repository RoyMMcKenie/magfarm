# MagFarm compatibility - v0.3.6

## Observed client checkpoint

On October 6, 2026, user-supplied screenshots showed MagFarm v0.3.6 running in
EverQuest's Frontier Mountains on a level-112 magician with a two-member local
group and a summoned pet. These observations establish this local test setup,
not universal compatibility with every server, build or plugin distribution.

ImGui Lua bindings and MQ2Lua inventory detection worked. All three optional
plugins were individually recognized as Loaded/Not loaded. GUI recovery was
observed for EasyFind, Nav and MoveUtils. Nav/EasyFind remained independently
listed during the Nav-missing test; absence of Nav does not establish that
EasyFind can perform its normal travel function without it.

## Dependency and API requirements

- mq runtime and ImGui Lua bindings must be usable. There is no separate required
  MQ2ImGui plugin in this implementation.
- Modern Plugin(name).IsLoaded Boolean telemetry is expected. Errors or
  non-Boolean results remain Unknown and do not authorize dependent commands.
- MQ2EasyFind, MQ2Nav and MQ2MoveUtils are optional for the monitor. They provide
  separate components of the existing best-effort cancellation button.
- MQ2Melee is observed only. Presence is not proof of activity or conflict.
- Loading uses the documented `/plugin <name> load noauto` command, with explicit
  operator initiation and a subsequent availability check.

## Proven cases and limits

See TESTING-v0.3.6.md for exact results. Missing detection/recovery and one-missing
idle stop dispatch were observed for all three components. Startup with EasyFind
missing also worked. Group/pet panels remained available throughout the shown
optional-dependency cases.

Not tested at this checkpoint:
- Cancelling active travel, navigation or sticking with this version.
- All three optional components absent, including disabled stop-button behavior.
- Actual unknown/error plugin telemetry.
- Plugin DLL absent or failing to initialize; failed GUI recovery.
- ImGui missing; missing-core startup error behavior.
- Startup with Nav or MoveUtils absent.
- Actual active-controller conflict detection/resolution or exclusive ownership.
- Navigation meshes, route/path availability and zone transitions.
- Other clients, servers, builds, classes or plugin distributions.

A dispatch count is not a physical-movement assertion. Native follow and other
controllers are not covered. No auto-unloading/conflict-remediation is implemented.
Do not unload supporting plugins while another script is using them.

## Existing monitoring caveats

The readiness update does not change state.lua or config.lua. Group-reported
remote mana is not independent validation of another client's actual mana.
Unknown roles/resources retain their existing representations. Resource colours
are display-only and never authorize actions. No raid collection or automated
engagement has been added.

Character settings persistence remained observable: startup showed HP=35 and
Mana=36 from the existing settings file. That is a load observation during this
checkpoint, not a new v0.3.6 persistence regression test.

---

<details>
<summary>Archived v0.3.5 baseline notes - historical context only</summary>

The current v0.3.6 sections above supersede any older scope, version or dependency statements below. These prior notes are preserved, not current operating instructions.

# MagFarm Compatibility Record

**Package version:** 0.1.0  
**Profile tested:** 112 MAG, level 112 Magician  
**Test environment:** Frontier Mountains

This document records only interfaces tested in the active user environment. It exists to prevent future code from relying on guessed MacroQuest members or command syntax.

## Verified movement cancellation

| System | Verified command | Observed result |
|---|---|---|
| EasyFind travel | `/travelto stop` | EasyFind reported `/travelto stopped` |
| MQ2Nav | `/nav stop` | MQ2Nav reported `Stopping navigation` |
| MQ2MoveUtils | `/stick off` | Defensive stop command included in the safety sequence |

MagFarm stop sequence:

```text
/travelto stop
/nav stop
/stick off
```

## Verified ImGui conventions

```lua
local mq = require('mq')
local ImGui = require('ImGui')

mq.imgui.init('magfarm', ui.render)

local show
ui.open, show = ImGui.Begin('MagFarm##magfarm', ui.open)

if show then
    -- draw contents
end

ImGui.End()
```

Verified control conventions:

```lua
if ImGui.Button('Label') then
    -- action
end

value = ImGui.Checkbox('Label', value)
value = ImGui.InputText('Label', value)
value = ImGui.InputInt('Label', value)
```

## Verified character TLOs

```text
Me.Name
Me.Level
Me.Class.ShortName
Me.PctHPs
Me.PctMana
Zone.Name
```

## Verified pet TLOs

```text
Me.Pet.Name
Me.Pet.ID
Me.Pet.PctHPs
Me.Pet.Distance
Me.Pet.Target.CleanName
Me.Pet.Target.ID
```

Observed idle state:

```text
Pet target name: NULL
Pet target ID: 0
```

## Verified target TLOs

```text
Target.CleanName
Target.ID
Target.Level
Target.PctHPs
Target.Distance
Target.Type
Target.AggroHolder.Name
```

Observed unengaged target state:

```text
Target.AggroHolder.Name: NULL
```

## Verified spell interfaces

```text
Me.Gem[1..12].Name
Me.Gem[1..12].ID
Me.SpellReady[spell name]
Me.Casting.Name
Me.Casting.ID
```

Observed casting example:

```text
Spell: Spear of Molten Arcronite
Active casting name: Spear of Molten Arcronite
Active casting ID: 57045
SpellReady during cast: FALSE
SpellReady after completed cast and before recast: FALSE
SpellReady when available: TRUE
```

## Spell gem rules

- 112 MAG has 12 valid gem slots.
- A valid but empty slot returns `NULL` for both name and ID.
- An out-of-range slot 13 also returns `NULL` for both name and ID.
- Therefore, populated-gem count must not be used as gem capacity detection.
- MagFarm 0.1.0 iterates the known valid profile range 1 through 12.
- Empty slots are displayed as `Empty`, not used as an enumeration stop condition.

## Unsupported interfaces

Do not use these in MagFarm unless independently re-tested:

```text
Me.Gem[slot].Timer
Me.Pet.Target.AggroHolder.Name
Me.Gem[2]
```

Observed results:

```text
Me.Gem[slot].Timer:
  No such 'spell' member 'Timer'

Me.Pet.Target.AggroHolder.Name:
  No such 'spawn' member 'AggroHolder'
```

</details>
