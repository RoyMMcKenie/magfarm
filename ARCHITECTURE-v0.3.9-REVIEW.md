# v0.3.9 intended architecture

Review candidate architecture; this document does not mean the source set is already present on this branch. See RECONCILIATION-v0.3.9.md for provenance and publication status.

## Runtime boundaries

- init.lua starts and stops the package, registers the main UI and drives its normal tick loop.
- ui.lua displays cached/observed information and queues explicit operator requests. It invokes spell_rules.tick outside rendering and spell_rules.render inside the main window.
- state.lua reads character, group, pet, target and spell information. capturePosition supplies finite local coordinates and stable reported zone/spawn identity for camp controls.
- config.lua owns existing per-character display thresholds and their retry/recovery diagnostics. Its .settings storage stays independent of spell-rule storage.
- readiness.lua observes runtime bindings and allowlisted optional plugins. Loads occur only after explicit operator requests.
- movement.lua owns existing explicit manual cancellation, pet recovery and guarded return-to-camp actions. Preview eligibility does not call this module.
- spell_model.lua is the pure validator/evaluator/order model. It has no TLO reads, file I/O or gameplay commands.
- spell_store.lua validates and persists owner-specific preview rules. File I/O is invoked outside ImGui rendering, on startup load or explicit Save/Reload requests.
- spell_rules.lua samples protected telemetry, owns the new-rule form and configured list, evaluates preview states and queues storage requests.

## Spell-rule contract

Rules pin spell name, spell ID and gem slot, plus a Boolean preview-inclusion flag, positive priority, whole-percent minimum Mana and target-HP ceiling, and the declared single-target NPC damage category. Exact spell/gem identity changes block the rule. Lower numeric priority sorts first, with insertion order as the tie break.

The category is operator-declared; spell effects are not independently classified. A matching selected NPC target is necessary but is not permission to attack or cast. Unknown observations remain unknown rather than authorizing execution.

## Intended persistence contract

Spell rules use separate owner-specific .rules files under mq.configDir. Server/character identifiers and spell names are hex-byte encoded. Schema 1 records are parsed as text, never executed. The reconstructed candidate bounds file size and rule count, validates all records and rejects duplicate spell IDs.

Save is explicit. Reload explicitly discards session edits only after a successful load. Temporary-file replacement and a previous-good backup are used; rollback is attempted after replacement failure. Unknown/corrupt/owner-mismatched files block saves. Missing primary with a backup requires manual recovery. No crash-proof/fsync durability guarantee is made. These failure paths need further testing.

## Display and safety

The new-rule form is separate from configured rules. Resetting its gem selector does not alter saved rule identity. Include in preview is not an execution switch. No automatic casting, targeting, memorization or attacks are part of the spell-rule subsystem. Cost, range, LOS, engagement and outside-player ownership are not verified. Camp anchors remain session-only.

Each code file must retain a documentation header/footer; every function must describe WHAT, WHY, WHERE, HOW and WHEN. The status-row flicker repair remains a separate unverified change.
