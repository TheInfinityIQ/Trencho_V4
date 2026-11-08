# Rear worker 3D presentation contract

Assigned to C on `codex/3d-rear-workers`, from Office merge `2e03004c55a07515ef0c1af33989e17735bddd39`. Commit this contract, [ownership diagram](diagrams/3d_rear_workers.mmd) and [explicit observation scope](current_change/rear_workers.md) before production code. Lead owns actual remote evidence, the new script UID, reviews and integration. No local engine, new imports, animation download or regression suite.

## Bounded outcome

Present one scene-owned visual per real living player rear actor. Reuse the already imported manager mesh, skin and neutral idle at the same 1.8 m scale. Worker ID and actual assignment/duty labels distinguish workers from the separately labelled “You · controlled manager.” The manager remains outside the ledger actor set and remains the only controllable character. This adds no worker control or collision body.

Only actual committed ledger endpoints position the worker visual. No new workforce, route, movement, collision, stock or clock owner is introduced. Existing management retains commands. Neutral idle during endpoint motion, missing walk/carry/work animations and opaque-shell occlusion are explicit limits; do not relocate a person or imply enterable interiors to improve the art.

## Narrow detached read and event ownership

Add one ledger presentation query over supplied rear actor IDs. Read keyed Person records, their immediate holder kind, keyed actual carried Stock and holder-relative world position. Return detached scalar/vector facts: identity, owner, health, assignment, duty, rear occupancy, holder kind, position and actual held stock ID/type/count. Exclude non-player, dead, non-Occupied rear and carrier-held people using existing physical facts. Do not invent eligibility or duty rules. Do not call inspect_entity/inspect_person_status, scan claims/occupants/inventory or enumerate the global ledger in this query.

Coalesce membership/role/cargo refreshes at session command/settlement state changes. The existing Preview session binding forwards to its current world; the new scene-owned presenter binds only its current ledger and disconnects on tree exit/replacement. Existing entity_moved updates only an already eligible affected visual, cached endpoint and heading. It performs no inspection or roster rebuild. Do not use time_advanced as a roster poll or add per-frame scans.

Carry art is a representative cue labelled with the real held type/count only when the stock holder is that person. Incoming, promised and reserved goods are never displayed as carried goods. Hidden roots affect only visibility; session gameplay continues independently.

## Implementation and acceptance

A small feature-local worker presenter composes the existing human factory with role/cargo labels and a non-colliding parcel cue. Extract only the manager's existing human creation steps needed for exact mesh/skin/idle reuse, retaining its prior tree/animation binding order. The 3D preview adds the manager's control identity label and forwards state refreshes. All other camera, construction and management behavior is unchanged.

The fixed current-change observation is one explicitly arranged real worker, an actual three-unit M11 carry through public APIs and one genuine ledger movement endpoint, then one actual worker/manager screenshot. It asserts stable identity, position, held count and no worker collision. Dead/away/boarding filters are source-reviewed with unexercised limits, not a runtime matrix. No ordinary hire/haul loop, extra scenario, native controls or FPS claim.

C supplies exact frozen source, reviewed purposes/maps and the ignored proposal. Lead runs required engine parsing and the one 35-second rendered child within the existing 45-second process, retains the actual new script UID and requests exact-head technical/Designer/UI/UX decisions. Actual image readability and source review gate merge.

## Source handoff limits

The projection and scene adapter are implemented with the event ownership above. Direct syntax parsing passed the four changed production scripts and the ignored proposal. No new assets or import-list change is needed; the actual new helper UID remains Lead-owned. [Feature status](3d_rear_workers.json) records the exact source and limitations. Engine execution, the single actual image and exact-head visual decisions remain pending. No regression or local engine check was performed.

## First actual observation and narrow correction

Required validation `42449796720` and the fixed arranged observation `42449801128` passed at `81cbfb57` (artifact `13605261796`). C viewed the original image: the long manager label overlapped the worker duty line. Designer and UI/UX requested only a compact two-line manager identity, “You” then “Manager,” at the same position and colour. Worker roles/cargo, camera and exact proposal remain unchanged. Preserve the first functional PASS and original image; corrected visual acceptance is pending. No other source, scene, scenario or engine limit changed.

## Actual current-change evidence

Required 42450137343 and the single arranged worker observation 42450178511 passed at `1541f28c2aa6ce5247cd88256ac803989ff4ce63`. The worker visual follows the real `(10,90) → (22,90)` ledger endpoint event, retains the same person and carried stock identity, and shows three actual M11 units with no worker collision body. The actual manager remains separate. See [stored image and scoped receipt](evidence/rear_workers.json). Actual engine-generated helper UID retained; no imports or workflow changes.

The earlier functional pass 42449801128 exposed overlap between the long manager label and worker duty text. The compact player identity corrects this current-feature readability issue; the original capture remains documented. Exact-source Designer/UI/UX image decisions and final-head technical records belong to [PR #125](https://github.com/TheInfinityIQ/Trencho_V4/pull/125). These staged entities/poses do not establish ordinary hiring/hauling, native controls, full animation or FPS.
