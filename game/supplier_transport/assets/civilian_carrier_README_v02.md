# Crew transport — comfortable static source v02

Current faceted_crew_vehicle_v02.blend / faceted_crew_vehicle_v02.glb and
delivery_manifest_v02.json retain comfortable full-depth benches. v01's taller,
narrower bench clearance experiment is archived and superseded. It made the
worker posture unnatural and is not the chosen occupant presentation.

Concept first: concept_all_angles_v01.png, generated with the built-in image tool;
exact prompt is concept_prompt_v01.txt. Online foundation search and actual GLB
inspection followed, before geometry. See asset_reference/README.md. No external
candidate geometry or materials were reused. Existing own cab/interior/wheels
provide a consistent family; the crowned hood and open crew platform are new.

Eight passenger places face inward, four each side. People are separate actual
worker actors, never permanent body meshes. Source has body/glass, six instances
of one wheel, steering/spin/body pivots and exact driver/seat/floor/stand/rear/
ground markers. Marker inward orientation refers to the entity and keeps the
existing raw-avatar presenter pi rotation. All transforms are in the manifest.

Readiness is STATIC, pending human appearance approval and Lead integration.
Driver and eight-passenger source fit studies in ../vehicle_character_animation/
are separate from this vehicle GLB; no seated or disembarking clips are exported.
The driver study measured about28.5mm hardhat clearance to the cab's inner roof;
this is a static pose observation, not moving-driver animation acceptance.

Important measured design limit: a comfortable seated worker's boots project
into the empty geometric aisle. Opposing original poses leave about112mm between
boot tips, insufficient for another standing worker. Rear-to-front staged exit
with measured foot clearance, or a reversible physical layout adjustment, must
be agreed and demonstrated before authoring the full stand/walk/crouch/jump/
land/walk-on sequence. A narrow empty aisle and eight seat markers do not prove
an occupied unloading route. The compact leg experiment was explicitly rejected.

Scoped mesh QA passes with no errors/floating/z-fighting/winding/degenerate/
nonmanifold findings. Accepted151hidden mounted-body contact pairs and12glass/
frame pairs retain recoverable closed source components. Fresh GLB import keeps
all eight mesh bounds within1e-4m and verifies all eight seat markers' inward
directions. Source reopens with one scene and zero actions. Actual exported
front/left/rear/right/top views and wireframe are versioned v02.

No Godot source edits or local Godot runs. Game routes, driver/occupant identity,
collision, body motion, exhaust, terrain and performance remain Lead-owned.
