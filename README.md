<!--
  FILE    : magfarm/README.md
  PACKAGE : MagFarm Lua (MacroQuest / EverQuest)
  VERSION : 0.1.0
  WHAT    : Installation, operation, safety, and troubleshooting guide.
  WHY     : Lets an operator use the package without reading source code.
  WHERE   : Package root beside init.lua.
  WHEN    : Read before the first in-game run and after every upgrade.
-->

# MagFarm

MagFarm is a documented MacroQuest Lua package for a Magician. It is designed as a controlled camp/follow assistant with explicit group Main Assist ownership, pet and mercenary pull discipline, spell-role selection, and future spell acquisition support.

## Status: 0.1.0 foundation

Version 0.1.0 intentionally provides the observable control core before autonomous pulling:

- Manual, Camp, and Follow modes
- Start, Pause, Resume, Stop, and Set Camp controls
- Character/server-specific settings
- Magician class preflight
- Spellbook role detection and manual role overrides
- Group/Main Assist status warning foundation
- Pet and mercenary status foundation
- Spell Acquisition scan-only preview foundation
- Rolling activity log and debug trace

It does **not** yet buy/scribe scrolls, issue offensive combat commands, control mercenary stances, or autonomously pull. Those features are staged after client-specific command paths are tested.

## Install

Place the folder named exactly `magfarm` inside your MacroQuest Lua folder:

```text
<MacroQuest>/lua/magfarm/
    init.lua  runtime.lua  state.lua  config.lua  utils.lua
    spells.lua  assist.lua  pet.lua  merc.lua  follow.lua
    spell_acquisition.lua  ui.lua
    README.md  ARCHITECTURE.md  ATTRIBUTION.md  CHANGELOG.md
```

Run:

```text
/lua run magfarm
```

## Commands

| Command | Action |
|---|---|
| `/magfarm` | Toggle the MagFarm window |
| `/magfarm start` | Start using the configured mode |
| `/magfarm stop` | Stop safely and return to Idle |
| `/magfarm pause` | Pause and stop movement |
| `/magfarm resume` | Resume the state saved by Pause |
| `/magfarm camp` | Save the current location as camp |
| `/magfarm mode manual` | Use Manual mode |
| `/magfarm mode camp` | Use Camp mode |
| `/magfarm mode follow` | Use Follow mode |
| `/magfarm spells` | Rescan spellbook and show role selections |
| `/magfarm acquire scan` | Scan open merchant/inventory in preview mode |
| `/magfarm status` | Print current state and key safety status |
| `/magfarm quit` | Save settings and end cleanly |

## Safety model

- When grouped, a valid Main Assist owns hostile target selection.
- Without a valid Main Assist, offensive group automation stays disabled.
- Solo or Magician-Main-Assist camp behavior is planned for the camp-pull milestone.
- Pet and mercenary emergency behavior is planned but remains disabled until its command interface is verified on the live client.
- Closing the window does not stop the script. Use Pause or Stop.

## Credits

Spell Acquisition is a clean Lua adaptation of the workflow in `scribe.mac`, originally authored by Sym. The supplied source credits Chatwiththisname, Lemons, and Sic for later contributions. See `ATTRIBUTION.md`.

<!--
  END OF FILE : magfarm/README.md
-->
