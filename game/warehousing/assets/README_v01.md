# Supply Depot — static v01 delivery

Five visual GLBs: warehouse_shell_v01, warehouse_crate_rack_v01,
warehouse_long_stock_rack_v01, medium_crate_v01 and small_crate_v01.
delivery_manifest_v01.json has exact hashes, dimensions, node names/transforms,
materials, actual counts, accepted warnings and the measured layout record.
Editable sources: warehouse_shell_v01.blend and warehouse_fixtures_v01.blend.
warehouse_static_review_v01.blend is an arranged source presentation, not game
stock or runtime code. Production files have zero animations/skins/images.

## Contract

Metres, Godot+Yup. WarehouseFront=-Z; Lead faces it toward world south. Shell
12x16m OUTER,200mm maximum wall assembly inside,11.6x15.6clear beforeposts.
Floor extends to outerboundaries, top0m, bottom-.20m. Open portal4x4m, no raised
entry lip; static open shutter geometry only. Actual lowest lamp solid4.50m,
roof beam solid4.70m. Eight Light_Anchor markers are atY4.45m, intentionally
below the physical fixture as emission points. Roofheight is about5.70m.

Root Warehouse_Visual groups: Floor, Roof, Shared_Frame, Lighting,
Boundary_Front/Back/Left/Right. The whole corresponding Boundary group owns
wall/panels/trim/gable glazing and front portal/shutter. For a legal full matching
12or16m edge join, remove BOTH corresponding boundary groups. Shared_Frame
contains explicit corner posts, not central aisle posts. Roof/lighting remain
separately controllable for interior presentation. Partial/corner joins are not
authored. Frame/collision geometry extends no whole-building hull across entry.

Production visual GLBs EXCLUDE the collision-only meshes. Editable sources keep
actual simple floor/wall/frame/roof proxies for comparison; shell_direct_dimensions
lists their bounds. The Lead owns matching runtime primitives, collision layers
and routing. Importing a visual GLB alone does not make a walkable game warehouse.

Rack roots: Warehouse_Crate_Rack, Warehouse_Long_Stock_Rack. Each2.6x1x1.8m,
deck tops.25/.95m. Crate clearfootprint2.5x.9m,8medium crates/deck,16/rack by
arrangement. Access both long faces. Long stock has actual separated saddle
bars atX±.25 and open extraction ends; bracing stays on one side instead of
blocking the ends. Bars leave free grasp regions outsideX±.30, but hand contact
is not validated. FourExtract_End_Left/Right_Deck_1/2 markers identify the end
faces; Work/Access markers remain for source alignment. Do not infer an authored
haul route, certified shelf rating or new animation from these empties.

Medium_Crate is.6Lx.4Dx.32H, Small_Crate.4Lx.3Dx.24H. NATIVE localX isL,
localZ isD,localY isH. Warehouse rack layout uses that orientation; rotate
deliberately if a truck's packing axis expectsL along its longitudinalZ.
Actual front/back handle cavities and bars, two label plates and exact Grip/
Quantity_Label markers are present. Grip Left/Right means local-X/+X, not a
ready anatomical attachment map. Runtime labels show material and actual netkg/
capacity. MediumM07=16kg/M11=24kg; smallM02/M06/M10=24kg/M09=16kg. No baked full
weight or literal individual-component count. Source libraries use namespaced
aliases where Blender global uniqueness requires it; standalone GLBs have exact
agreed marker names, no fuzzy .001 matching.

## Observed static checks

Scoped mesh checks pass, including the corrected local window frames, stock
stops and crate lid/corners. No reported z-fighting, floating, degenerate,
winding or non-manifold errors. Accepted warnings: coincident mounted-component
vertices, hidden opposite contact faces, and the intentionally below-grade slab.
Raw per-asset warnings remain in the manifest. Source stays recoverable; no
indiscriminate whole-building union was performed.

Every visual GLB format-validates with0errors/0warnings. All imported mesh bounds
match source within1e-4m (fixture meshes exactly at reported precision). Sources
reopen with one scene and zero actions. Front/back/left/right/top plus wire and
actual exported interior/cutaway views were inspected.

The arranged actual-export review contains exactly two racks and21M11packages:
16full24kg=384kg,then4full24kg+20kg=116kg; SAME500kg, no new grant. Other six
slots have no rack. Measured actual mainbank gap3.4m (3m designated), side1.5m,
crossrows2m, front/rear2.8m. The2x1module source study removes both shared wall
groups, keeps floor edges exactly coincident and shows continuous interior.
This establishes artist static geometry only, not game ledger/jobs/physics.

Concepts precede modeling; exact image prompts and source review retained.
KenneyCC0 existingbuilding_k was inspected and used as visual palette/sawtooth
reference; no external geometry/texture copied. Existing idle-worker snapshot
is presentation-only. No Godot source or local Godot run was used. Human style
approval, actual gameplay walking/handling/joins/smoke, lighting and performance
remain separate. ALL NEW ANIMATION AUTHORING REMAINS PAUSED.
