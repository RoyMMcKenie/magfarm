# MagFarm v0.3.6

Local-group read-only monitoring with explicitly requested safety controls and
startup-readiness inspection. This is a locally tested candidate pending review;
these notes do not mean it has been committed, pushed, tagged or released.

## Scope and safety

- Shows character resources, casting/readiness, local-group roles, pet state,
  selected-target information and twelve spell gems.
- Does not automatically travel, target, engage, cast, loot or command pets.
- Stop All Movement, Pet Back Off and Pet Follow require operator requests.
- Optional plugin loading requires an explicit Load-button click. MagFarm never
  automatically loads or unloads plugins, or disables another controller.
- Loaded plugins are not proof of active behavior or an actual conflict.

## Startup Readiness

The panel reports MQ2Lua, ImGui Lua bindings, MQ2EasyFind, MQ2Nav, MQ2MoveUtils and
an observation-only MQ2Melee row. ImGui is a Lua module, not a separate invented
plugin. Missing ImGui prevents UI startup with a descriptive error. A missing
optional movement plugin does not prevent monitoring or disable pet controls.

Plugin telemetry uses protected `mq.TLO.Plugin(name).IsLoaded()` reads. Native
Boolean results become Loaded or Not loaded; errors/non-Boolean results remain
Unknown. Unknown status never authorizes that plugin's stop command.

Checks run at startup, approximately once a second, on a queued manual refresh,
and immediately before stop dispatch. Refresh with unchanged labels does not
add repeated status-transition entries.

The three Load buttons are enabled when availability is not confirmed and are
disabled when their plugin is confirmed loaded. A click queues the documented
`/plugin <name> load noauto` command for the main loop. Names are allowlisted;
loads are not requested by character state, resource thresholds or rendering.
`noauto` avoids changing the MacroQuest.ini plugin autoload list. A plugin may
still execute its own initialization. A dispatched load command is not proof
of a successful load; use the subsequently sampled inventory result.

## Movement-stop coverage

| Plugin | Existing cancellation command | Dependency absent or unknown |
|---|---|---|
| MQ2EasyFind | `/travelto stop` | Skip this component |
| MQ2Nav | `/nav stop` | Skip this component |
| MQ2MoveUtils | `/stick off` | Skip this component |

Available components are attempted independently. Stop All Movement is disabled
in the UI when none are confirmed available. With one component absent, the
other two are still dispatched and the skipped name is reported. Dispatch
counts do not prove actual stopped motion or command-level success.

Native follow, other automation and unlisted movement systems are not covered.
MagFarm does not claim exclusive movement ownership. MQ2Melee being loaded is
an observation, not a finding that it is active or conflicting.

## Run and stop

Place the package files in the active Lua scripts directory's `magfarm` folder.
Use EverQuest chat, not PowerShell. Enter each command separately.

Start:

```text
/lua run magfarm
```

Stop:

```text
/lua stop magfarm
```

The current source set includes init.lua, ui.lua, readiness.lua, movement.lua,
state.lua and config.lua. Character display thresholds retain existing
per-server/per-character persistence. The readiness update does not change
config.lua, state.lua or saved settings.

## Public identity policy

Public examples use anonymous class/level labels such as `112 MAG` and `111 PAL`;
pets are described as `summoned pet`. Do not publish test characters' names,
personal filesystem paths, raw settings files or unredacted gameplay screenshots.

Normal in-game names and internal per-character settings remain unchanged.
The aim is to avoid linking the project creator to particular game characters,
not to conceal names from the existing in-game group. Raid support stays deferred.

Archived notes must follow the same public-example policy. Current-file cleanup
does not remove prior commits, published images, downloads, caches or forks.
History changes require separate review/approval; no force-push is authorized here.
Local updater scripts, backups, private review exports and history audit reports
are not public release artifacts and must not be staged with the package.

## Documentation and validation

- ARCHITECTURE.md: modules, lifecycle, queues and safety boundaries.
- COMPATIBILITY.md: observed environment and limits.
- CHANGELOG.md: dated change history.
- TESTING-v0.3.6.md: screenshot-supported results and explicitly untested cases.
- INSTALL-v0.3.6.txt: operation and local update/review instructions.

The Activity Log remains a fixed-height scrolling child region. Resizable log
height is deferred as a possible future feature request, not a release blocker.
The header action message describes the last action; the readiness line
reports current plugin availability, so their counts can legitimately differ.

Official API/command references:
- https://docs.macroquest.org/reference/top-level-objects/tlo-plugin/
- https://docs.macroquest.org/reference/data-types/
- https://docs.macroquest.org/reference/commands/plugin/

Validation is limited to the cases recorded in TESTING-v0.3.6.md. In particular,
idle dispatch must not be described as an active-travel cancellation test.

---

<details>
<summary>Archived v0.3.5 baseline notes - historical context only</summary>

The current v0.3.6 sections above supersede any older scope, version or dependency statements below. These prior notes are preserved, not current operating instructions.

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


</details>
