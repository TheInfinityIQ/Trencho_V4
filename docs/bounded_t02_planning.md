# Incremental troop transport planning

This implements the next measured performance slice from the [engineering field guide](engineering_field_guide.md). Retained profiling identified synchronous T02 outward/return route admission as the main work in three opening frame stalls. Startup, changing views, other route callers and overall game responsiveness remain separate work.

## Plan and acceptance

1. Keep route calculations request-local and pure, with bounded inner work, ordered arithmetic and explicit unsupported cases.
2. Enqueue a cheap unreserved T02 descriptor during the existing policy decision. Complete the full rear fixed-point settle before capturing route inputs or pumping continuation work.
3. Retain running elapsed time as debt while planning holds the shared clock. Pause stops both future accrual and consumption of retained debt; speed changes apply prospectively. A live frame consumes at most 0.1 simulation seconds. No discarded debt or burst catch-up.
4. Revalidate current inputs, intent and physical ownership before reserving the manifest exactly once. Fresh departure after actual boarding and fresh empty return use the same bounded primitive.
5. Keep ordinary management and inspection available at the settled boundary. Clearly distinguish pending planning, Ready, actual boarding, movement and completion.

Acceptance requires that pure work never moves a person or hull, reserves a manifest or consumes fuel; Ready while paused never commits; changed commands/world/session cannot commit obsolete captures; current crew, passengers, payload, geometry, danger and fuel still govern. Chunk count cannot create policy decisions. A physical job keeps its existing hull and passengers through interrupted planning.

## Ownership and integration

`TerrainWorld.begin_route` owns the cell, height, cut sort, active sweep and part calculation. `Routes.begin_plan` composes it with the existing vehicle/profile/leg rules. Existing synchronous methods remain available for unaffected callers.

TroopTransport owns a FIFO of private admission/departure descriptors and continuations. Its public status contains no worker references. Pending descriptors do not claim people or hulls. Current hull/load/crew/endpoints, world identity/revision, current delivered information and the relevant acknowledged intent are rechecked before atomic admission. Callable identity alone cannot establish current mine knowledge. An empty return need not retain the old passenger transport intent after lawful dismount.

The live UI explicitly enables this path after creating its Farmland session. Direct non-live callers retain their synchronous behavior. Rear time advancement can return early only after a complete `_settle`, never from a partially executed sweep. Base pumps one private chunk at that boundary and completes another full settle after an actual domain transition.

Clock authority is fixed when enabling this mode: the UI uses the default wall-clock mode and `tick_live`; an explicit elapsed-time caller must enable with `false` and use `tick(seconds)`. Mixing clock sources is rejected. Explicit mode never adds wall time at speed changes or management commands. Known pure construction/dispatch/supply previews carry an inspection-only result flag and retain prepared route work; mutation-capable commands conservatively invalidate it regardless of whether their result is successful.

No authoritative advance, settle or commit yields; pure planning emits no session mutations; every live pump returns at a fully settled boundary. Management callbacks operate there in actual receipt order. This owner invariant does not assume that every Godot callback occurs before node processing: [deferred signals](https://docs.godotengine.org/en/4.7/classes/class_object.html#enum-object-connectflags) and [scene timers](https://docs.godotengine.org/en/4.7/classes/class_scenetreetimer.html) have other ordering. Their result hook invalidates private captures and completes their immediate effects before the next planning step or admission. Speed controls accrue elapsed time under the previous speed, then change speed without discarding pure route work. Starting a new session cancels obsolete private work before replacing the session.

This gives same-time completed engineering, production and already-received management effects precedence over a later transport reservation. It intentionally changes the old mid-sweep admission position; it does not claim identical global ordering to the old synchronous implementation. Existing policy tick/round-robin attempt order remains the admission request order.

## Resource limits and current evidence

The 128-unit/4000-microsecond work allowance is cooperative. Native allocation/release and fixed input capture are indivisible. Existing local passenger checks, mine and known-fire checks also remain explicit synchronous costs. The terrain helper documents finite support limits; exceeding one reports unsupported rather than changing a physical clearance rule or falling back to synchronous routing. Revision checks do not detect arbitrary direct container writes that omit a revision update.

The 0.1-second live consumption cap preserves all earlier event boundaries and retains debt; it does not establish requested-speed throughput. At ten rendered frames per second it permits at most one simulation second per wall second, even with 2x selected. Debt growth and clock lag remain observable limitations, and overall speed/responsiveness acceptance remains open.

On helper revision `3648e762020e857f6560cb5821200a066a0b9e6d`, [one brief GitHub direct check](https://github.com/TheInfinityIQ/Trencho_V4/actions/runs/41193498817) composed both new helpers for one canonical T02 route: 120 metres, 12 simulation seconds, 0.24 litres, completed over 51 frames. It left the hull unchanged and invalidated the completed result after an authored terrain revision. It did not exercise live admission, the full opening, Windows responsiveness or a hard step latency maximum.

Follow the [current verification instruction](current_change_verification.md): no regression writing, suites, matrices or unchanged scenarios until the main game is complete. Only brief direct demonstrations of the actual new code are permitted, on GitHub under the desktop resource restriction.
