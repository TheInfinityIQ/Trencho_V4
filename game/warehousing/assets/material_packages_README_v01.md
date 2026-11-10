# Shared material packages — static v01

Five shared warehouse/truck visual GLBs, with editable source
shared_material_packages_v01.blend. Exact hashes, exported node transforms,
counts, dimensions and warnings are in delivery_manifest_v01.json.
All new animation authoring remains PAUSED. No new pickup animation is required:
future paired timber handling should synchronize the existing bending motion,
after dimensions and real hand access are resolved and authoring is resumed.

|Material|File / root|Packing L x D x H (m)|Net capacity (kg)|Triangles|
|---|---|---|---|---|
|M01|metal_stock_v01.glb / Metal_Stock|.60 x .20 x .06|25|1528|
|M03|closed_keg_v01.glb / Closed_Keg|.40 x .40 x .50|25|600|
|M04|timber_bundle_v01.glb / Timber_Bundle|2.00 x .32 x .24|50|736|
|M05|textile_bale_v01.glb / Textile_Bale|.60 x .40 x .40|25|564|
|M08|fuel_can_v01.glb / Fuel_Can|.40 x .30 x .42|20|828|

Each file has one mesh, one opaque vertex-colour material and zero texture
images, skins or animation clips. Labels are blank plates: runtime text must
show material and actual current net kg/capacity, including partial packages.
These represent existing stock; decorative tube/board counts are not inventory.

Metres, Godot +Y up. Native local X=L, Z=D, Y=H. Front=-Z. Rotate deliberately
when the truck packing convention expects L along longitudinal Z. Each root
contains exact Packing_Min, Packing_Max, Quantity_Label_Front and
Quantity_Label_Back names. The packing markers are opposite corners converted
from Blender coordinates; exported Z reverses, so derive an AABB using the
componentwise minimum/maximum of BOTH marker positions. Their names alone are
not componentwise Godot minima/maxima. Label transforms face outward.

Metal_Stock, Closed_Keg and Textile_Bale have Grip_Reference_Left/Right;
Fuel_Can has Handle_Grip_Reference. Timber_Bundle has Undergrip_Reference_1..4.
All grips are PROVISIONAL references, with no posed character approval. Source
marker aliases are namespaced because Blender requires global unique names;
each standalone GLB has exact names, with no .001 suffix matching required.

Metal stock is nine hollow rectangular profiles with nominal 4mm walls; this
is a generic 25kg game package, not separately counted tubes. The bale and can
use actual rounded faceted bevels, preserving their assigned packing sizes.

Timber boards are exactly 2m x .15m x .05m. The six-board visual is about
2.00 x .32 x .162m, within the conservative .24m packing height. No invisible
spacers were added to fill that difference. Fixed rack saddles stay on racks.
Undergrip references are 18mm below mesh base / 22mm below wood bottoms: real
external clearance/support is necessary. Bare-ground pickup is unverified.
Do not shorten the existing truck interior to match the 2m planks.

The can stays .42m high including its handle. The rounded handle opening is
nominally .15m wide x .075m high; the body limits central vertical clearance to
.0675m. No glove pose has been approved. Its 20kg game contents do not imply
20 litres; a 30L-class SCHUETZ container informed the exterior scale.

Visual GLBs exclude collision proxies. The Lead owns runtime collision,
routing, shelf packing, attachment transforms and actual quantity text.
Production material is self-contained C0/Palette vertex colour with no special
Blender-only shader dependency.

All five mesh checks pass with no errors, all format checks report zero errors
and warnings, and reimported visual bounds match at the recorded precision.
Accepted source warnings concern hidden contacts between separate closed parts
and coincident seam vertices; reports preserve counts and rationale. Export
three-quarter/back/side/wire images were visually reviewed. Source reopens with
one scene and zero actions. No local Godot run, gameplay check, performance
claim, carrying contact acceptance or human appearance approval is included.

This is artist-authored geometry using the existing construction palette.
No external mesh or texture was copied. References:
[SCHUETZ jerrycans](https://www.schuetz-packaging.net/schuetz-germany-hq/en/jerrycans/),
[NIBIO pine](https://www.nibio.no/en/subjects/forest/use-of-wood/timber-species-in-norway/pine).

The final publisher updated metal stock, can and bale only after visual review;
keg and timber exports remained unchanged. Earlier working sources/reports
remain historical; use this manifest and the final *_mesh_review_final.json
records rather than the initial build_receipt.json failures.
