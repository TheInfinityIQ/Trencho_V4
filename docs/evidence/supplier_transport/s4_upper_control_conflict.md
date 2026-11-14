# S4 worker operation: remaining source-fit conflict

11 November 2026. The accepted operator task remains active, but this is a concrete source-fit handoff, not a completed animation delivery. No new action keys or GLB exports were authored. Original worker, timber and S4 v02 production files are preserved.

## Completed source work

- Inspected both actual gloves' volar anatomy instead of using the old largest-upward-facet assumption. Existing shared finger geometry cannot be treated as an independently articulated pointing finger.
- Fitted actual supporting palms, hips/knees and planted feet at closed/mid/parked poses without stretching arms. Replaced the excessive early forward lean that put the helmet/arms into the pan/lower bale.
- Preserved the failed narrow-control study in `narrow_control_history`. Its 18mm face/20mm recess did not pass actual glove contact.
- Implemented the Lead-accepted wide flush controls: centres at model-local Godot(-.264,.780,-.2375) and(-.264,1.100,-.2375), 140mm-wide x40mm-high faces,3mm press stroke, attached thin fixed housings within the original footprint. No bearing/padding/cargo reduction. Sealed fixed-frame paired-pin linkage and retained push-push release states are documented in `manual_control_contract.json`; internal mechanical engineering is conceptual, not certified/simulated.
- `manual_hardware_fit.json` establishes zero frame/neighbor surface intersections in the two actual static press fits at that stage. This does not establish the later complete movement path.
- Moved the left stabilizing palm to actual pan underside Z=-.070m, with right palm Z=+.150m, to clear the broad controls. Added a real outward hand-transfer arc rather than relying solely on joint interpolation through the housing.

## Current decisive geometric conflict

`remaining_motion_conflict.json` isolates the actual source worker against the new fixed housing during the most recent complete source sequence:

| Source time | Pan angle | Actual intersecting body | Exact Boolean solid overlap |
| --- | --- | --- | --- |
|3.233333s|6.255586deg|Left shoulder|2.20645e-8m3|
|4.266667s|45.749969deg|Left upper arm and upper chest|4.91351e-6m3|

At the larger conflict, the intersection lies approximately at X[-.264,-.257], Y[1.078,1.122], Z[-.2351,-.1600]m in module-local Godot coordinates: the **upper B control housing**, not the lower bale or a hidden external candidate. This is roughly4.91cm3 of solid overlap. The lower-bale, adjacent occupied-envelope and above-floor truck checks are clear in those samples. It is not a harmless hand/button bearing contact.

Actual views: `remaining_motion_conflict_1.png` and `remaining_motion_conflict_2.png`; diagnostic native files with matching names retain the exact poses. The full worker, housing, pan and lower cargo are shown. The omitted full truck/neighbor rendering is represented by measured source collision geometry; these are source reviews, not game captures.

The complete current-change source check is `source_operation_gate.json`:241 samples of one8-second opening candidate,89 failed samples. The reverse would use the same states; it has not been published as a closing clip. Apart from the housing conflict, the current entry/hand-transition path still contains rejected reach/contact failures. The maximum arm clamp in this attempted path is an authoring-path defect, **not** proof that the worker needs longer arms or that the mechanism is universally unreachable. Leg/sole checks do not erase the upper-body/contact failures.

## Next bounded resolution

Resolve B's mounting/access position outside the measured torso sweep before publishing keys. One candidate is lowering it into the roughly0.9m front waist-access region; that is an **unfitted proposal**, not a passed replacement. Alternatively change the mounting location while preserving the full shelf footprint, structural support, padding, occupied cargo and pan sweep. Do not remove body geometry, shrink people/cargo, stretch arms, accept the overlap, add powered actuation or rebuild individual fingers to conceal the conflict.

After that source fit clears, finish the entry/withdrawal contact paths and re-check only the changed operation. Then author/export the coordinated worker+mechanism actions, inspect the actual export and provide full normal-speed opening/closing video. Human appearance approval and Lead engine integration remain separate.

No current wide-hardware QA/export/video approval is claimed. Earlier narrow-study QA is not substituted for the changed wide housing. No local game engine, regression suite or new controller was run or created.
