# Completed rear exteriors: bounded implementation contract

Accepted pre-code contract. Baseline PR122 merge92a75717c3967948be08fc0a16f13ebf69b39ef3, branch codex/3d-facility-exteriors. Developer C owns this bounded asset integration; Lead owns isolated CI additions, actual sidecars, remote execution, review and merge. No local engine or extra gameplay campaign.

## Candidate set and provenance

Original Kenney City Kit Industrial2.0 CC0 archive supplied by Lead: SHA2565b381164e5760f3830a2dbee43b972deee38b2a695d091b56e238ab2910c96d2, root logs/industrial-asset-inspection/industrial.zip. C viewed its four tiny thumbnails and inspected the bundled license, exact selected GLB nodes/POSITION bounds and texture dependency. Exact members/hashes and derivations are in [the asset manifest](3d_facility_assets.json); raw source bounds remain in the ignored inspection notes; NORMAL bounds are not geometry bounds.

| Original model | Actual candidate kind | Catalog dimensions, normal / quarter turn |
| --- | --- | --- |
| building-a (rejected, not shipped) | Construction Office / construction stays provisional | 10x8 / 8x10m |
| building-h | Workshop / workshop | 16x12 / 12x16m |
| building-k | Receiving / receiving | 16x12 / 12x16m |
| building-k | Logistics Centre / dispatch; Storage / depot | 20x16 / 16x20m |
| building-l | Materials Plant / materials | 20x16 / 16x20m |

The original four models are the historical candidate set; the Office candidate was rejected after actual manager-scale review (details below). Three models now ship. One combined mesh and absent named door anchors are normal, not blockers. Author small explicit front/yaw/offset metadata per model and calibrate it in the first actual current-build render. Thumbnails do not prove final facade alignment; no general fitting framework or further asset-search campaign is needed.

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

Ship only the three retained selected GLBs (h/k/l), their shared11986-byte colormap PNG and exact original license. The rejected Office a model is removed; its exact hashes/measurements stay in the manifest history. Integrated model paths use snake_case. Apply exactly one byte in each original GLB JSON chunk: Textures/colormap.png becomes textures/colormap.png (uppercase T→lowercase t). File/chunk lengths and all binary geometry stay identical. Record original/integrated hashes and the edit offset; these are explicitly derived GLBs, never original-byte claims. PNG and license remain exact original bytes. Texture SHA256950f4f891ebd05a2affac810e6eeb0fea1511bc39039b65a3cbf2e17d17bc6a2. No archive/thumbnails/authoring/tools/scripts or extra roster in production. Retained models are63–162KB; use LFS before genuinely large additions later.

Lead owns the explicit minimal isolated import list and actual remote-generated .import/.uid retention; no full editor/project/plugin scan. Keep Compatibility and current resource/error/time limits. Style direction is accepted, individual asset fit still provisional.

Acceptance: current-build completed shells bind to actual Complete IDs, fit uniformly, retain readable west entrance/approach and truthful other states, and agree with picking/camera/labels without gameplay/custody changes. Author per-facility/orientation limits/fallback in the mapping metadata. After assignment, use the one bounded new-asset render chosen by Lead to resolve fit; thumbnails alone are not readiness. Any arranged view is labelled and cannot establish earned construction or ordinary full-loop/FPS/native acceptance.

Diagram: [completed exterior ownership](diagrams/3d_facility_exteriors.mmd). Asset receipt: [manifest](3d_facility_assets.json).


## Relevant API rationale before implementation

