# Current objective ownership and state in the 3D RTS view

Contract published before source, baseline `f29b02403cb998de6e3bcf7c77b730a9b45e5f3c`, branch `codex/3d-field-objectives`. The source candidate is recorded below; no engine observation or runtime acceptance yet. Lead owns integration and the single remote demonstration. [Diagram](diagrams/3d_field_objectives.mmd), [fixed proposal](current_change/field_objectives.md), [status](3d_field_objectives.json).

## Confirmed narrow defect and existing authority

BattlefieldPresentation._entity_marker already reads the current registered objective owner and computes ownership_label/ownership_colour for each permitted PLACE row. World.refresh_markers uses that colour only inside `if not markers.has(row.id)` when constructing a PLACE cube. For a retained proxy, subsequent refreshes update position/visibility but leave its material unchanged. World.refresh_marker_positions also updates only pose/visibility. An existing objective therefore has no source path that reapplies its newly committed ownership colour after capture. This is a confirmed source defect, not an observed capture result.

ObjectiveService.register records the actual PLACE position, owner empty, state Neutral and control0. Its settle method owns changes to owner, Neutral/Controlled/Contested state and latest_change. advance_to owns control/income progression. RearSimulation._settle consumes the returned changed flag and emits state_changed after finite settlement; reached simulation boundaries also emit state_changed. GameSession forwards this to Preview._state_changed, which coalesces _field_dirty. The current battlefield physics refresh then consumes one fresh Policy result and invalidates inspection. No new service signal or simulation tick is needed. Control-only progress remains in the existing inspection, refreshed by its current time notifications; do not add a progress bar or per-frame objective inspection.

IdentityLedger.add_place creates a finite, root PLACE. Its move_entity API rejects PLACE, and ObjectiveService stores the registration position. No public objective/place relocation exists in this narrow path. Presentation uses current permitted PLACE position plus combat.world.ground(position) at initial/coalesced refresh. Private unsignalled position writes are not a supported movement boundary. Terrain-dependent height is refreshed through the same existing state boundary, without holder or terrain polling.

## Exact population and information boundary

Support only the intersection of CURRENT permitted Policy PLACE rows and actual ObjectiveService registrations of Resource, Route Hub or Observation. Current normal Farmland creation registers these nine IDs:

| Actual ID | Kind | Initial ground coordinates |
| --- | --- | --- |
| resource-west-blue | Resource | 800,2600 |
| resource-centre-blue | Resource | 2000,2600 |
| resource-east-blue | Resource | 3200,2600 |
| resource-west-red | Resource | 800,3400 |
| resource-centre-red | Resource | 2000,3400 |
| resource-east-red | Resource | 3200,3400 |
| route-hub-west | Route Hub | 1000,3000 |
| route-hub-east | Route Hub | 3000,3000 |
| observation-central | Observation | 2000,3000 |

The blue/red suffix describes the authored location, not ownership. All registrations initially have owner empty/state Neutral. Derive current ownership exclusively from ObjectiveService, never the ID, nearby unit, starting side or ledger PLACE.owner (which is separate and remains unchanged).

HQ berth, declared enemy HQ and other order-only/nonregistered places retain their existing proxy and inspection behavior. CONTACT remains report-only; no enemy truth, participant lists, hidden unit pose, control orders or objective rules are exposed. Friendly PERSON/T01 presentation and other carriers remain unchanged. This does not introduce a building type, interior, headquarters model, new asset, capture-radius graphic or terrain/collision representation.

## Small proposed presentation composition

Enrich the existing registered-objective branch of Policy._entity_marker with only objective_kind and objective_state scalars from the same keyed objective row already used for ownership. Retain ownership_label/colour and permitted PLACE position. Do not overwrite entity.owner, copy the full ObjectiveService.inspect result, return blue/red participant or blocker arrays, or broaden which places Policy admits. Existing inspection receives the same additive metadata and keeps its current readable titles and objective feedback.

Add one scene-owned field_objectives presenter under the existing battlefield marker root. Consume the caller's ONE current Policy result; cache an actual ground Node3D anchor and detached permitted scalar view per supported ID. Replace only its old objective proxy reference in World.markers and exclude represented objectives from the legacy timed proxy-position loop. Preserve marker_rows order, current first-row ties and strict nearest<18px inspection. Unsupported PLACE rows retain their old path.

