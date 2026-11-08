# Selected Construction Office utility-truck presentation contract

**Selected:** original Kenney Car Kit 3.1 `Models/GLB format/truck-flat.glb`, bundled CC0. Lead approved the exact selected contract and two-box approximation before implementation on `codex/3d-utility-truck`, based on worker merge `20ccb777920417c93c71e5f30c01a6fecc0d81aa`. This document and the ownership diagram are committed before production code. Actual import and bounded source/visual acceptance are recorded below; no local engine or regression run. Only this candidate's geometry was inspected; the supplied truck/delivery-flat thumbnails were viewed but their models were not inspected.

## Exact source and transformed fit

Lead obtained the original through the normal creator browser Download → Continue without donating flow. C verified the supplied 4,814,237-byte ZIP, SHA256 `fac7dacac5c7874348cf19729af3ef205f3d366493edaf0a827d93f4fdf3d0c4`. The earlier cached HTML and public endpoint 403 remain in the parent receipt; acquisition is now resolved. Exact model, palette and license provenance will be retained in `docs/3d_utility_truck_assets.json`; the original selected receipt remains in ignored research logs.

Five scene roots are four separate wheel meshes and the combined body. Apply their actual translations: front axles Z 0.7825572, rear axles Z -0.6374428, wheels Y 0.3, body Y 0.15. No node rotation, scale, matrix, hierarchy or animation is present. The union of actual translated POSITION vertices is X[-0.75,0.75], Y≈[0,1.30], Z[-1.37255716,1.37255704]. Body-only or untransformed wheel bounds would give the wrong ground/fit.

Uniform factor `min(7/2.74511421, 2.7/1.5) = 1.8` is width-limited. The visible exterior is **4.94121 m long, 2.70 m wide and 2.34 m high**, leaving 1.0294 m at each end within the unchanged 7×2.7 m canonical reservation. Lead and Designer accepted this inset; do not stretch the length or change the service footprint. Normalize externally to the full horizontal centre and minimum ground Y, preserving original wheel/body pivots. Keep the queried body root at scale 1.

Tyres are about 1.08 m in diameter, wheelbase 2.556 m and wheel-centre track 1.62 m. Cab top is 2.34 m and body underside 0.27 m. The actual rear deck plane is source Y 0.61, X±0.45, Z[-1.2225572,0.0774428]: fitted deck height 1.098 m, width 1.62 m and length 2.34 m. These proportions are credible beside the existing 1.8 m human; actual current-build appearance was accepted in the scoped reference below.

## Front, cab and loading evidence

The source front is **+Z**, corroborated by the actual front axle, tall/sloped positive-Z cab front and negative-Z rear bed. Cab facade/roof triangles establish X±0.55000001, Y[0.80,1.30], Z[0.07255716,0.97255719]. Source upper cab sides are near X±0.55; the combined body has no separate door, seat or loading socket and no animation. Any side-door/seat/bed attachment is authored visual metadata, not an enterable opening or a backend port. Do not apply the Office standing-door criterion to this seated cab.

For raw source +Z forward, queried body/visual yaw is `90° - actual ledger facing_degrees`; ledger 0° means +X. Use an actual narrow keyed pose/facing read on the affected movement event. Do not copy/reimplement the ledger's small-displacement heading threshold or simulate another route.

Current station entry/exit and loading remain at the actual hull world point. Worker reporting, 3-second station handling, 2-second pickup/drop, finite fuel, personal handling and actual cargo transfer are unchanged. The retained person is seated only when actual holder/Driver facts agree; no duplicate loose or seated person. Detailed payload mesh, cargo-ID index, seating and interiors are explicitly deferred. The original open bed has no cargo art; its appearance is not proof of empty inventory and trip counters must not become cargo counts.

## Fixed presentation-first query policy

Lead chose `AnimatableBody3D`, layer 4/mask 0, physics synchronization and measured primitive shapes. Existing picking/SpringArm mask 5 sees it; manager mask 1 does not. **Physical manager-versus-truck blocking is absent.** No crushing, riding, yielding, player driving or other backend interaction rule is introduced. This is partial physical integration; 3D02/full vehicle interaction remains open.

The two proposed boxes below are in the normalized, scaled source +Z frame, before the actual heading rotation. They follow visible geometry, not the 7 m reservation:

| Region | Box size X/Y/Z (m) | Local centre X/Y/Z (m) |
| --- | --- | --- |
| Low chassis/wheels/body through deck | 2.700000 / 1.098000 / 4.941206 | 0 / 0.549000 / 0 |
| Actual cab above deck | 2.700000 / 1.242000 / 2.133000 | 0 / 1.719000 / 1.197103 |

