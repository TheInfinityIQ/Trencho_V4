# Three static shelves — independent delivery

Use independent_static_delivery_v01.json for this delivery. It contains only
S2_CrateShelf, S3_RestraintRack and S4_ProtectedCargo. Editable source is
s2_s3_s4_static_v01.blend (S1 excluded), one scene/zero actions. All three
GLBs/format checks/bounds and complete360degree video have been reviewed.
S1 and all worker handling contacts remain separate work.

|Root / GLB stem|External LxDxH m|Deck tops m|Relative to Cargo_Floor XYZ m|
|---|---|---|---|
|S2_CrateShelf / s2_crateshelf_v01|.70x.53x1.50|.10,.55,1.00|.665,0,-.9176246215|
|S3_RestraintRack / s3_restraintrack_v01|.70x.53x1.50|.10,.70|.665,0,-.2176246215|
|S4_ProtectedCargo / s4_protectedcargo_v01|.70x.53x1.50|.10,.70|.665,0,.4823753785|

Metres,+Yup, bottom-centre pivot,identityrotation/unitscale. ShelfX=depth/Z=length;
vehicle forward=-Z. Parent to the existing Cargo_Floor marker; it already sits
at truck(0,1.02,1.7176246643). These roots place module centres at truckZ.80,
1.50,2.20m. Each module remains wholly inside its550mm side zone with20mm
wallgap; the stationary aisle edge staysX+.40m.

Deck_00 etc are support TOP planes. Clear bay650x480mm; actual flat support
644x474mm S2/S3 or628x458mm padded S4. S4 padding is part of the30mm total tray
structure. Packet_00_00 etc use cargo-bottom pivots and intentional-Y90degree
yaw for long crates. S3 Can_Packet slots use identityrotation: two300mm widths
along rack,400mm length acrossdepth. One keg OR two cans, never both together.
Exact node transforms are in the manifest. No unverified stacked slots.

Remove matching separate Restraint_00 etc BEFORE pickup. Static meshes only,
no restraint action. Lips20mm/release50mm. S2 loadH<=370mm after450pitch and
30structure/50release;400mm bales use S4. S4 is full-width without divider.
Approach/Extract references do not prove anatomical grip or a usable route.

s2_s3_s4_static_review_v01.mp4 contains all three complete5second360degree
turntables with15frame holds:498frames/16.6s800x640@30fps. Framing was inspected
before capture, encoded first/middle/last frames decoded and checked after.
Actual export still/wire views are retained too. No skin/animation/texture
images; original geometry, one opaque vertex-colour material per GLB. No
external geometry/texture copied; source concepts/references/provenance retained.

Accepted QA warnings concern hidden contact faces/coincident seams between
closed editable parts. Each mesh QA passes, all three format checks0errors/
0warnings, reimported bounds match. Static artist readiness does not establish
character handling, game integration, performance or human appearance approval.
Lead owns runtime collision, labels/actualkg, stock custody, packing and routing.
