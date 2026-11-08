# Completed rear exteriors: bounded implementation contract

Accepted pre-code contract. Baseline PR122 merge92a75717c3967948be08fc0a16f13ebf69b39ef3, branch codex/3d-facility-exteriors. Developer C owns this bounded asset integration; Lead owns isolated CI additions, actual sidecars, remote execution, review and merge. No local engine or extra gameplay campaign.

## Candidate set and provenance

Original Kenney City Kit Industrial2.0 CC0 archive supplied by Lead: SHA2565b381164e5760f3830a2dbee43b972deee38b2a695d091b56e238ab2910c96d2, root logs/industrial-asset-inspection/industrial.zip. C viewed its four tiny thumbnails and inspected the bundled license, exact selected GLB nodes/POSITION bounds and texture dependency. Exact members/hashes and derivations are in [the asset manifest](3d_facility_assets.json); raw source bounds remain in the ignored inspection notes; NORMAL bounds are not geometry bounds.

| Original model | Actual candidate kind | Catalog dimensions, normal / quarter turn |
| --- | --- | --- |
| building-a | Construction Office / construction | 10x8 / 8x10m |
| building-h | Workshop / workshop | 16x12 / 12x16m |
| building-k | Receiving / receiving | 16x12 / 12x16m |
| building-k | Logistics Centre / dispatch; Storage / depot | 20x16 / 16x20m |
| building-l | Materials Plant / materials | 20x16 / 16x20m |

The four models remain the bounded candidate set. One combined mesh and absent named door anchors are normal, not blockers. Author small explicit front/yaw/offset metadata per model and calibrate it in the first actual current-build render. Thumbnails do not prove final facade alignment; no general fitting framework or further asset-search campaign is needed.

## Ownership and state

Only an actual ConstructionService row.state == Complete with a supported mapping receives the completed exterior. Bind by stable site ID and consume row.kind/center/size/door/orientation. Awaiting M11, Building, cancellation/recovery and other transitional states keep honest existing proxies. Other facility kinds or visibly incompatible candidate/orientation pairs stay explicitly provisional.

Rendering cannot complete work, grant stock/labour/capacity, merge the kinds sharing building-k, or change claims/holders/recipes/staffing/routes/fuel/time. This is completed exterior presentation; no interiors, machinery semantics, new gameplay or global spatial rewrite. Existing construction commands and active-manager occupation protection stay authoritative.

## Fit and west-facing approach

Measure the actual imported bounds, correct the asymmetric source origin/base and use one uniform scale. Keep visible projections inside the current Catalog reservation. Do not independently stretch axes or infer dimensions from art names. Source_notes.json envelope numbers are rough arithmetic, not approved runtime transforms.

The actual row.door is an OUTSIDE service/approach point, one metre beyond the runtime footprint's west edge. It is not a demand to put a mesh door hole exactly at that coordinate. Use authored model front/offset metadata to present a readable west-facing entrance and a clear visual approach from that unchanged service point. Leave reserved inset space visibly understandable. Do not move backend doors, routes or custody positions to suit art.

Quarter turn swaps Catalog dimensions but does not blindly rotate the authoritative west-side door north. Calibrate each supported facility/orientation mapping rather than add90degrees automatically. Read actual row.door; legacy template doors can differ. The first bounded asset render resolves orientation, apparent human scale and entrance/approach fit. Correct a small visual offset or keep an incompatible pair provisional; do not remain indefinitely at metadata research or force an implausible shell.

## Occlusion and labels

Fitted roofs/chimneys can exceed the current3m provisional volume. Keep Catalog ground reservation and current gameplay/collision rules; coordinate actual shell picking and third-person camera occlusion explicitly instead of silently allowing visible roofs to be picked through or converting art height into backend permission. Accepted implementation: a static actual-mesh presentation occluder on bit4, with picking/SpringArm mask1|4 and manager mask1 unchanged. Use imported triangle geometry, not an invented roof height. No generic framework or new terrain/combat rule.

Place site identity/state labels at a clear calibrated shell anchor; do not assume the old4.5m box label clears these roofs. Keep HUD identity and normal depth testing, with no blanket label-depth disable. Actual render decides readability.

## Packaging and acceptance

Include only the four original selected GLBs, their shared11986-byte colormap PNG and exact original license. Integrated model paths use snake_case. Apply exactly one byte in each original GLB JSON chunk: Textures/colormap.png becomes textures/colormap.png (uppercase T→lowercase t). File/chunk lengths and all binary geometry stay identical. Record original/integrated hashes and the edit offset; these are explicitly derived GLBs, never original-byte claims. PNG and license remain exact original bytes. Texture SHA256950f4f891ebd05a2affac810e6eeb0fea1511bc39039b65a3cbf2e17d17bc6a2. No archive/thumbnails/authoring/tools/scripts or extra roster in production. Selected models are63–177KB; use LFS before genuinely large additions later.