Add one bounded field_objective_cues Control, following the current cached projection pattern without replacing PERSON/T01 helpers or creating a generic framework. Proposed symbol: fixed6px-radius ownership-coloured circle, black outer outline and coloured inner outline. Always show a two-line label beside the current visible objective: existing readable _site_label title, then current ownership_label and actual objective_state. Use an explicit existing-title formatter dependency; draw from cached strings rather than invoking inspection while drawing. Proposed14px text/18px line spacing, black outline/shadow, fixed screen size; selected actual ID uses the existing9px ring convention. This is a location symbol, not a world-scale object or 25m capture-zone boundary.

Ownership colours stay Policy's existing friendly blue74c8ed, enemy red e48378 and neutral gold f0c565. Reconcile colour, ownership text and state on EVERY changed current view, including an already existing anchor. Equality guards compare the same cached scalar fields/ground point, so an owner/state change cannot be discarded merely because position is unchanged. Cue drawing and objective picking share the same cached current-camera point and behind/offscreen/finite predicate. Camera/view/viewport invalidations reproject cached anchors only; no ledger, objective inspect, roster or holder reads in drawing, picking projection or a new per-frame loop.

The current state/coalesced Policy boundary is sufficient for owner/state updates. If battlefield is hidden, retain the current dirty flag and reconcile fresh Policy on return before presenting it; simulation progress remains with existing owners. On objective removal or world/session replacement, disconnect old presenter/camera bindings and erase World/cue references before freeing anchors. Keep current camera pitch -65 degrees, height3400, zoom10..6500, reachable pan and existing management/modal visibility unchanged.

## Proposed source boundary and acceptance

Expected production scope after review: BattlefieldPresentation scalar metadata, new field_objectives.gd and field_objective_cues.gd, World composition/reconciliation and Preview cue/inspection invalidations. No ObjectiveService capture/income changes, identity/control writes, new service events, shared inspector rewrite, orders, asset acquisition, workflow or solid-contact source. Lead owns actual new script UIDs after any future remote process.

Acceptance: a current permitted registered objective has exactly one ground anchor, readable title/ownership/state and correct Policy colour; an existing anchor consumes changed owner/state/colour when the normal coalesced current Policy refresh arrives. Selection resolves the same actual permitted ID through existing inspection. Neutral/Controlled/Contested and current ownership remain distinct facts; colour alone does not substitute for text.

The single proposed direct observation uses untouched existing resource-centre-blue at the normal paused opening, one reachable normal-camera size500 view and one image/current selection. No time advance, unit staging, forced owner/control/state, synthetic signal or capture replay. It can establish only initial neutral representation/colour/state/terrain/selection, not a real ownership/state transition. Transition behavior is source-reviewed and runtime acceptance explicitly OPEN until a later genuinely scoped actual capture opportunity. Do not close that gap using a fake event or broad combat setup. Whole-map label overlap, all nine simultaneous visibility, native input/FPS and complete battlefield acceptance also remain unverified.

Planning checks: JSON/document/map/whole branch-delta whitespace checks only, including all added files. Preserve the repaired main's exact base64 failure-log representation and prior evidence; no evidence mutation belongs to this objective plan. No local engine, executable or automatic process.

## Source candidate after approved pre-code publication

Lead approved exact pre-code `914d799f34047487de60b6c2445c2326795f35ab` before implementation. The candidate adds the two permitted objective scalars in Policy, scene-owned ground anchors with complete scalar-view equality guards, cached two-line ownership/state cues and explicit existing title-formatter dependency, plus World/Preview composition and current pick/invalidation integration. Registered objectives leave the timed legacy proxy loop; unsupported places and existing people/trucks/contacts keep their previous path. No objective, identity, order, income, inspection, asset or workflow source changed.

Five changed production scripts and the single ignored untouched-objective proposal pass syntax parsing; final map/purpose/HTML and entire branch-delta checks are reported in the frozen handoff. Lead owns actual new script UIDs, one35s rendered/45s wrapper observation, image/receipt and role acceptance. Actual ownership/contested/controlled transition runtime acceptance remains OPEN, even if that initial neutral observation passes. No engine process by this source owner.
