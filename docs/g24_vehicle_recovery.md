# G24 vehicle destruction and recovery

GDD9.5 owns the values. The scene-owned recovery service shares G01 identities, stock and the rear clock; its bounded review is available from the main selector at the fixed 1280×720 development size. Scenario initial conditions are declared in `recovery_fixture.gd`; buttons invoke real damage, repair, coupling and crossing services. They do not establish production presentation or autonomous recovery AI.

## Ownership and physical outcomes

The ledger emits `vehicle_damaged` synchronously after penetrating surface damage. It records `last_damage_at`, persistent `damage_immobilized`, and a once-only `destruction_resolved` marker. Recovery commits that marker before occupant callbacks, fuel loss, claim release or salvage. Existing G21 `apply_heavy_damage` delegates vehicle hits to G23's authoritative Top surface; demolition's legacy ejection fallback is suppressed after G24 resolves destruction. Its external blast uses pre-impact seated identities, preventing a second hit on newly ejected people. G22 can call `apply_device_damage` for Bottom penetration and surviving immobilization.

Active occupants receive60injury/80suppression; prior incapacitation causes one recorded death. The nearest supported metre candidate outside the hull and within8m is selected using the person's whole footprint. Deep water or no survivable exit kills occupants. Loose freight and hull ammunition retain half per type across all stacks, rounded down; existing claims release. Personal gear is tagged on dropping and retains its normal casualty ownership, separately from vehicle freight. Surviving freight forms an owned ground pile. Fuel is recorded as lost, distinct from travel burn. A land wreck blocks its footprint until20M11 and60engineer work seconds clear it; no Metal is generated. No repair resurrects a zero-health hull.

## Repair and towing

Health repair costs10nearby unreserved ground M11 and40work for100capped health. The separate mobility action costs20M11/60work, restores100health once, and clears the persistent immobilization flag. Health thresholds, actual driver, fuel and terrain support remain independent motion conditions. One or two distinct P02 with E08 must remain within2m of the hull footprint on accessible ground. Material commits once; eligibility or safety interruption preserves work without progress. Cancellation consumes committed materials without granting health. No visible hostile within150m and no hull damage within10s are required. Existing S09 repair retains its staffed-bay constraints and checks G24 hull safety; the services share engineer and target commitments.

Attaching/detaching consumes20active stationary seconds from one actual P02/E08. T01 accepts a disabled T03 or E13 up to3000kg; T05 accepts a disabled friendly vehicle or gun up to35000kg. Tow chains and wreck recovery into working hulls are refused. Towing excludes tractor firing, sums real contents/crew/ammunition/fuel for bridge admission, moves both physical objects, uses quarter normal speed and twice fuel, and preserves12m spacing in the existing straight-lane fixture. Turning requires20m clearance. The recovery service also exposes a measured straight world lane; each object retains terrain access. B02 rejects a tank combination and B03 admits a legal actual load below80000kg. Existing G21 load fixtures now seed an actual coupling explicitly; G24 covers timed creation.

## Interruption and persistence

The service owns repair jobs, exclusive worker commitments, coupling jobs and measured tow journeys. Progress advances only at shared chronological boundaries. Engineers leaving, losing kit/qualification/health, unsafe conditions, damage or lost coupling block applicable work. No per-frame gameplay polling is added. A restored G32 save must serialize the new ledger damage/destruction/wreck/tow fields, fuel-loss accounting, stock personal-gear provenance, service jobs/progress/last times, coupled identities, journeys and events; restore the single damage subscription and rebuild wreck obstacles before simulation resumes. Whole-game save/restore remains G32.

## Validation scope

The focused regression runner covers A41 identities, rounded salvage, repeated damage, casualty gear, water/no-exit outcomes, paid clearance, interrupted health/mobility work and A42 timed coupling, real loaded bridge traversal, firing restriction and fuel. A display-backed input case exercises destruction, health/mobility repair and towing through actual mouse input and captures1280×720 views. Results and remaining limitations belong in the complete PR evidence; these test definitions alone do not establish a pass.

Source prerequisites: accepted G23 `116e221c93ec587c6d9209ce9eb537cef5cf2a07` and accepted G21 `b58e825ee74e83076a7d7b3a75c023dc9c8570a4`. Both remain subject to Designer integration; this branch reconciles their shared boundary without claiming either merged or released.

## PR82 combined review fixes

The review candidate integrates main `815d974` through PR81 candidate `2cb8f678983935ab37339633e6459b5cda5bab4e`. Recovery engineers must occupy independent ground PLACE holders: being a nearby seated passenger with a kit grants no repair or coupling work. New repair/coupling starts check mine and demolition commitments, and those services reject recovery commitments; ongoing rate checks preserve each job's own ownership.

Ordinary tow journeys and coupled bridge traffic limit both actual hulls to the earliest G22 swept mine contact. They charge only prefix fuel before synchronous damage, re-read health and coupling after movement callbacks, and stop instead of moving stale targets or rolling wrecks back. Bridge traffic rejects already destroyed/immobilized tractors and dead or uncoupled tow objects before spending fuel or moving; an already immobilized tow target remains legal. G22 stationary blast/remote checks use the hull's actual orientation, and movement contact uses the swept lane direction. A surviving penetrating device hit retains its once-only 10 occupant injury; only destruction delegates its occupant consequences to G24.

Focused review evidence adds actual boarding/disembarkation and symmetric scan/recovery exclusions, tractor destruction and survival, trailing contact with secondary blast, rotated stationary blast, and bridge approach destruction/fuel/uncoupling. The combined regression is registered in the normal repository gate. Local results and final combined-head CI are reported in PR82; no duplicate full run is required for an unchanged ancestry-only main integration.

Old PR82 CI also exposed R01 input setup still using 1000×720 and 960×640 after the review selector grew. Both R01 cases now use the single supported 1280×720 development size throughout, retaining all behavior and scrolling assertions; both affected input cases passed locally. This is a test-setup alignment under the fixed-screen policy, with no production or balance change.
