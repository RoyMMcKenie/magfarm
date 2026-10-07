# MagFarm changelog

## 0.3.6 - 2026-10-06 - Local validation checkpoint; publication pending

### Added
- Documented readiness.lua module with protected inventory reads, cached
  Loaded/Not loaded/Unknown states and explicit optional-plugin load requests.
- Startup Readiness panel, ImGui-binding verification and observation-only
  MQ2Melee status; plugin presence is not asserted to be an active conflict.
- Explicit EasyFind/Nav/MoveUtils Load buttons using documented load noauto.
- Bounded readiness transition and load-request/dispatch/result logging.

### Changed
- Stop All Movement refreshes dependencies and independently dispatches available
  components, reporting absent/unknown names and protected dispatch failures.
- UI stop control remains available for partial coverage and is gated at zero
  confirmed components; pet recovery is independent of movement prerequisites.
- Entry point verifies ImGui availability before requiring the UI.

### Public identity and comment cleanup
- Replaced identifying test-character/pet references in comments and archived
  compatibility notes with anonymous descriptions. In-game identities unchanged.
- Updated UI dependency/event descriptions and stop-dispatch wording; Lua
  executable tokens unchanged by this comment-only code cleanup.
- Documented the publication identity policy. History remains a separate audit
  and approval task; current-file redaction does not erase prior commits.

### Preserved
- No automatic plugin loading/unloading or gameplay automation.
- Existing character settings, config.lua and state.lua.
- Fixed-height scrolling Activity Log; resizing deferred as a future request.

### Validation
- Loaded detection, EasyFind-missing startup, GUI recovery for all three optional
  components, all-loaded idle dispatch and each one-missing idle dispatch were
  observed in user-provided client screenshots.
- Test record distinguishes observations from active-movement cancellation,
  unknown telemetry, all-missing and failed-load cases, which were not tested.
- README, architecture, compatibility, install notes and test record updated.
- This entry does not claim a commit, push, tag or public release exists.

## Previous changelog (preserved)

# MagFarm changelog

This record covers the current monitor branch. It replaces outdated legacy-attempt notes; it does not reconstruct historical releases or announce a new release/tag.

## 2026-10-06 - v0.3.5 save diagnostics

Code checkpoint: `cfb1359`, Add tested settings save diagnostics and activity logging.

- Updated `config.lua` and `ui.lua` only: 92 insertions and 17 deletions in the published code commit.
- Added successful-save counters, local timestamps, saved HP/Mana values and explicit pending status.
- Added bounded settings events for loads, operator edits, resets, successful writes and failures.
- Connected the event queue to the existing Activity Log once per tick.
- Kept schema version 1, defaults, validation, storage filenames, temporary/backup/rollback behavior and gameplay actions unchanged.
- In-game user verification showed HP=35/Mana=36, Saved #1 at 2026-10-06 16:22:32, and prompt Activity Log updates. This is a successful-save/visibility check, not failure-path or crash-recovery testing.

## 2026-10-06 - persistence baseline verification

- User confirmed edited thresholds HP=40/Mana=46 reloaded after stopping and restarting MagFarm.
- User confirmed explicit reset values HP=35/Mana=35 reloaded after restart.
- These tests preceded the diagnostics extension. The extension preserved the tested storage algorithm; reset-after-extension and cross-character behavior were not separately demonstrated by the recorded screenshots.

## 2026-10-06 - repository and local setup

- Moved all five Lua modules and package documentation to the repository root on `monitor-baseline-v0.3.5`.
- Removed the redundant nested `magfarm` repository folder; retained the installed Lua package folder name and `magfarm.` imports.
- Connected the user's existing installation location as the working copy, with Git metadata outside OneDrive and backups of previous local files.
- User verified the working branch, correct GitHub origin and clean synchronized status after publishing the diagnostics commit.

## Current limitations

No automatic gameplay or raid collection has been added. Startup plugin verification, injected save-failure tests, crash recovery and comprehensive role/resource boundary tests remain unverified or unimplemented as applicable.
