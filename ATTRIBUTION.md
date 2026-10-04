<!--
  FILE    : magfarm/ATTRIBUTION.md
  PACKAGE : MagFarm Lua (MacroQuest / EverQuest)
  VERSION : 0.1.0
  WHAT    : Records the authors and source material credited by this package.
  WHY     : Maintains clear provenance for adapted ideas and future maintenance.
  WHERE   : Package root beside README.md.
  WHEN    : Read before redistributing or modifying adapted components.
-->

# Attribution

## Mag106 source macro

MagFarm began as a clean Lua redesign of behavior found in the supplied `Mag106.mac`.
Its existing spell names, camp-loop intent, self/pet buff intent, and combat ideas are preserved as historical reference only; MagFarm is not a line-for-line port.

## Spell acquisition source

The Spell Acquisition subsystem is a documented Lua adaptation of the workflow in the supplied `scribe.mac`.

- Original macro: `scribe.mac`
- Original author recorded in source: **Sym**
- Original date recorded in source: **September 4, 2012**

### Contributions recorded in the supplied source

- **Chatwiththisname** — January 14, 2018: corrected loop-variable handling and improved bag opening behavior.
- **Lemons** — November 9, 2020: added emulator-server support.
- **Sic** — May 7, 2021: corrected duplicate-purchase behavior that could affect PAL, SHD, BST, RNG, and BRD characters.

### Lua adaptation

MagFarm reimplements the useful behavior as a new, state-driven Lua subsystem: merchant/inventory scanning, rank-aware duplicate checks, reviewed plans, spending caps, one-action-at-a-time verification, post-scribe spellbook refresh, and explicit operator control. It does not copy the MacroQuest macro implementation line-for-line.

<!--
  END OF FILE : magfarm/ATTRIBUTION.md
-->
