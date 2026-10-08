# v0.3.9 source reconciliation review

Recorded 2026-10-08. This is a review checkpoint, not a release. The documentation commit does not publish or update executable code. The branch still contains its inherited monitor baseline until a separate source commit is approved and completed.

## Intended nine-module source set

| Module | Source treatment |
|---|---|
| config.lua | Latest uploaded config source preserved; includes explicit retry/recovery interfaces. |
| movement.lua | Latest uploaded movement source preserved; explicit stop, pet recovery and guarded return only. |
| readiness.lua | Uploaded readiness source preserved; protected observation and explicitly requested plugin loading. |
| init.lua | Uploaded entry point retained; v0.3.9 runtime version and corrected header. |
| state.lua | Latest uploaded monitoring source plus reconstructed capturePosition compatibility export. |
| ui.lua | Latest uploaded UI plus reconstructed spell_rules require/tick/render integration hooks. |
| spell_model.lua | Decision functions extracted verbatim from the uploaded fictional-input test script. |
| spell_store.lua | Reconstructed from earlier candidate design and schema/API; not an exact installed-file copy. |
| spell_rules.lua | Reconstructed from uploaded standalone editor and integration/wording-cleanup changes; not an exact installed-file copy. |

The original fictional-input spell test script is retained separately under tests in the prepared local review package. Duplicate attachment suffixes are not module filenames. Preserved source may have newline normalization.

## Static reconciliation findings

The prepared local candidate contains nine runtime modules and one standalone test script. Twelve local module-interface relationships were checked with zero missing referenced exports. The model decision functions and original test content matched the uploaded basis. String/comment, delimiter and keyword-block balance checks passed. Hashes and file provenance were recorded in the local review manifest.

These are structural checks, not Lua compilation or MacroQuest runtime execution. The candidate is not asserted byte-for-byte identical to the installed client package.

## State compatibility repair

The uploaded UI calls state.capturePosition during normal camp processing and guarded return validation. The latest uploaded state source exported only capture. The reconciled candidate restores capturePosition without replacing current character/group monitoring code. Zero coordinates remain valid; unavailable/nonfinite coordinates or changing zone/spawn observations invalidate the position sample. No movement is initiated by collection.

## Known open defect

The preview status row can disappear and reappear, moving everything below it. The available editor clears shared preview results before rebuilding them and conditionally draws the row. That is consistent with the report but does not establish the exact live rendering timing.

The source reconciliation baseline deliberately retains this defect. A separate proposed repair will build a complete result batch before publishing it and reserve a stable status area. Neither implementation nor client verification of that repair is claimed here.

## Publication boundary

Preserve existing LICENSE, attribution and repository history. Do not publish local .git pointer files, personal settings or personal filesystem paths. A future source commit must include full exact file contents for approval. Update the current branch status after that source commit; do not label this branch synchronized in advance. No default-branch change, merge or release is authorized by this document.
