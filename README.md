# MagFarm

Version: 0.3.5, including the save-diagnostics extension.
Working branch: `monitor-baseline-v0.3.5`.
Tested diagnostics code checkpoint: `cfb1359`.

## Purpose and scope

MagFarm is a MacroQuest Magician monitor with explicit manual safety controls. It displays character, local-group roster, independent stacked group roles, pet, target, casting, readiness and twelve spell-gem slots. It does not automatically select targets, cast, attack, engage pets, start character travel/navigation, loot, manage inventory or assign group roles. Raid collection is not implemented.

The manual controls are Stop All Movement, Pet Back Off and Pet Follow. Their requests are dispatched from the main loop, not from the ImGui render callback. A selected NPC or a red resource value does not authorize a game action.

## Repository and installation layout

The repository root contains `init.lua`, `config.lua`, `state.lua`, `movement.lua`, `ui.lua` and documentation. There is no nested package folder inside the repository. Place or clone the repository root at the active MacroQuest Lua scripts directory's `magfarm` folder. The installed folder itself must still be named `magfarm`, because the code imports `magfarm.ui`, `magfarm.config`, `magfarm.state` and `magfarm.movement`.

Start and stop these commands in EverQuest chat, not PowerShell:

```text
/lua run magfarm
/lua stop magfarm
```

`/magfarm` toggles the monitor; `show` and `hide` control visibility; `stop` requests movement cancellation; `quit` requests clean shutdown; `help` prints available slash commands. Pet recovery controls are UI buttons.

## Persistent display options

Open Options to change HP and Mana red-below thresholds. Defaults are 35% each. Values are validated, clamped to 0..100 and rounded. A known value turns red only when strictly below its threshold; equality is not red. Unknown resources remain neutral `--`. Remote mana is group-reported and has previously shown inaccurate readings.

Storage is `MagFarm_<encoded server>_<encoded character>.settings` in `mq.configDir`, not the Git working directory. Schema version remains 1. Settings are parsed as data, never executed. Writes occur in the main-loop tick and on clean shutdown. Reset always queues a save, even if values already match the defaults. Existing-file replacement uses temporary and backup files with a rollback attempt on replacement failure. Unknown schemas are preserved. Crash recovery from `.bak` is manual.

## Save diagnostics

Options distinguishes loaded values, pending values, successful saves and failures. A successful save shows a session-local counter, local date/time, actual HP/Mana thresholds and the storage path. Editing or resetting does not itself count as a successful write.

The Activity Log receives settings load, edit, reset, save and failure events as well as manual-action events. Events are drained once per main-loop tick. The UI retains at most 20 entries; history and save counters restart with the Lua package. These diagnostics are not a persistent audit log.

## Git workflow

The active local MagFarm folder is the Git working copy. For a OneDrive-backed working folder, this user's setup keeps the Git database outside OneDrive. Its `.git` file points to a machine-local database; do not reuse that pointer on another computer.

Run Git commands in PowerShell from the working folder. To receive GitHub changes, stop MagFarm and use `git pull --ff-only`. To publish tested Lua edits, review `git status` and `git diff`, stage only intended files, commit, then push the working branch. Do not rerun the first-time clone or diagnostics installer after successful installation. Git synchronization is manual, not automatic. Never force an overwrite to resolve unexplained errors.

## Validation and remaining work

On 2026-10-06, the user confirmed startup, edited HP=40/Mana=46 surviving restart, and reset values of 35/35 surviving restart on the pre-diagnostics v0.3.5 baseline. After the diagnostics extension, the user confirmed a loaded-values event, a prompt Mana edit event and a successful save display for HP=35/Mana=36. The two-file diagnostics update was committed and pushed as `cfb1359`.

Failure injection, crash recovery, cross-character isolation, all role combinations and threshold-colour boundary tests are not established by these screenshots. Automatic startup plugin verification is not yet implemented. Consult `COMPATIBILITY.md` for the historical tested-interface record; it is not a complete current-feature description. `INSTALL-v0.3.5.txt` is retained as the earlier persistence-install note; this README describes the current Git layout.
