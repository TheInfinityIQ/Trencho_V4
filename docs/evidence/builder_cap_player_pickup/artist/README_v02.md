# Refined faceted pickup v02 — current visual handoff

Dawson requested faceted forms with some rounded corners and specifically asked
to move away from a super-low-poly Roblox-like appearance. This version keeps
the compact blue two-door/longbed silhouette while adding manufactured edge
bands, a gently crowned roof, pressed hood contours, wipers, lower door mouldings
and more natural32-sided tires with a shaped sidewall/rim and actual tread.
It is a modeled interpretation for review; human art approval is still pending.

Current editable source: `faceted_personal_pickup_v02.blend`.
Current static export: `faceted_personal_pickup_v02.glb`.
Exact hashes, node transforms, material definitions, scope and provenance are in
`delivery_manifest_v02.json`. Prior v01 files remain intact historical versions.
No production game source or local Godot run was used.

Every runtime node name, hierarchy and rest transform matches v01 within1e-5.
Steer localGodotY, wheel spin localX, Body_Pivot localZ roll/localX pitch; all
seat/eye/exit markers are unchanged. Roof now1.746m. Width including mirrors
1.985m and overall length4.512m remain. Nominal tire radius0.34m remains;
actual tread minimum is approximately0.03mm below zero, a negligible modeling
contact tolerance. This does not establish a physics/collider specification.

31,674 triangles across six instances;19,398 unique resource triangles,
48,196 exported vertices across unique resources after flat normal/color splits.
Three mesh resources remain: body, glass and ONE shared wheel. Three materials
are paint/body palette roughness0.43, matte wheel palette roughness0.80 and basic
alpha0.20 glass. Opaque materials still use white base factor and linear COLOR_0;
no textures, transmission, shaders, skins or authored driving clips. Use linear
vertex colors as albedo in Godot. This is a higher-detail local candidate, not a
measured runtime performance claim; no benchmark or speculative LOD library added.

Final scoped mesh review passes with zero errors/floating/z-fighting. Accepted
warnings: four contact vertices,42 hidden body contact face pairs and4 glass/frame
contact pairs. Separate fixed closed pieces preserve editability; indiscriminate
welding can create nonmanifold contacts. The source is saved and reopened,
all six imported export bounds match within1e-4m, and wheel sharing is retained.
Khronos validation:0errors/0warnings,4informational intended empty-marker notices.
See `mesh_review_v02_final.json`, `roundtrip_check_v02.json`,
`saved_source_check_v02.json` and the GLB validation JSON.

`v02_final_*` images show the actual source, `v02_roundtrip_three_quarter.png`
the actual imported export. `export_wireframe.png` is the actual current export
with geometric triangle-edge overlays. `pickup_refined_motion_review_v02.mp4`
is the full20-second artist study:8s turntable then12s start/left/right/brake/
settle, clearly labeled NOT GAMEPLAY. `motion_preview_parameters_v02.json`
records the source hash and per-frame motions. Video is separate from the static
GLB and does not add clips or change the runtime contract. Godot driving,
seating/collision, actual runtime footage and performance remain Lead-owned.

Original unbranded geometry, no external mesh or texture; silhouette/color
reference is Dawson's supplied [blue1980Hilux listing](https://www.classic.com/veh/1980-toyota-hilux-rn37023005-4y86xop/).
No Toyota badge, national marking, reference photo or copied geometry is embedded.
