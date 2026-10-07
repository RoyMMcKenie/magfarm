# MagFarm architecture - v0.3.6

## Module responsibilities

| File | What and why | Where and when |
|---|---|---|
| init.lua | Entry point, early readiness initialization, binding/window lifecycle | Requires readiness and verifies ImGui before requiring UI; initializes existing settings at startup and flushes them at shutdown |
| readiness.lua | Protected plugin inventory, cached states, explicit-load queue, bounded transition events | Called at startup, in ui.tick and immediately before stop dispatch; no automatic load/unload |
| ui.lua | Snapshot rendering, readiness panel, Options, manual-request queues and bounded Activity Log | Renders through ImGui; drains requests/events in the ordinary package loop |
| movement.lua | Existing explicit stop and pet-recovery dispatch | Stop refreshes inventory and attempts confirmed components independently; pet recovery remains separate |
| state.lua | Read-only game observations and local-group roles | Captures the displayed snapshot; unchanged by the readiness update |
| config.lua | Validated display thresholds and existing persistence diagnostics | Loaded/edited/flushed through the prior lifecycle; unchanged by readiness |

## Lifecycle

1. init.lua requires mq and readiness.lua.
2. readiness.initialize protects the ImGui require and collects plugin status.
3. A missing core ImGui binding produces a descriptive startup error. No plugin
   is automatically loaded to repair it. MQ2Lua is already executing the script;
   its inventory row is diagnostic, not a request to reload/unload the runtime.
4. init.lua requires UI and config, initializes settings, binds the existing
   slash command and registers the ImGui callback.
5. The main loop calls ui.tick. It processes explicit readiness load requests,
   polls inventory, drains readiness events, flushes/drains config diagnostics,
   and dispatches queued manual stop/pet actions.
6. UI rendering uses cached readiness rows and one game snapshot. Load/refresh
   clicks only queue work; they do not execute plugin commands or waits inside
   the ImGui callback.
7. Shutdown flushes existing configuration and releases the slash binding.

## Inventory semantics and events

A named protected reader calls Plugin(name).IsLoaded(). Only true and false are
accepted as known Boolean telemetry. Errors/non-Boolean values remain Unknown.
Cached rows include a label, known/loaded flags, purpose and diagnostic detail.

There are five inventory rows: MQ2Lua, three optional stop components, and
MQ2Melee for observation only. The latter is not a mandatory dependency and does
not establish a conflict. ImGui module availability is shown separately.

Startup records each plugin label once. Later samples log label changes only.
The readiness event queue retains up to 20 pending events and is drained once
per tick into the UI's bounded history. The UI history also retains up to 20
entries. Initial inventory and settings events therefore precede later manual
actions; older entries can be evicted normally.

## Explicit plugin-load path

requestLoad validates one of MQ2EasyFind, MQ2Nav or MQ2MoveUtils, rejects confirmed
loaded or already queued names, and records operator intent. tick consumes the
request once, sends `/plugin <name> load noauto` through a protected call and
refreshes inventory. The log distinguishes requested, dispatched, and loaded.
A normal dispatch return is not a guarantee the DLL exists or initialized.

No unload path is implemented. No arbitrary name or command text is accepted
from the readiness UI. The plugin's own initialization remains outside MagFarm's
control even for a session-only load.

## Stop dispatch and independent controls

movement.stopAll refreshes inventory immediately before dispatch. Fixed
components are attempted in order: EasyFind travel stop, Nav stop, MoveUtils
stick off. Each confirmed component has its own protected call, so another
component's absence/error does not prevent the remaining attempts. Missing or
unknown names and dispatch failures are separately summarized.

The UI disables the stop button only when no component is confirmed available.
A slash-command stop request still passes through movement.stopAll's checks.
Counts indicate dispatch attempts that did not throw, not physical cancellation
or a plugin command acknowledgement. Native follow and other controllers are
outside this three-component scope.

Pet Back Off/Follow depend on the existing pet state, not optional movement
plugin availability. No observation initiates a stop, pet command or plugin load.

## Documentation standard

Every code file requires a documentation header and footer. Every function,
including named protected-call helpers, documents WHAT, WHY, WHERE, HOW and WHEN.
Changes must describe safety boundaries and lifecycle, update the dated change
history and record precisely which tests ran. Do not invent MacroQuest commands.
Do not mark source inspection, idle dispatch, or plugin presence as proof of
successful gameplay behavior or conflict resolution.

The 120-high scrolling Activity Log remains unchanged. A resizable region is a
possible future feature request. Current readiness is separate from the retained
last-action header message. No gameplay implementation changed during this
documentation update.

---

<details>
<summary>Archived v0.3.5 baseline notes - historical context only</summary>

The current v0.3.6 sections above supersede any older scope, version or dependency statements below. These prior notes are preserved, not current operating instructions.

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


</details>
