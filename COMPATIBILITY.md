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