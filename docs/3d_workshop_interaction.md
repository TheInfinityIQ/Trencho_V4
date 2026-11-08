# Rear Workshop interaction — bounded pre-code contract

Baseline `865957e82cebf6407249ca3fae5ef935eac89f87`, branch `codex/3d-workshop-interaction`. Pre-code `5648f891fcc07e068b746653a5f1b632b816b953` was committed before source and has Lead technical approval. [Diagram](diagrams/3d_workshop_interaction.mmd), [fixed observation](current_change/workshop_interaction.md), [status](3d_workshop_interaction.json). Lead owns publication/integration, final exact-source/visual review and the single remote process. T03 art stays deferred; its clean source-only branch and ignored findings remain intact.

## Confirmed missing connection and reusable UI

Preview currently queues selection only in the battlefield. Rear left click recaptures controls or commits a placement; no rear facility-selection route reaches BaseDemo._select. The existing Work panel already owns the needed recipe, mode/output-target and requested-worker controls, plus context_status from the actual activity snapshot with recipe/status/target/local inputs/missing inputs and present/assigned/requested/vacancy counts. Reuse those controls and backend owners; no duplicate production panel or new framework.

For player-built Workshops, Construction.activities[actual site ID] is the actual production owner and BaseDemo._select("site",site_id,true) resolves its facility metadata. The declared initial physical site is initial-workshop, while its existing production owner/duty is rear.production/workshop; resolve that specific existing declaration to _select("building","workshop",true). Preserve physical site ID versus logical UI duty in the interaction and receipt. Do not map an arbitrary constructed Workshop to the global workshop owner.

## Two-file interaction route

Add E to the current rear _unhandled_input path and the existing rear hint. It is available only while rear view is focused, controls captured, management/modal closed and no placement draft. Preserve left-click recapture/placement, camera controls, F5 normal entry and optional F6. Queue one request with current world/model/construction-service/camera identity; no hover prompt, per-frame scan or new reach/proximity rule.

Consume that request once inside the current _physics_process safe-query path, after any newly rebuilt geometry synchronizes. Cast from the current camera/reticle through its existing visible far plane using current mask5. First hit only: ground, table, truck, wall or other intervening geometry stops interaction; do not tunnel/search behind an occluder. No facility roster or inventory query is part of the ray.

World.refresh_rear tags each existing reservation with its actual site ID; the exterior shell already carries that metadata. A small World helper resolves metadata only through the hit collider's CURRENT collision-root ancestry. Preview then revalidates request identity, actual current Construction.instances row, Complete/workshop kind and exact current production owner before opening. Reject removed/replaced/stale or unsupported targets; do not select a cached ID, current ray from another session or a fallback unrelated owner. The initial-workshop mapping is explicit and valid only in the existing declared nonempty rear.

Call the existing _select with the resolved kind/logical ID, then open management/release held movement and cursor capture. Bring the selected facility controls into view using the existing scroll container if needed. Recipes, target/staff commands and status remain the existing metadata-based UI. Selection must not call default staffing, change recipe/target or replace the actual activity. Preserve once-only completion staffing and player edits. No production, construction, staffing, recipe, rates, qualification, grants, hauling or policy source changes.

The stale safety scope is the NEW queued interaction before opening and its selected-owner/metadata validation. Preserve existing Work-panel behavior after opening; do not expand into an audit or rewrite of all old stale-command/modal behavior. Report any concrete separate defect to Lead. Failure/unsupported-hit feedback can use the existing preview message/hint.

## Acceptance and verification limits

An E press aimed at an actual completed Workshop opens THAT owner's existing Work context with real rifle recipe/output target, requested versus present staff, actual local/missing ingredients and concrete current activity wait reason. One deliberate command through the existing UI changes the selected owner, not a different global facility. Initial declared and constructed-ID forms are source-reviewed; the one arranged observation exercises only one declared initial owner, not both forms at runtime.

The fixed proposal uses an existing declared prebuilt Workshop session, staged reachable exterior manager/view and the real E-to-physics-to-_select route, one real UI output-target edit and one readable management image. No debug completion/material grant, time advance, old production loop or regression matrix. It is arranged current-change UI evidence, not ordinary opening-to-earned-factory, actual rifle production, supply/repeat or FPS/native acceptance. Lead owns the one35s rendered child/45s wrapper process; no local engine.

Expected production files are only game/preview_3d/preview.gd and world_presenter.gd. No new assets/imports/workflow/UIDs. Maintain function purposes/map/HTML; preserve fixture, encoded evidence and all current sidecars. Check the COMPLETE baseline-to-final branch delta including added docs, not only the last patch.

Godot primary references: [ray-casting](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html) places direct-space queries in physics processing; [InputEvent flow](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html) allows GUI consumption before unhandled gameplay input. This increment reuses the project's existing pending-query style.

## Source handoff and stop boundary

The source candidate changes only Preview and World: current rear E queues identity-bound work, first-hit query resolves only current site geometry, and exact current owner/Work metadata is checked before opening. Existing reservation geometry gains site_id metadata; existing shells, services, UI and defaults are unchanged. The selected existing Work region is scrolled/focused only after deferred current-context revalidation. Two changed scripts and the ignored one-E/one-UI-target proposal parse successfully; final purposes/map/full branch checks are recorded in the handoff, with no engine or runtime claim.

The proposal uses direct _unhandled_input event injection to exercise the actual pending-to-physics route, not native OS/viewport input acceptance. It preserves physical initial-workshop versus logical workshop in the receipt and deliberately leaves the constructed-ID runtime path, broad occlusion/stale cases, earned production and normal factory/supply/repeat acceptance open. Existing recipe choices may use their current item codes; this bounded route does not relabel or rewrite the Work panel.

Dawson instructed this contributor to finish only this bounded task and then stop. Lead owns the remote demonstration, source/visual review, publication/integration and subsequent fixes/features. No successor or additional T03/asset/audit work follows this handoff.
