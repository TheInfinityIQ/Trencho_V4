# 3D-03A: actual rear construction commands

Accepted pre-code contract. Baseline PR121 merge f9d94f7190687cc2c8e43f0cb0da8b42804fd1e5; Developer C owns implementation, Lead owns publication/remote check/review/merge. This first 3D-03 increment uses existing planar construction authority and the canonical manager pose from 3D-02A. A speculative global ledger conversion is not a prerequisite.

## Ownership and acceptance

Preview owns a small current candidate/revision and one pending intent. BaseDemo.confirm_build_at remains the shared command/result/selection owner; Construction.place performs its existing one full validation and real site/material/worker setup. Return the actual command result for 3D feedback. Do not pre-call a second full validation before place. Construction.cancel and the existing selected-site consumed-loss/current-identity confirmation remain unchanged.

A fresh current world click creates at most one actual site or shows its current owner's rejection. Successful placement selects actual result.id and clears that draft; failure keeps draft/orientation and exact cause. Draft RMB/Escape clears no real site. Committed cancellation uses existing Keep construction / Cancel construction disclosure, stale-decision checks and physical remaining-stock recovery. No automatic refund, retry, free labour, immediate completion, new reach rule or speed change.

## Input and freshness

Modal > management GUI > rear placement > rear look/RTS. World actions stay in unhandled input so GUI/typing consume first. Catalogue/menu/focus-reacquisition clicks cannot place. Observe releases, consume one intent before authority, suppress repeats and clear pending intent on focus/modal/view/session changes. One Escape handles one layer; typing R never rotates. Camera toggles preserve draft/orientation/player/speed but invalidate the old candidate.

Use explicit draft start/end/selection/rotation, session, geometry and camera/viewport notifications, removing the per-frame _draft_basis string poll. Candidate revision represents current aim, camera transform/projection/viewport, kind/rotation/draft generation and committed geometry/facts. Camera transform notification includes collision-arm movement. Relevant actual construction-blocker motion may wake a cheap refresh from its existing active-motion state; never scan inventory/whole-world state each render. A sealed candidate stores actual session/model/service/camera identities, revision, draft and queried point. Stale/pending/no-ground requests are discarded, never retargeted or retried.

Closest-solid ray queries run in physics. WorldPresenter exposes the actual rear-ground collider reference. A roof/table/wall first hit invalidates the prior ground target; do not ray through it or treat roof Y as construction permission. Only a finite rear-ground hit projects scene X/Z into existing footprint/entrance/access checks. A footprint overlapping another structure can still be rejected from an adjacent-floor hit. Numeric explicit commands remain shared owner actions, never world click-through. No backend building-height or new terrain rule.

Cheap placement_hint ghosts are amber/provisional, known invalid red with the real cause. Green only follows an explicit full Preview of the identical current candidate/facts; a small Check placement action may reuse that existing preview boundary. A change returns it to provisional. A pending indication exists only while a real query/intent is outstanding. Ghost tint is no reservation. Keep command feedback until a meaningful new user adjustment/action rather than overwrite failure with cheap-clear text.

## Committed presentation and limits

Refresh from committed state: actual ID, construction state, materials/labour requirement and provisional footprint volume. Cancelled loose goods/reserved space remain truthfully indicated until recovered; show a material/reservation marker, not an intact building collision wall or instant refund. Current facility boxes/provisional height are not a completed facility model roster. No asset campaign, new import dependency, camera model, combat/ledger/route/fuel rewrite or default-entry flip.

Narrow files: Preview input/candidate/feedback; BaseDemo draft notifications and existing command result; WorldPresenter ground/camera notifications and provisional site/ghost display. ConstructionService stays unchanged unless an actual missing API is demonstrated. Update reviewed purposes and source-linked UI flows; retain regression fixtures.

## Relevant Godot API consultation

