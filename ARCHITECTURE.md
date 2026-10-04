<!--
  FILE    : magfarm/ARCHITECTURE.md
  PACKAGE : MagFarm Lua (MacroQuest / EverQuest)
  VERSION : 0.1.0
  WHAT    : Maintainer map of MagFarm modules, state flow, boundaries, and safe editing rules.
  WHY     : Lets a future maintainer understand the design without reverse engineering source.
  WHERE   : Package root beside init.lua.
  WHEN    : Read before changing package behavior.
-->

# MagFarm architecture

## Start here

1. `init.lua` loads configuration, registers `/magfarm`, registers ImGui, and runs the outer loop.
2. `ui.lua` only renders status and requests actions. It must never wait.
3. `state.lua` owns Start, Pause, Resume, Stop, mode selection, and one non-blocking state tick.
4. `runtime.lua` owns live state; it is never saved.
5. `config.lua` owns persisted settings and validation.
6. Specialized modules report decisions upward; none independently starts combat or movement.

## Module map

| File | One job | Requires |
|---|---|---|
| `init.lua` | Startup, commands, main loop, clean shutdown | all modules |
| `runtime.lua` | Runtime state, status, log, camp data | none |
| `utils.lua` | Logging, command dispatch, timers, helpers | mq |
| `config.lua` | Defaults, load/save, validation | mq, utils |
| `state.lua` | State transitions and policy orchestration | config, runtime, utils, modules |
| `spells.lua` | Spellbook scan, role picks, upgrade recommendations | mq, config, runtime, utils |
| `assist.lua` | Group/Main Assist status foundation | mq, config, runtime, utils |
| `pet.lua` | Pet status and future taunt/attack policy | mq, config, runtime, utils |
| `merc.lua` | Mercenary status and future policy | mq, config, runtime, utils |
| `follow.lua` | Follow-leader validation and future navigation policy | mq, config, runtime, utils |
| `spell_acquisition.lua` | Scan-only vendor/inventory plan foundation | mq, config, runtime, spells, utils |
| `ui.lua` | ImGui controls and display only | mq, ImGui, modules |
| `dev/doc_audit.py` | Offline documentation-standard audit | Python |
| `dev/smoke_test.py` | Offline structure/configuration smoke test | Python |

## State flow

```text
IDLE
  -> PREPARE       Start requested
PREPARE
  -> MANUAL        Manual mode preflight passed
  -> CAMP_IDLE     Camp mode preflight passed
  -> FOLLOW        Follow mode preflight passed
  -> PAUSED        Preflight failed
MANUAL / CAMP_IDLE / FOLLOW
  -> PAUSED        Operator pause or safety condition
  -> IDLE          Operator stop
PAUSED
  -> prior state   Operator resume
```

Camp pulling, defensive fallback, pet release, mercenary control, and combat are intentionally reserved for later versions. The state names are present now so their later addition does not require replacing the architecture.

## Invariants

- UI callbacks do not call `mq.delay` or run multi-step game jobs.
- A group Main Assist owns group target selection.
- Without a valid Main Assist, group offense is disabled.
- Any safety exception must stay scoped to an already validated active pull target.
- No module may require a higher-level module and create a require cycle.
- Settings belong in `config.DEFAULTS`; live state belongs in `runtime.lua`.

## Future spell maintenance

Spell role candidates live in `spells.lua`, in best-first order. Add a newly preferred spell above older candidates, run `/magfarm spells`, review the recommendation, and update `CHANGELOG.md`.

## Documentation standard

Every Lua file has a header, footer, What/Why/Where/How/When function blocks, and line-level code documentation. Run:

```text
python dev/doc_audit.py
python dev/smoke_test.py
```

before considering an edit complete.

<!--
  END OF FILE : magfarm/ARCHITECTURE.md
-->
