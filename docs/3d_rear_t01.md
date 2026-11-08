# Selected pre-code contract: actual player Rear T01 presentation

Status: Lead approved the bounded source contract and assigned codex/3d-rear-t01 from main fa0950b9f449a132865a74cbd6068daffb3f02ae. This contract, diagram and fixed single observation definition are committed before production. No new asset search/import, local engine run or repeated truck audit. Original read-only source proof remains in ignored logs/3d-rear-t01-proposal/source_proof.json.

## Accepted source and bounded outcome

Reuse only the already cleared Car Kit truck_flat.glb, its own palette, scale/origin and EXACT same two query boxes. Retain 4.941206 m art within unchanged 7 x 2.7 m T01 reservation. Unit AnimatableBody3D, sync_to_physics=true, layer 4/mask 0; manager mask 1 and camera/picking mask 5 unchanged. Manager blocking remains absent. No supplier External service change, T02-T05, Army RTS art/information change, new model/asset/import, routes, inventory/index, crew/seating, payload or driving rule.

One detailed rear T01 body per actual qualifying hull, created at existing registration/state boundaries and moved from keyed canonical ledger facts. Construction utility presenter retains its existing registry, created flag, labels, retained-person distinctions and lifecycle semantics.

## Exact membership and ownership predicate

Proposed rear_t01_views(registry_rows, player) iterates only supplied rear.vehicles.vehicles rows. Skip utility=true rows before keyed ledger lookup. For each supplied ID require ALL:

- Actual entity exists, kind CARRIER and design_type T01, with nonempty canonical vehicle_spec.
- Actual fleet_domain == Rear, owner == player AND controller == player. Owner alone is insufficient.
- Actual immediate holder exists and is PLACE; keyed holder-chain world position and canonical facing_degrees are finite.
- wreck_cleared is false. Do not reject solely for health<=0, damage_immobilized, towing, stopped fuel, or a retained registry row.

The new projection returns detached identity, current domain/controller/holder/pose and hull health/immobilized/state only. It copies no entity object, vehicle_spec dictionary, occupant/cargo list or inventory. No broad inspect_entity/snapshot/map_markers, global entity scan or per-hull manifest search. The keyed rear_t01_pose uses the same actual hull predicate; movement never asks for state, stock, crew or label data.

Holder PLACE is deliberate, not a fixed name whitelist. Actual manufactured bays have dynamic IDs; legitimate rear-owned dispatch hulls move through rear, dispatch berths, hq-queue and hq-berth before transfer. Current dispatch advance_to even uses holder rear for physical route positions outside the rear field. Neither a holder named rear nor crossing X=240 proves fleet ownership. Do not infer a transfer from geometry or rename/place/type/fleet state directly.

The actual complete_hq_hull_receipt boundary requires Rear plus holder hq-berth, then changes domain to Military and controller to army-blue-hq while owner remains army-blue. It does not erase rear.vehicles.vehicles. Thus the domain/controller predicate removes the retained ID after the existing session state notification; no new army model is created. Strategic Delivery can remain Rear at HQ and return as the same ID: do not remove it solely because holder is hq-berth.

Construction domain is disjoint from Rear, and its rear vehicle row also has utility=true. Pending Construction created=false never becomes a Rear T01 through a shared row. No construction row migration or second loose/seated person.

## Scene and event ownership

Add a scene-owned rear_t01_trucks presenter beside utility_trucks. Membership/state refresh is coalesced from existing session state_changed and initial bind, independent of which area is visible. Cache one body per actual ID. On entity_moved, affect only a cached ID, read keyed canonical pose and assign the complete transform atomically with yaw 90 degrees minus ledger.facing_degrees. Do not duplicate ledger displacement/heading thresholds. If an affected cached ID is no longer eligible, detach/free it; no roster scan on movement. State refresh detaches freed/cleared/transferred IDs. Disconnect ledger bindings immediately on world exit/replacement.

Rear and field roots already toggle exclusively in Preview._apply_view. This slice adds no battlefield presenter or contact knowledge. An eligible Rear-owned hull may travel beyond rear ground while remaining in the rear-owned cache; use its actual canonical position rather than clamp/teleport/hide it by invented domain rules. Existing battlefield cubes/X<240 heuristic are unchanged and remain a separate partial adapter. One detailed model per actual hull is owned by exactly one of the two disjoint rear presenters; there is never a second detailed rear-owned model after true HQ transfer.

Minimal new label: actual hull ID, Rear fleet / T01, actual hull condition. Omit fuel, occupancy/cargo quantities, crew claims and dispatch phase. Rear handling rows can retain Departed while manifest state advances, so do not display their stale phase as current transport state or introduce another manifest index. Existing management remains the source for logistics phase/fuel/crew/inventory. Preserve the current Construction utility label verbatim.

## Minimal shared selected-T01 body helper

Propose one small t01_presentation.gd helper for selected asset constants, create_body(id) and atomic apply_pose(body, pose). It owns only the exact art normalizer, original five meshes, two boxes and existing TruckState label setup. No fleet registration, eligibility, policy selection, scans, commands or clock. Normal ResourceLoader caching can serve the same PackedScene; no autoload/global fleet framework.

utility_trucks delegates body/pose construction to that helper but keeps bind/model/ledger/event cache, registry membership, _apply_state and all public body names/meta/geometry. Preserve its currently referenced MODEL_PATH/scale/box constants as aliases if needed. rear_t01_trucks calls the same helper and supplies its minimal own text. Technical review must compare the extracted geometry/normalizer/masks/label setup to the accepted utility source; the new single observation exercises the shared factory for the newly commissioned Rear hull. No extra utility re-demonstration or image audit.

No new data imports. Two new script UIDs (helper/presenter) must be actual engine-produced artifacts under Lead ownership. Lead owns workflow if any necessary integration change is found, remote check, reviews/PR/merge. C must commit the accepted contract/diagram/fixed definition before production after branch assignment.

## Acceptance and fixed observation

See [the fixed observation definition](current_change/rear_t01.md). One arranged commissioning uses actual existing reserve_rear_hull -> create_heavy_output -> vehicles.register_output boundaries, not direct domain/controller/state insertion. This is the same creation/registration sequence invoked by heavy_production._create_output after earned work, but the observation does not earn that work.

Observe one new Rear T01 with one genuine canonical pose update, one screenshot and then actual public HQ hull receipt after explicitly staging that same hull at hq-berth. Owner and rear registry remain; Rear presenter disappears after state notification. No dispatch/haul/factory loop, driver creation, passenger/cargo case matrix, new ray/arm/geometry audit, native input or FPS. Existing Construction duplicate exclusion and health/recovery/Strategic Delivery distinctions remain honestly source-reviewed. Lead owns remote evidence and integration; this arranged observation cannot establish full gameplay acceptance.

Registration API detail: vehicles.register_output returns void. The direct observation calls it without a result and verifies actual registration/identity/domain postconditions. Only Dictionary-returning APIs have their ok field asserted; no backend API change is needed.
