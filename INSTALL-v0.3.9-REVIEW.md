# v0.3.9 review installation boundary

Do not install this branch as a v0.3.9 package yet. The current documentation update does not publish the reconciled executable source. The local reconciliation archive is for review, not an instruction to replace the working installation. No EverQuest login or installation is required while client testing is unavailable.

## For a later approved source package

1. Save any intended unsaved rule edits and confirm a successful save message.
2. Quit the running package cleanly with /magfarm quit. If it has already crashed, its slash command may no longer be registered; /lua stop magfarm can stop a remaining named process.
3. Back up the existing lua/magfarm folder. Preserve settings separately; do not delete them.
4. Merge only the explicitly listed replacement source files into lua/magfarm. Do not delete or replace the entire folder.
5. Preserve LICENSE, attribution, documentation, local .git metadata and unrelated files. Do not restore older Lua files over the approved source set.
6. Restart with /lua run magfarm and verify startup before changing rules or manual camp controls.

The intended runtime set is init.lua, config.lua, state.lua, ui.lua, movement.lua, readiness.lua, spell_model.lua, spell_store.lua and spell_rules.lua. Uploaded duplicate suffixes are not installed filenames.

## Rule storage

Existing display .settings files are separate from spell .rules files. Save rules writes only after an explicit request. Unsaved edits are not automatically persisted at shutdown. Confirm Saved N rule(s) and No unsaved rule edits before restarting. Reload (discard unsaved edits) is not Save.

The prior standalone editor's session rules are not automatically migrated; add intended rules once in the integrated editor if no saved rules exist. Do not run the old standalone editor alongside the integrated editor during validation. Standalone model tests are not runtime dependencies.

## Rollback and backup recovery

If the candidate fails, stop it and restore the backed-up source package without deleting settings. Preserve the error and the failing source for diagnosis. Do not overwrite a malformed rules file just to silence an error. If a rules primary file is missing but a .bak exists, recovery is manual with the package stopped. Restore the intended backup to the primary filename only after preserving the current files.

No source installation, release certification or storage repair is performed by this document.
