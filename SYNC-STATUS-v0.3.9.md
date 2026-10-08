# MagFarm v0.3.9 synchronization status

Recorded: 2026-10-08.

## Branch status

This branch was created from monitor-baseline-v0.3.5 at commit ccc690096d0d6e7bd3fae5c65951a3209e60af33. This document does not update executable code. Until a subsequent source synchronization commit is reviewed, do not treat this branch as the complete v0.3.9 package. Existing legacy and main branches are unchanged by this update.

## Client-observed validation

The following observations concern the locally installed candidate tested during development, not a certification of the current branch contents:

- The v0.3.9 monitor starts and displays its integrated spell-rule panel after restoring the missing state.capturePosition export.
- A single configured rule was explicitly saved and restored after a clean package quit/restart. Spell name, spell ID, gem slot, Include in preview flag, priority, minimum Mana and target-HP ceiling were restored.
- Existing display-threshold settings loaded separately from spell-rule storage.
- Live preview rejection was observed for player/corpse assist targets and for an absent reported assist target.
- The UI wording cleanup separates the new-rule form from configured rules and removes stale session-only messages.
- The earlier fictional-input spell decision suite reported 36 passes and 0 failures. This was a model test, not live casting validation.

## Known open defect

The preview status row can disappear and reappear, shifting the Remove button and all content below it. The user isolated this movement to the BLOCKED status row.

The editor code available for inspection clears a shared preview-results table before rebuilding it and conditionally draws the status row. This is consistent with the reported symptom, but the precise live rendering timing has not been traced.

Proposed repair: build the next result batch separately, publish the completed batch, and reserve a stable status area per configured rule with an explicit pending/unknown state. No repair is claimed complete or client-verified here.

## Validation still outstanding

- Corrupt and unsupported-schema rule files.
- Write, rename, backup and rollback failures.
- Cross-character/server storage isolation on the client.
- Multiple-rule and duplicate-rule persistence paths.
- Changed-gem identity blocking on the client.
- Status-row layout repair and visual regression testing.

## Synchronization requirements

Reconcile the uploaded source modules, generated candidate modules, state compatibility repair, UI cleanup and tests before publishing a coherent source commit. Any reconstructed component must be explicitly identified as reconstructed rather than an exact copy of the installed file. Preserve prior repository history and license/attribution.

Update README, changelog, architecture, compatibility and installation/testing documentation alongside the source. Installation instructions must say to merge named files and never imply that users should delete the existing package folder.

Do not publish local .git pointer files, character settings, personal filesystem paths or private configuration. Duplicate-upload numeric suffixes are not actual module filenames.

## Documentation and safety boundaries

Each code file must have a documentation header and footer. Every function must document WHAT, WHY, WHERE, HOW and WHEN.

Spell rules remain preview-only. Include in preview does not authorize casting. No automatic targeting, memorization, attacks or spell execution are part of this checkpoint. Spell category is operator-declared; spell cost, range, line of sight, engagement and outside-player ownership are not verified. Existing manual safety controls are separate from preview eligibility.

EverQuest is currently unavailable for further client testing. Offline inspections and checks must be labelled separately from client runtime passes. No release certification, default-branch change or merge is implied by this document.
