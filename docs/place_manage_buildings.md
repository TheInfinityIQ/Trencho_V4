# Place and manage buildings

The normal live3D opening starts at1x. Pause /1x /2x remain in management.
Diagnostic/standalone model factories retain their existing default speed.

Place a building on the overhead grid, return to it and press E, then set its
builders. Present builders can use a partial delivery of Building Materials;
they stop at the amount supported by real material and resume when more arrives.
Costs, total work, four-builder limit and exclusive worker ownership are retained.
Used materials are charged incrementally, rounding up the current earned work to
whole material units. They are never charged twice at completion. Site requests
subtract used, locally available and already inbound materials from total demand.

The cyan remainder and orange-edged solid building represent actual earned work,
revealed from ground to roof. Four corner pylons and orange tape mark construction.
The completion sequence is cosmetic: four scissors fade/swoop to the midpoints,
snip together and fade. Finite jointed tape pieces fall onto their own collision
ground, then pylons grow over0.5s and shrink over0.25s before all props clear.
The actual facility is usable as soon as its authoritative construction completes.
The sequence follows Pause /1x /2x; it does not own completion or inventory.

Cancellation removes the effects without a celebration and loses only materials
actually used. Remaining real goods require physical recovery. Builders continue
while the confirmation is open; its existing refresh shows the current used count
and explains that it can increase. The command still validates session, site,
selection and unfinished state, then reports the actual loss at cancellation.
This live warning was approved by the Game Designer9November; changing the used
count alone must not make the confirmation unusable at1x.

## Ownership and integration

[Frozen plan](feature_plans/place_manage_buildings_v1.json) and
[system diagram](diagrams/place_manage_buildings.mmd) precede production changes.
ConstructionService owns consumption/work/completion. The persistent scene-local
site adapter listens to its keyed signal; progress updates shader parameters
without recreating building meshes or collision bodies. Existing footprint,
access, placement and site picking stay with their current owners. Whole-mesh
and per-surface imported materials are restored on completion. Returning to an
already completed site does not replay its celebration. Cancellation, dismantling
and session replacement release the corresponding scene lifetime.

Workshop/Vehicle Works share the existing garage exterior; Munitions/Support/
Materials share the industrial exterior; Training uses the existing warehouse.
These licensed prototype exteriors are identified by site labels, not a promise
of finished bespoke art. Vehicle Park is an open ground slab, not an enclosed
building or an impassable routing obstacle. Fixed facilities remain unchanged.

The Artist owns the delivered pylon/tape/scissors meshes and authored snip clip;
Lead owns their Godot integration. Asset readiness and current direct-check
receipts are recorded separately from source implementation and player acceptance.
No local engine, regression suite or60FPS certification is part of this delivery.

## Engineering basis

Godot [spatial shaders](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)
support world-position varyings, clipping and material passes. They let the same
building geometry show complementary finished/unfinished regions. Bound
[Tweens](https://docs.godotengine.org/en/4.7/classes/class_tween.html) manage finite
runtime targets, and [RigidBody3D](https://docs.godotengine.org/en/4.7/classes/class_rigidbody3d.html)
provides gravity/contacts for temporary ribbon pieces. Those engine capabilities
support this design; the finite body count, isolated collision layer and
material/work authority are project choices. No standing world scan or new
gameplay clock is introduced for this feature.
