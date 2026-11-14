# Supplier driver — independent animated increment

construction_worker_driver_v01.glb contains the seven unchanged current worker
clips plus supplier_driver_idle and supplier_driver_drive, each2seconds looping.
No draft timber, new single-package or crew clip is included. Editable source:
construction_worker_driver_v01.blend. Exact hashes, clip data checks and full
video metadata are in delivery_manifest_v01.json.

This is a FLOOR/FOOT-relative actor root, not a hip marker attachment. The driver
clips put Hips .407m above actor floor. Both retained truck Driver_Seat markers
are Body_Pivot-local(-.45,.40,-.23), identity rotation, and Body_Pivot rests1m
above ground. Parent the actor floor at Driver_Seat+(0,-.407,0), equivalently
Body_Pivot(-.45,-.007,-.23), or truck-rest(-.45,.993,-.23). Keep all transforms
under Body_Pivot to inherit the existing body motion. Do not add .407 twice.

Apply the existing raw-avatar Y rotation PI (180degrees) ONCE to the visual:
raw worker faces+Z, vehicle/seat forward is-Z. Actor root motion and identity
belong to Lead. There are no world-motion, method or cargo-custody tracks.

The GLB preserves the current worker's mesh, normals, colors, weights, indices,
33-joint order and the sampled data/channel sets of all original seven clips
within the reported precision. One mesh, one material, no external resources.
Source seated-pose mesh QA passes; two hidden back-to-back contact-face pairs
are accepted in this deformation. Format check has zero errors and warnings.

supplier_driver_complete_review_v01.mp4 shows both complete2s loops at1x in the
retained actual materials cab, with15frame end holds.152encoded/decoded frames,
800x512@30fps. First/reveal/end views were inspected before recording and the
encoded first/middle/last images checked after. This is artist footage; runtime
integration, human appearance approval and gameplay/performance remain separate.

New motion is artist-authored on the unchanged existing game worker. Existing
mesh/source licence and provenance records remain with that original delivery;
no new external mesh/texture was acquired. Other animation work remains paused
outside the two explicitly resumed supplier vehicles.
