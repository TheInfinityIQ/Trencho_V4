# Faceted materials vehicle v01

Original M35-inspired conventional cab/6x6 chassis with enclosed hard moving-truck
box, upward sectional shutter and sliding loading ramp. No canvas, weapons,
brands or national/Allied markings. Produced after the all-angle2D mockup and
licensed-foundation search; actual inspected Zsky candidate was rejected, not
copied. Existing original Trencho wheel geometry is reused and shared six times.
See `brief.md`, `concept_all_angles_v01.png`, exact concept prompt and
`asset_reference/README.md` for the design/source record.

`faceted_materials_vehicle_v01.blend` is the editable source; originals are hidden
under working collections, with the published ASSET_Materials collection and
presentation scene. `faceted_materials_vehicle_v01.glb` contains only the vehicle
and four mechanical clips. `delivery_manifest.json` is the exact node/material/
dimension/provenance/hash contract. Current readiness is static body plus authored
door/ramp animation, pending Dawson review and Lead integration. Driver/paired
workers, packages, game controls/custody/routing and runtime performance remain
separate stages; no permanent phantom driver is welded into the body.

## Measurements and interface

Metres; Godot/glTF+Y up/-Z forward, Blender+Z up/+Y forward. Actual neutral envelope
including mirrors:2.435m wide,3.390m high,5.830m long. Nominal box width2.12m,
clear inside1.90m. Exact authored usable floor and timber length2.735249243m,
1.5times the canonical measured1.823499495m worker height. Floor1.02m, guaranteed
rear opening1.90m wide x1.94m high fromY1.04to2.98. Central aisle0.80m and
two0.55m storage lanes are the accepted initial clearance layout, subject to actual
worker/paired-pose checks. Door sill is20mm above the cargo floor/ramp dock;
include the small threshold in physical foot/floor routing.

Root Materials_Visual; Body_Pivot atGodotY1.0 owns body, glass, mechanism and
cab/cargo markers. Body roll localZ/pitchX. Front Steer_FL/FR own Spin_FL/FR;
rear Spin_ML/MR/RL/RR directly underroot. Allsix wheels share ONE mesh, nominal
radius0.43m, track1.80m; centresX±0.90,Y0.43, axleZ-1.85,+1.65,+2.55.
Steering localY; wheel spin localX with angle=-forwardtravel/0.43. Ground-root
Driver_Exit_Left, Ramp_Ground and Rear_Access require actual terrain/obstruction
resolution by Lead. Cargo_Front/Rear/Left/Right/Floor and Ramp_Top define the
vehicle-local space. Driver_Seat hip(-0.45,1.40,-0.23), Driver_Eye
(-0.45,2.08,-0.24), Driver_Floor(-0.45,0.993,-0.23), Exhaust_Emitter supplied.
Exact local transforms/parents, not guessed object axes, are in the manifest.

## Mechanical clips

All four are2.0seconds,once: `door_open`, `ramp_deploy`, `ramp_stow`, `door_close`.
Each explicitly controls all10Door_Section nodes and Ramp_Root, including constant
poses of the other mechanism, preventing an unkeyed fallback-to-rest change.
Ten rigid0.194m-joint-length sections follow vertical rails, a0.30m curved header
and overhead rails. The exported fully-open slat bounds clear the whole opening.
The0.90m-wide tapered ramp slides fromunderdeck before lowering;3m horizontal run
and1.02m rise, exact exported tip aligns with Ramp_Ground within1e-4m. This is
reference-flat-ground geometry, not automatic terrain adaptation or a collider.

Suggested owner sequence: complete door_open, complete ramp_deploy, perform actual
physical loading/unloading, complete ramp_stow, complete door_close. Clip names
and advisory endpoints do not move inventory, grant capacity or change custody.
Door/ramp video is an artist review of the actual exported clips, not game footage.
Source/clipframe ranges and complete encoded-frame checks accompany the MP4.

## Assets and direct checks

34,552 triangles across19instances;13,696unique resource triangles,
24,823unique exported vertices after normal/color splits. Five mesh resources:
body,glass,shared wheel,shared door slat andramp. Three materials: shared opaque
linear COLOR_0 body palette roughness0.52,matte wheel palette0.80 and basic
alpha0.20glass. Use linear vertex colors as albedo. No texture images, skins,
particles or custom shader dependencies; no performance benchmark claim.

Published mesh QA passes with no errors/floating/z-fighting/winding/degen/
nonmanifold findings. Accepted warnings are68hidden fixed-body contact pairs,
52anti-slipbar/ramp contact pairs and12glass/frame contact pairs. These are
mounted closed-component contacts, not duplicate visible surfaces. Tiny~0.04mm
tread bound below nominalground is a modeling tolerance. The coherent cargo
shell is one explicitly constructed hollow mesh; individual original panel inputs
are retained for editing, not duplicated into the export.

Saved source reopens with one scene; all19neutral imported mesh bounds match
within1e-4m. Actual exported full-open clearance/ramp tip and all11targets in
each clip were checked. Khronos validation:0errors/0warnings,14informational
empty-marker notices. See mesh_review_published,roundtrip_check,
animation_contract_check,saved_source_check and GLB validation reports.

Human appearance/animation approval and game integration remain pending.
No production Godot source changes, local Godot runs or regression suites.