[Mesh.create_trimesh_shape](https://docs.godotengine.org/en/stable/classes/class_mesh.html) builds a ConcavePolygonShape3D from actual imported geometry. [ConcavePolygonShape3D](https://docs.godotengine.org/en/stable/classes/class_concavepolygonshape3d.html) is intended for static level geometry, not the moving CharacterBody3D. Therefore attach the bounded shell occluder to a StaticBody3D on presentation bit4; retain the existing simple reserved-footprint movement collider and its manager mask1. No backend terrain/combat/ledger height follows from these meshes. Import-format guidance is recorded with the asset manifest; only declared GLBs and palette enter the isolated importer.

Rendering maps only Complete rows; source-front/yaw and approach offsets are explicit small metadata. Uniform fit uses measured bounds and can preserve a common scale across both quarter-turn reservations while keeping the west facade stable. Actual viewport evidence decides whether a mapping is readable or must stay provisional. No general fitter, interiors or machinery semantics.

## Source handoff and unverified visual choices

`facility_shells.gd` owns three loaded scenes and shared per-mesh static occlusion shapes for this presenter lifetime. It reads Complete rows, measures rotated imported bounds and fits a common square envelope with 0.4m inset, so swapped reservations use identical scale and retain the west facade. The presenter keeps its existing hidden 3m layer1 reservation, marks its ground perimeter and draws the approach from the unchanged row.door. No gameplay geometry is inferred from the exterior. Ground picking and the actual SpringArm use mask5; manager mask1 remains unchanged. The geometry snapshot includes kind/door/orientation as well as existing state/size/goods so visual changes rebuild at event boundaries.

After actual review, Workshop uses source-Z rotated+90 degrees with fraction0.80057 and a0.45-source-unit entrance inset. Receiving/Storage/Logistics retain source+Z/-90/fraction0.5; Materials retains source+Z/-90/fraction0.65. Office remains explicitly provisional. Corrected Workshop and front-relative labels still require the same actual arranged visual review. An incompatible legacy non-west approach remains explicitly provisional. Other kinds have no exterior mapping. The same warehouse art does not merge Receiving, Storage and Logistics identities or capabilities.

Proposed direct observation is ignored `logs/3d-facility-exteriors/current_asset_view.gd`, not a production scene or regression suite. It keeps the same four Complete rows (Workshop quarter-turned), now explicitly requiring three usable shell identities/model bindings plus the accepted visible Office proxy and pending-exterior label. It records fitted bounds, retains the actual warehouse roof ray/real SpringArm probe, overview and three reviewer-requested actual-manager entrance/fallback reference frames. It does not earn construction or run an old construction/manager flow. Lead owns its bounded remote execution, sidecars and review. Lead has since observed the original isolated import/parse and arranged functional checks described below. Corrected front/label acceptance, native input, complete roster, full loop and FPS remain unclaimed.

[Official glTF import guidance](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html) recommends glTF and describes external texture dependencies; the isolated importer now needs exactly the three retained GLBs and their declared palette; Lead removes only the rejected Office GLB from both existing input lists. The original license is retained for provenance, not an engine import. There is no Blender/converter dependency.

## Local verification of this handoff

Initial direct static checks parsed the three changed production GDScript files and ignored proposal; this calibration parsed only its two changed production scripts and the revised same proposal with the repository's pinned syntax parser. A byte comparison against the supplied archive confirmed exactly one recorded URI byte differs in each GLB, unchanged binary chunks and exact palette/license bytes. The living map and function purposes are current; the HTML was rendered independently without modifying the preserved button-contract fixture. These are source/provenance checks, not Godot compilation or visual/gameplay acceptance. No local engine, regression suite or old flow was run. Lead owns actual generated sidecar retention and the corrected remote observation/visual review; prior actual evidence is recorded below.

## Actual calibration and accepted Office fallback

Required import/parse42444251919 passed. First observation42444289146 failed because the proposal searched an exact repeated sibling name; all four candidate meshes actually rendered. Corrected same observation42444556186 passed at f7d0c26, with actual warehouse roof Y6.6425m/layer4 and real SpringArm hit length1.998m. Targeted same-process references42445080653 passed at63368b31 (artifact13603032502). C personally viewed Office, Workshop and Receiving frames: Office and Workshop approached blank/window faces; the Workshop gable hid its centre label. Receiving's actual door is believable beside the full manager. These remain arranged observations, not earned construction/movement/native/FPS acceptance. Preserve the original failed and passed images/logs.

Read-only original GLB POSITION/NORMAL/UV/palette inspection places the orange Workshop garage on source-Z at Z0.074, X[-1.1082,-0.8482], Y[0,0.27]. Thus yaw+90 faces west, fitted front fraction0.80057 locates it along world Z, and0.45 source-unit inset from minimum Z(-0.376) carries the decorative cue through the existing reserved setback to that actual face. Its fitted height is approximately2.288m beside the unchanged1.8m manager. Receiving and Materials fronts/model bytes are unchanged. No entered courtyard/interior or backend service-point movement is implied.

The Office's source-Z entrance at X[-0.8475,-0.7075], Y[0,0.27], Z≈-0.599 has glass and handle geometry, but the uniform fit3.455577 makes it only0.933m high and0.484m wide; its whole ground-floor band is1.555m. A1.8m source door would require a13.89m source-X building span, incompatible with10x8/8x10m reservations. Lead explicitly approved only this mapping's fallback: Complete Office retains its existing truthful volume with “Office exterior pending.” Remove its active mapping/shipped GLB, retain rejected-candidate provenance/measurements, and do not stretch art or change manager/footprint rules. The same four arranged rows now assert three real usable shells plus that explicit Office proxy; this is an accepted scope correction, not a silent relaxation of the earlier four-candidate assertion.

Mapped labels now anchor1m west of the measured shell's nearest bound, at45% of its height clamped2.4–3.2m and the authored facade fraction. The actual depth test and bottom alignment remain; the anchor is outside the visible near gable in the requested west-side view. Other viewing directions retain ordinary occlusion. Corrected actual visual acceptance is still pending; no global no-depth flag or general label/camera framework was introduced.
