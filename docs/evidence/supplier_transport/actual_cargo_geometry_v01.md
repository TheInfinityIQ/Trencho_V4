> **S1 ORIENTATION ERRATUM — 11 November 2026:** The report below is retained as historical evidence, not an accepted S1 support result. The Artist withdrew its four-left-position zero-support count: the S2/S3/S4 left-PI placement had been incorrectly applied to S1. Frozen left timber S1 uses identity; S1 is currently excluded from runtime shelf binding. Corrected wall-side S1Metal left-identity/right-PI support and undergrips are being measured. Do not use the report’s generalized left-PI statement, left support count or claimed independent support proof to authorize an insert. Pure-rack90→72 arithmetic and actual package yaw are unaffected. No runtime/asset change follows from this correction.

# Actual cargo geometry decision — 11 November 2026

Recommendation: retain the frozen timber delivery and keep **S1 metal as a separate variant** with the original .425/.85m support spacing and stacking envelope. Correct its missing physical support before any mounting choice. **No universal riser or final contact station is accepted by this study.** Keep S2/S3/S4 and the crate-rack originals unchanged; their remaining conflicts need actual contact-frame fitting or a separately approved layout. No new pickup or other-item hauling clips were authored.

## Actual integration contract

Source: current `cargo_packing.gd`, `material_packages.gd`, `supplier_vehicle_view.gd`, `warehouse_service.gd` and `warehouse_view.gd`, hashed in the manifest. M01 metal/M04 timber use S1; M02/M06/M11 use S2; M03/M08 use S3; M05/M07/M09/M10 use S4. Earlier S2/S3 metal diagnostics are not shipment cases.

Truck package yaw is **+PI/2 when quarter_turn is true, otherwise zero**, independently of the left fixture's PI placement. Static shelf Packet markers at -PI/2 are not the packing authority. Small cases/cans commonly stay yaw0, two along the .7m module. Crate-rack packages retain yaw0, four columns by two rows by two decks:16 positions. Work1.1 and Approach markers remain staging. Worker facing must derive from the actual handle group and workspace; no .735 reuse, package rotation change or mirrored provisional grips.

All dimensions below are relative to the actual walking floor. Truck floor is worldY1.02; roof underside gives2.32m above it, portal top1.96m above it. Use **1.94m guaranteed travel height** for a release envelope, retaining20mm below the portal. Warehouse clear height4.5m. Keep50mm release. Preserve existing packing dependencies; warehouse access must not gain a new inventory-order workaround.

## Proven constraints in the retained source geometry

- Original metal S1 v02 has **zero projected support area** under both front packet positions on the left, at both original decks:four unsupported base positions. Exact upward top-triangle clipping against each packet footprint establishes this, not sparse rays. Translating the entire rack cannot repair a missing support surface. Recommend a separate metal support insert/deck at the original planes, within the existing footprint/30mm structure zone; this proposed obstacle has NOT been modeled or contact-approved. It must not modify the frozen timber saddles.
- The pure packing geometry is90metal packets per old S1 rack, versus72 if .60/.95 timber tops are substituted with the same1.50m ceiling. These are **pure-rack packet capacities**, not truck counts, quoted fees or actual cargo mass. The game also applies5000kg payload, grouping and fees. No quote/economy change is inferred.
- Original bend shoulder minimum1.066146m and arm+entire-glove radius.692854m give an optimistic minimum reachable surface height**.373292m** over the sampled downstroke. Thus S2/S4 small-case top.34m and warehouse metal top.31m remain below even this permissive bound:33.3mm and63.3mm deficits. S2 medium retained grip.335m is38.3mm short; S4 bale retained grip.32m is53.3mm short. Merely choosing a closer floor station cannot overcome those vertical exclusions. Actual wrist/palm reach is more restrictive than this free sphere.

## Mounting bounds — necessary spans, not approved offsets

These spans retain every support plane, outer envelope, stack count and current packet yaw. They intersect original-source arm/glove reach, measured aisle boot limits, roof and lifted-load limits. They apply to the initial **toward-rack facing workspace** and retained grip references. They are not a universal feasibility theorem: pose gaps, different grip-derived facing, actual palms and collision-free engagement are not certified by a span. Do not select its midpoint as a mounting decision.