Lead owns the explicit minimal isolated import list and actual remote-generated .import/.uid retention; no full editor/project/plugin scan. Keep Compatibility and current resource/error/time limits. Style direction is accepted, individual asset fit still provisional.

Acceptance: current-build completed shells bind to actual Complete IDs, fit uniformly, retain readable west entrance/approach and truthful other states, and agree with picking/camera/labels without gameplay/custody changes. Author per-facility/orientation limits/fallback in the mapping metadata. After assignment, use the one bounded new-asset render chosen by Lead to resolve fit; thumbnails alone are not readiness. Any arranged view is labelled and cannot establish earned construction or ordinary full-loop/FPS/native acceptance. No new run now.

Diagram: [completed exterior ownership](diagrams/3d_facility_exteriors.mmd). Asset receipt: [manifest](3d_facility_assets.json).


## Relevant API rationale before implementation

[Mesh.create_trimesh_shape](https://docs.godotengine.org/en/stable/classes/class_mesh.html) builds a ConcavePolygonShape3D from actual imported geometry. [ConcavePolygonShape3D](https://docs.godotengine.org/en/stable/classes/class_concavepolygonshape3d.html) is intended for static level geometry, not the moving CharacterBody3D. Therefore attach the bounded shell occluder to a StaticBody3D on presentation bit4; retain the existing simple reserved-footprint movement collider and its manager mask1. No backend terrain/combat/ledger height follows from these meshes. Import-format guidance is recorded with the asset manifest; only declared GLBs and palette enter the isolated importer.

Rendering maps only Complete rows; source-front/yaw and approach offsets are explicit small metadata. Uniform fit uses measured bounds and can preserve a common scale across both quarter-turn reservations while keeping the west facade stable. Actual viewport evidence decides whether a mapping is readable or must stay provisional. No general fitter, interiors or machinery semantics.

## Source handoff and unverified visual choices

`facility_shells.gd` owns four loaded scenes and shared per-mesh static occlusion shapes for this presenter lifetime. It reads Complete rows, measures rotated imported bounds and fits a common square envelope with 0.4m inset, so swapped reservations use identical scale and retain the west facade. The presenter keeps its existing hidden 3m layer1 reservation, marks its ground perimeter and draws the approach from the unchanged row.door. No gameplay geometry is inferred from the exterior. Ground picking and the actual SpringArm use mask5; manager mask1 remains unchanged. The geometry snapshot includes kind/door/orientation as well as existing state/size/goods so visual changes rebuild at event boundaries.

All four source-front candidates are +Z rotated -90 degrees toward west. Front fractions along fitted Z are Office/warehouse0.5, Workshop0.8, Materials0.65. These are authored starting choices, not visual acceptance; the one actual render must confirm the visible facade, apparent scale, marker and labels. An incompatible legacy non-west approach remains explicitly provisional. Other kinds have no exterior mapping. The same warehouse art does not merge Receiving, Storage and Logistics identities or capabilities.

Proposed direct observation is ignored `logs/3d-facility-exteriors/current_asset_view.gd`, not a production scene or regression suite. It explicitly arranges four Complete rows (one per new model, Workshop quarter-turned), records actual fitted bounds and identities, observes one actual roof ray plus the real SpringArm against that roof and captures an arranged overview. It does not earn construction or run an old construction/manager flow. Lead owns its bounded remote execution, sidecars and review. No engine execution, import, native input, actual visual approval, complete roster, full loop or FPS result is claimed by this source handoff.

[Official glTF import guidance](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) recommends glTF and describes external texture dependencies; the isolated importer needs exactly the four new GLBs and their declared palette. The original license is retained for provenance, not an engine import. There is no Blender/converter dependency.

## Local verification of this handoff

Direct static checks parsed only the three changed production GDScript files and the ignored visual proposal with the repository's pinned GDScript syntax parser. A byte comparison against the supplied archive confirmed exactly one recorded URI byte differs in each GLB, unchanged binary chunks and exact palette/license bytes. The living map and function purposes are current; the HTML was rendered independently without modifying the preserved button-contract fixture. These are source/provenance checks, not Godot compilation or visual/gameplay acceptance. No local engine, regression suite or old flow was run. Actual generated sidecars, import, rendering, roof/camera observations and visual review remain Lead-owned pending work.