The upper region is measured rather than inferred from the filename: cab facade/roof triangles above the actual rear-rim height locate the rear cab plane at source Z 0.07255716. Clip the original body triangles to Y≥0.61 and Z≥that plane, then take the resulting geometry union: X±0.75, Y[0.61,1.29999998], Z[0.07255716,1.25755713]. This includes the real cab-side/mirror/upper-front projections. Exact source boxes, normalizer origin and geometry derivation are retained in the asset manifest and ignored `queried_shapes.json`. No third segment is proposed.

These are conservative primitive bounds, not a triangle-perfect collider. There is **no full-height box over the empty rear bed**; thin rear rims above the deck have no separate query shapes in this bounded approximation. Lead explicitly accepted this approximation; the later actual camera/picking observation must still confirm the queried silhouette. Do not add a moving facility trimesh or general decomposition framework.

## Official API rationale and deferred interaction

[AnimatableBody3D](https://docs.godotengine.org/en/stable/classes/class_animatablebody3d.html) supports manually driven bodies and physics synchronization, with motion-derived velocities. [StaticBody3D](https://docs.godotengine.org/en/stable/classes/class_staticbody3d.html) moves by teleporting rather than affecting bodies along its path. Thus the former is the Lead-selected event-driven queried presentation body; neither becomes a new movement authority.

[ConcavePolygonShape3D](https://docs.godotengine.org/en/stable/classes/class_concavepolygonshape3d.html) is hollow and intended mainly for static level geometry. The moving truck therefore does not reuse the facility triangle shape. [BoxShape3D](https://docs.godotengine.org/en/stable/classes/class_boxshape3d.html) provides explicit width/height/depth for the two bounded primitive regions. Keep root scale 1 and supply measured dimensions/offsets directly.

A later bounded requirement must address manager/vehicle physical interaction consistently across the existing vehicle roles, with geometry appropriate to each vehicle rather than accidental asset-specific rules. Lead owns that separate scope with Designer; this initial body does not claim those rules or a runtime fleet matrix.

## Packaging, ownership and next step

Proposed files are only `game/preview_3d/assets/car_kit/truck_flat.glb`, its own `textures/colormap.png`, and exact original `license.txt`. The model is 207,424 bytes; palette 12,371 bytes; license 696 bytes. Keep the palette distinct from Industrial and Commercial despite its shared basename. An explicit one-byte JSON texture-URI T→t derivative may use snake_case paths; lengths and binary geometry stay identical. Offset, proposed derived hash and binary-tail hash are in the receipt, computed in memory only. Only these selected assets are assigned for integration; original archive/previews/research scripts remain ignored.

Existing construction registry/created flags, keyed hull pose/physical state and keyed actual retained-person facts own identity and state. Coalesce membership/state facts at existing boundaries; a movement event updates only the affected cached pose with a narrow canonical heading read. No broad scans, full carrier inspection, per-frame polling, stock index or second movement/collision owner. Hidden views do not stop services; release old bindings on replacement.

The 3D label shows actual identity, phase, hull condition and verified retained-person/Driver facts. It deliberately omits fuel: driving burns fuel between state boundaries, while movement reads remain pose-only. Existing management retains fuel information; backend fuel and consumption remain unchanged.

C owns the assigned presenter, keyed detached hull/retained-person views, canonical pose getter, exact source assets and current maps. Lead owns exactly two new data imports, actual sidecars/new helper UID, remote evidence, draft PR and integration. The fixed observation is recorded in [the committed definition](current_change/utility_truck.md); the executable proposal stays ignored. Later evidence should show actual identity, fit, human scale, canonical pose, useful camera/pick silhouette and truthful scalar crew/phase state; it cannot establish detailed payload, seating, manager blocking, ordinary utility-truck work, native/FPS or full vehicle parity. No old construction/truck loop, extra model search, local engine or runtime matrix is included.

## Actual current-change receipt

Required validation 42504672978 and the single current-change observation 42504678319 passed at `26e9fb0d778fb17df6509171c68540a656952936`. Existing settle created the actual hull from an explicitly arranged Complete Office. The canonical `(36,80)` position and 228.012782° heading match the synchronized queried body; all five imported meshes and own palette resolve with 2.7×2.34×4.941206 m bounds. Exactly two measured boxes provide a cab hit at Y2.34, an above-bed miss and real SpringArm retraction to 1.375 m. Only the software-driver VSync warning remains.

The [stored image and receipt](evidence/utility_truck.json) preserve the full actual manager/truck reference, truthful phase label and staged/camera-only caption. Actual generated two import sidecars and new script UID are retained unchanged. Lead, Designer and UI/UX personally viewed this exact reference and accepted its appearance, scale and readable labels at `26e9fb0`. Exact final-head role decisions belong to [PR #126](https://github.com/TheInfinityIQ/Trencho_V4/pull/126). This does not establish ordinary construction/haul, manager blocking, payload/seating, lifecycle runtime coverage, native input, FPS or full vehicle parity. No local engine or old scenario was run.