| Variant | Original support tops | Necessary whole-rack base span | Pure homogeneous packet capacity |
| --- | --- | --- | --- |
| S1 metal | .425/.85 | .054–.219m |90 metal |
| S2 | .10/.55/1.00 | .199–.547m |6 small /3 medium |
| S3 | .10/.70 | .113–.689m |2 kegs /4 cans |
| S4 | .10/.70 | .194–.376m |2 bales /10 small /3 medium |
| Crate rack | .25/.95 | .099–.650m |16 positions |

The source JSON used the exact1.96m portal bound; applying the recommended20mm travel reserve decreases the portal base ceilings by20mm. None of the table endpoints changes because arm/hand bounds are tighter. A physical mounting frame/plinth was not authored; its solidity needs checking before any riser is adopted.

## Body/frame conflicts and the compact next decision

Necessary reach did not establish a complete fit for any common offset across all items. Cached original body/helmet/feet, actual exported racks, same-rack occupied packages and the actual opened/deployed truck were used. The first mounting sweep's positive poses were rechecked against the real truck; five candidates hit it and are excluded. A further bounded workspace derived worker yaw from the **actual retained grip midpoint**, keeping package yaw and grip references unchanged. That corrects the assumption that every worker can simply face perpendicular to the aisle.

- S2 lower small cases and S4 lower small cases still had no clear witness in the checked workspace at the diagnostic325mm base. A no-witness result is **not** a proof that every possible pose/height fails.
- Left S4 upper bale has a body-only clear witness at325mm base, original pickup.6333s, shelf-local root(.640,0,-.025), yaw-1.55814. It has only15.3mm of the optimistic sphere margin, no fitted glove/contact or approach approval. It is not a ready hauling contract.
- For left S4 lower bale at425mm support, a measured static projection gives higher support at least**1.511901m** to put the upper structure above the source body with20mm clearance. Retaining three upper small-case layers there would require lifted travel height1.511901+.72+.05=**2.281901m**, exceeding the guaranteed1.94m portal. This particular raise-the-upper-deck solution cannot preserve both capacity and exit clearance; it is not a global impossibility proof for another fitted contact/layout.
- A right S2 lower-case projection gives next higher support at least1.506782m for one clear-fixed-geometry source pose. That is not a finished three-deck layout; the retained left counterpart remains unresolved.
- For the warehouse back bale at475mm lower support, a static original-pose witness gives upper support at least**1.557097m** (fixed frame/lower stock clear; upper deck/stock would move together). Upper1.575m would require outer height at least2.150m for a500mm keg,50mm release and25mm top allowance, retaining16 cells and the footprint. This is a **source-derived proposal only**, not authorization to build: back-row metal and complete hands/approach/occupied-stock movement remain unresolved. The2.2m timber allowance is not automatically approval for this crate revision.

Recommended next technical decision: keep counts, actual package yaw and the original bend; measure real near-face palm/handle contacts from the actual package meshes for the unresolved side/back cases. Do not reflect provisional markers as a shortcut. If those contacts cannot fit, return a separately quantified fixture-layout choice with the affected capacity/doorway constraint, rather than silently selecting a riser, changing packing or introducing a new pickup clip. The zero-support metal positions require a separate support solution regardless of contact fitting.

## Evidence and limits

`context_and_support_measurements.json`: exact metal-support polygons, necessary spans and actual-truck rechecks. `vertical_exclusions.json`: orientation-independent vertical bound. `grip_facing_workspace.json`: exact retained-grip poses and upper-projection witnesses. `mounting_interval_measurements.json` and `actual_geometry_measurements.json`: earlier bounded diagnostics; positive body-only poses are not full contact acceptance. Initial S1 left-body diagnostics do not model side-correct near-package dependencies and must not be used as a metal fit claim; final metal result here is the independent support proof.

This is a read-only geometry decision artifact. No meshes, actions, runtime code, package orientation, stocking rules or capacities were changed. Original clips/assets and frozen timber packages remain intact. No local Godot/engine run, regression suite, human appearance approval or native integration is claimed. Finite sampled body/triangle checks and a whole-glove reach envelope do not prove continuous contact, grasp strength, deformation or game readiness.
