# MagFarm v0.3.6 - Local validation record

Date: October 6, 2026 (user's CDT session).
Evidence: User-provided screenshots and visible MagFarm/MacroQuest console logs.
Status: Local readiness checkpoint completed; review/publication pending.
Method: Manual client testing; no automated Lua/MacroQuest runtime test claimed.

## Observed results

| ID | Case | Observation | Result |
|---|---|---|---|
| R01 | All-loaded startup | v0.3.6 monitor opens; ImGui available; runtime and three optional components Loaded; 3/3 summary | Observed pass |
| R02 | Loaded-state UI gating | Each loaded optional plugin's Load button appears disabled | Observed pass |
| R03 | EasyFind disappears while running | Not loaded, 2/3, Load button enabled; one visible transition at 17:04:50 | Observed pass |
| R04 | EasyFind GUI recovery | At 17:07:16: request, dispatch, Loaded; console confirms loaded and UI returns 3/3 | Observed pass |
| R05 | All-loaded idle stop | Explicit queue event and 3/3 dispatched result; EasyFind/Nav report no active travel/path | Observed pass for idle dispatch only |
| R06 | EasyFind-missing idle stop | 2/3 dispatched; skipped MQ2EasyFind; monitor stays available | Observed pass |
| R07 | EasyFind absent at startup | Old PID 19 ends; EasyFind unloads; PID 20 starts; UI 2/3 and EasyFind stays Not loaded | Observed pass |
| R08 | Nav missing/recovery | Not loaded, enabled Load, 2/3; later console confirms loaded and UI shows Loaded | Observed pass |
| R09 | MoveUtils missing idle stop | At 17:30:31 Not loaded; stop result 2/3 with MQ2MoveUtils skipped | Observed pass |
| R10 | MoveUtils GUI recovery | At 17:32:20 request/dispatch/Loaded logged; console confirms loaded; 3/3 | Observed pass |
| R11 | Nav-missing idle stop | At 17:34:03 Not loaded; later console and Activity Log show 2/3, skipped MQ2Nav | Observed pass |
| R12 | Nav GUI recovery | At 17:35:32 request; at 17:35:33 dispatch and Loaded; final UI 3/3, load buttons disabled | Observed pass |
| R13 | Monitoring with one optional dependency absent | Group/pet panels remain visible and manual pet buttons appear available | Observed UI pass; pet command execution not newly tested |
| R14 | Status repetition | Shown later log retains one transition/action sequence, not visible repeated copies | No duplication observed in shown entries; explicit refresh click not independently evidenced |
| R15 | Existing settings load | Restart log reports existing thresholds HP=35, Mana=36 | Load observed; save/restart regression suite not rerun |

## Important distinctions

- All stop tests above were requested while idle; dispatch does not prove active
  motion was cancelled or that a plugin accepted a command semantically.
- Plugin Loaded does not establish route readiness, mesh availability, an active
  controller, a real conflict or exclusive movement ownership.
- The stale 2/3 last-action header after recovery is expected; current availability
  is the separate 3/3 readiness line. Long action text can clip at the window edge;
  the complete observed result is retained in Activity Log and console.
- A combined three-command chat paste generated an argument-parsing error. The
  subsequent separately executed stop/unload/start sequence succeeded. This is
  not evidence of a readiness-module failure. Enter test commands separately.
- Logs and screenshots are session observations, not assertions about all builds.

## Not tested

Active travel/navigation/sticking cancellation with v0.3.6; zero available
components; actual Unknown telemetry; absent DLL/failed initialization recovery;
missing ImGui; Nav/MoveUtils missing at startup; active-controller conflict
resolution; zone changes and navigation mesh/path validation; other builds or
servers. Refresh deduplication follows the inspected implementation but its
button click was not independently verifiable from still screenshots.

## Reproduction and safety

Stationary, out of combat, other automation not using the plugin. Never unload
MQ2Lua or MacroQuest for these optional-dependency checks. Use EverQuest chat;
enter one command and press Enter before proceeding. Example missing-Nav case:

```text
/plugin MQ2Nav unload noauto
```

Observe Not loaded and 2/3, click Stop All Movement, and inspect the skipped-name
result. Restore using Load MQ2Nav and verify Loaded/3/3. Repeat only for a specific
unverified case; no additional plugin unloading is required for this checkpoint.

Startup example: separately enter `/lua stop magfarm`, then
`/plugin MQ2EasyFind unload noauto`, then `/lua run magfarm`. Restore EasyFind via
its Load button after inspecting the missing-at-startup result.

## Post-checkpoint source/document inspection

The October 6 review export contained 12 current files and nine committed
baselines. All 12 current hashes matched the export manifest. config.lua and
state.lua matched their baselines after line-ending normalization. All 70 named
functions had WHAT/WHY/WHERE/HOW/WHEN labels. No additional client or compiler
test was run during review.

A later publication cleanup removes identifying names from comments/archived
notes and corrects stale function/module descriptions. The preparation check
compares executable Lua tokens before/after, not a new runtime behavior test.
Normal in-game names/settings are unchanged. Repository-history privacy results
are reported separately and are not assumed clean.

## Review gate

Documentation-only updater must not edit the tested Lua files or saved settings.
Review git status/diff, preserve unrelated changes and obtain approval before any
commit/push. No tag, release, merge or publication is implied by this record.
