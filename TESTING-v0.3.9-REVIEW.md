# v0.3.9 validation record and pending checks

Recorded 2026-10-08. Separate observations of the earlier installed client version from checks of the reconstructed review candidate. This document does not certify the current GitHub branch as v0.3.9 executable source.

## Client-observed earlier installed version

- Monitor startup succeeded after the state.capturePosition compatibility repair was installed.
- Integrated rule creation and Include in preview worked.
- One rule saved successfully with no unsaved edits. After clean quit/restart, its spell identity, gem, preview flag, priority and resource thresholds reloaded.
- Existing display thresholds loaded separately.
- Preview blocking was observed for PC/corpse assist targets and an absent reported assist target.
- UI cleanup displayed separate new-rule/configured-rule sections and removed the stale session-only message.
- The user observed disappearing status text causing layout movement; that defect remains open.

The earlier fictional-input model test batch reported 36 PASS, 0 FAIL. Those tests validate model behavior, not live casting or client collector completeness.

## Prepared local reconciliation candidate

Nine runtime modules and one preserved standalone fictional-input test script were prepared. Static interface inspection found no missing named exports in twelve checked local module relationships. String/comment, delimiter and keyword-block balance checks passed. Extracted decision functions and test content matched the uploaded basis. Provenance and SHA-256 hashes were recorded in a local review manifest.

No Lua compilation, MacroQuest execution or client runtime testing of this reconstructed candidate was performed. Prior installed-version observations must not be relabelled as tests of reconstructed files.

## Pending offline/client checks

- Compile/parse the exact source set with a compatible Lua runtime.
- Repeat relevant model tests only when decision logic changes or source reconciliation warrants regression checking.
- Exercise protected live readings: missing members, unknown values and changed gem identity.
- Exercise schema validation, malformed records, unknown schemas, duplicate rules and oversized input.
- Exercise denied writes, short/write/close errors, rename failures and rollback failures without damaging good data.
- Verify cross-server/character isolation and multiple-rule save/load on client.
- Check the status-row repair separately for stable layout while genuine BLOCKED/UNKNOWN/eligible-preview states change.
- Verify manual safety controls and existing display persistence after source synchronization.

## Future narrow save/reload check

After an approved installation and successful startup, add one intended rule, enable only its preview flag, explicitly Save and confirm success, then quit/restart and verify exact restored values. Do not cast, enter combat or change targets merely to manufacture eligibility. No automatic gameplay behavior should be added for a persistence test.

Keep failures and unverified cases visible. Do not declare a release, a flicker fix or safe spell execution from this checkpoint. EverQuest testing is currently unavailable; repository documentation and source review can proceed without it.
