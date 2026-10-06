# MagFarm

**Version:** 0.1.1 
**Purpose:** Safe read-only MacroQuest monitor for a Magician.

MagFarm 0.1.0 is intentionally **not** a farming bot. It displays live character, pet, target, casting, spell-readiness, and spell-gem information. Its only action is a manually requested **Stop All Movement** command.

## Installation

1. Find the Lua scripts folder used by your currently active MacroQuest installation.
2. Create a folder named:

   ```text
   magfarm
   ```

3. Place all MagFarm files inside that folder.
4. Start the package in-game:

   ```text
   /lua run magfarm
   ```

The package does not contain a hard-coded EverQuest path, MacroQuest path, drive letter, server name, or Windows user folder.

## Commands

| Command | Result |
|---|---|
| `/lua run magfarm` | Load MagFarm and open the monitor |
| `/lua stop magfarm` | Stop the Lua package |
| `/magfarm` | Toggle the monitor window |
| `/magfarm show` | Show the monitor window |
| `/magfarm hide` | Hide the monitor window |
| `/magfarm stop` | Stop EasyFind travel, MQ2Nav navigation, and `/stick` |
| `/magfarm quit` | Cleanly end MagFarm |
| `/magfarm help` | Print command help |

## Version 0.1.0 scope

### Reads and displays

- Character name, level, class, HP, mana, and zone
- Pet name, ID, HP, distance, and idle/targeting state
- Current target name, ID, level, HP, distance, type, and aggro holder
- Current cast name and spell ID
- Readiness of `Spear of Molten Arcronite`
- Spell gems 1 through 12, including intentionally empty slots

### Does not do

- Start travel or navigation
- Cast spells
- Change or acquire targets
- Attack
- Issue pet commands
- Loot
- Manage inventory
- Automate combat
- Automate pulling
- Make decisions from zone population data

## Stop All Movement

The UI button and `/magfarm stop` issue these verified commands:

```text
/travelto stop
/nav stop
/stick off
```

These commands stop movement systems that are already active. MagFarm 0.1.0 never starts any of them.

## Tested profile

The initial compatibility baseline was tested on:

```text
Character: 112 MAG
Class: MAG
Level: 112
Test zone: Frontier Mountains
Pet: summoned pet
Spell-gem profile: 12 valid slots
```

See `COMPATIBILITY.md` for the precise tested interfaces and unsupported members.

## Testing checklist

1. Keep spell gem 12 empty for the first UI test.
2. Run:

   ```text
   /lua run magfarm
   ```

3. Confirm the MagFarm window opens.
4. Confirm character, pet, target, casting, readiness, and gem data display.
5. Confirm gem 12 appears as `Empty`.
6. While idle, click **Stop All Movement**.
7. Confirm nothing harmful happens.
8. Toggle the window with:

   ```text
   /magfarm
   ```

9. Stop the package:

   ```text
   /magfarm quit
   ```

## Safety rule

Do not add movement, casting, pet, targeting, or combat behavior to MagFarm without first verifying the exact MacroQuest interface in the active installation and testing that behavior in a safe environment.

## v0.1.1 monitor behavior

MagFarm v0.1.1 adds only observability:

- Target safety classification based on the verified `Target.Type` member.
- User-editable, read-only `Me.SpellReady[spell name]` display.
- A local in-window MagFarm activity log.

It does not add any casting, targeting, pet-control, travel-start, navigation-start,
combat, loot, or inventory behavior.