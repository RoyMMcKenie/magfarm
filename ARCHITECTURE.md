# MagFarm architecture

Scope: the current v0.3.5 monitor branch with save diagnostics. This document replaces architecture descriptions from the earlier legacy attempt.

## Module responsibilities

| Root file | Responsibility |
|---|---|
| `init.lua` | Require UI/config, initialize settings, bind `/magfarm`, register the ImGui callback, run the 100 ms loop and flush on clean shutdown. |
| `config.lua` | Validate thresholds, load/save schema-1 character settings, describe pending/completed results and queue bounded diagnostic events. |
| `state.lua` | Collect read-only character, numeric group-slot roster, independent role flags, pet, target, casting, readiness and spell-gem snapshots. |
| `movement.lua` | Dispatch existing explicitly requested movement cancellation and pet recovery commands. |
| `ui.lua` | Render the monitor and Options, enqueue manual requests, flush settings and consume diagnostic events in tick, and show bounded activity history. |

## Runtime flow

The repository root maps to the installed `lua/magfarm` directory. Package imports keep the `magfarm.` prefix; removing the redundant repository subfolder did not require removing that prefix.

Startup loads server/character settings before UI registration. The main loop calls `ui.tick()` and yields 100 ms while in-game. A visible monitor frame obtains a snapshot through `state.capture()`. Options updates validated in-memory values only.

On tick, config flushes pending values, then the UI drains settings events once into its Activity Log. Explicit manual requests are dispatched separately through movement helpers. Closing or hiding the monitor does not turn its observed data into action triggers.

## Persistence and diagnostics

Two resource thresholds share one configuration source. Defaults are HP=35 and Mana=35. Missing optional values retain defaults; valid loaded values use the same validation path as edits without generating operator-edit events.

Data lives under `mq.configDir`, with a filename derived from encoded server and character identity. Schema-1 text remains compatible with the previously tested settings files. The temporary/backup/rename algorithm is unchanged by diagnostics. Unsupported schemas block overwriting. Save failures retain in-memory edits but clear the automatic retry flag; another edit or explicit reset can queue a new attempt.

The status distinguishes pending memory values from the last completed result. Save counts increase only after a successful final rename and are session-local. Timestamps use local wall-clock time. The configuration event queue and UI Activity Log are bounded to 20 entries each. Reading status performs no file I/O, and draining events clears the pending queue.

## Data and action boundaries

Group.Member numeric slots 0..5 are the roster source. Independent roles may overlap; missing role telemetry stays unknown. Missing numeric resources remain nil rather than silently becoming zero. Remote mana remains group-reported. Raid data is not collected.

Automatic combat, casting, pet engagement, targeting, character travel/navigation, loot, inventory and role assignment remain outside the implemented scope. Startup plugin inventory and conflict/readiness reporting remain future work; command availability is not currently guaranteed by startup validation.

## Documentation rule

Every code file must retain a documentation header and footer. Every function must describe what, why, where, how and when. Comments describing safety, persistence or implemented features must match actual behavior rather than intended future behavior.