- [InputEvent routing](https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html): GUI gets its opportunity before _unhandled_input; consume the event once. _input observes releases/Tab, not world construction clicks.
- [Ray casting](https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html): direct-space reads belong at the physics boundary; query global ray coordinates and inspect the actual hit collider.
- [Node3D](https://docs.godotengine.org/en/stable/classes/class_node3d.html): transform-change notifications can invalidate the actual active camera, including inherited rig changes. Scene transforms do not become construction/accounting authority.

Project generations, command sequencing and ground-role decisions are our small ownership design using these APIs, not a generalized framework.

## Verification boundary

No local engine or regression/broad/FPS run. After source freeze propose one ignored brief changed-feature demonstration of an actual world candidate/placement and its rejection/cancellation feedback boundary as needed; Lead selects one bounded remote execution/captures and obtains technical/Designer/UIUX disposition. Do not rerun prior opening/manager scenarios. Source parsing is not native input, visual facility-art or full-game acceptance. [Ownership diagram](diagrams/3d_construction_commands.mmd).


## Source delivery and current launch

Opening `game/preview_3d/preview.tscn` with F6 now enables **actual construction commands**, not the former 3D-01 no-spend preview. The temporary guard/property is retired; historical 3D-01 evidence keeps its original uncommitted scope. Default F5 still uses the existing main. Facility volumes and their height remain explicitly provisional.

The implementation uses one local candidate and one consumed intent, explicit draft start/end/selection/rotation notifications, actual camera-ray transform/projection equality at transform notifications, and actual rear-ground collider identity. Unchanged SpringArm notifications do not invalidate. Unrelated session events revoke a fully checked green ghost but do not erase a pending click or replace static bodies. Only changed committed construction footprint/state/remaining-goods records rebuild site proxies and invalidate geometry; a newly changed collider is queried after the following physics synchronization boundary. This is a small scene-local record, not a global inventory hash/poll.

For existing construction trucks, only clearance membership in the current candidate footprint matters: known service truck IDs use their actual holder-chain positions, without inventory inspection; entering/leaving wakes the cheap hint, irrelevant motion does not starve placement. Authority still checks current facts once at place. Command feedback is bridged from the existing BaseDemo result path so selected-site cancellation stays truthful after management closes. The 3D composition retains drafts across management panels with a narrow opt-in flag; 2D panel behavior is unchanged. Actual returned site selection is restored when hidden construction rows refresh.

One proposed ignored demonstration will exercise this changed flow at actual 1x, not pause to mask freshness starvation. It will perform a current world rejection, one actual placement and its unconsumed selected-site cancellation/feedback. No old opening/manager scenario or consumed-loss fixture rerun, broader matrix or new rendered campaign. OS focus is required by real world input; Lead chooses the bounded execution/capture transport. No engine or demonstration has run locally.


Exact ignored proposal: `logs/3d-construction-commands/direct_demo.gd`. Within that same 1x process, rendered execution records construction_provisional.png, construction_placed.png and construction_cancelled.png after the corresponding physics/update and frame_post_draw; headless skips images only. No native OS, consumed-loss, full stale/camera/roof matrix or full facility-art approval is claimed by this one flow. Identical pointer events, like identical camera notifications, do not invalidate a represented candidate. No demonstration or engine run has occurred locally.


## Accepted occupation-rule delta — before code

Designer approved active-3D manager occupation protection after the first actual 1x construction flow. At the shared BaseDemo boundary, provisional/full previews and both world/numeric confirmations reject a proposed rotated footprint intersecting the live upright manager capsule, with `Move away before placing here.` This is physical occupation, not a build-reach or extra handling-clearance rule. No teleport, material spend or site creation occurs on rejection. Construction.place remains the site/economic authority and still performs its one full check when the scene gate is clear.

Preview explicitly binds optional current CharacterBody3D and CollisionShape3D references from WorldPresenter. These follow the world/session lifetime and are cleared/rebound before an old world is freed. They remain bound while the rear is hidden for RTS observation: numeric management still sees the manager's actual rear occupation. Normal 2D never binds these references, so it gets no phantom scene blocker.

Use the current collision shape's world X/Z centre and actual CapsuleShape3D radius against ConstructionCatalog.footprint(kind,quarter_turn), with the nearest point on that rectangle. The existing capsule is upright and unscaled, with dimensions on its shape resource. Positive circle/rectangle intersection blocks; mere nonpenetrating tangency gets no added margin. Do not use art/eye/camera dimensions, cached player aim, a padded square around the body or the construction handling border. Read the actual body/shape anew at confirmation, even after a previously clear ghost. Disabled/nonexistent optional shapes do not create a physical blocker.

Relevant APIs: [CapsuleShape3D radius](https://docs.godotengine.org/en/stable/classes/class_capsuleshape3d.html) is the physical shape dimension; [CollisionShape3D](https://docs.godotengine.org/en/stable/classes/class_collisionshape3d.html) supplies that shape to its physics-body parent and a disabled shape has no effect. Keep this a small scene-occupation check, not a general collision/ledger framework.

The SAME one1x proposal may replace the former bounds rejection with a genuine near-foot manager-overlap rejection, then perform the same clear placement, selection, unconsumed cancellation and three captures. No additional scenario or limit increase. Numeric/full-preview/rotation coverage remains source-reviewed rather than an expanded runtime matrix. The earlier UI corrections and actual functional result at2705b808 remain recorded; current final identity/images remain Lead-owned.
