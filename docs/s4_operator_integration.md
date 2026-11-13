# Approved S4 operation integration — 13 November 2026

Resume plan, frozen before production edits at local c4ac8a8. Dawson approved
both complete V02 movies with “It’s good”. The immutable Artist package and
prior diagnostics remain preserved. [Flow](diagrams/s4_operator_integration.mmd).

## Outcome and acceptance

An actual receiving hauler operates the approved shelf before accessing its
lower cargo. Upper cargo must be removed first. The shelf remains parked and
positively locked between packages. An actual hauler closes/retracts it before
departure, including supplier returns. The existing aisle reservation excludes
other handlers throughout approach, operation and exit. No inventory callback,
replacement person, animation-authoritative custody or repeating per-package
open/close is introduced.

Use existing Receiving time/boundaries and worker activities, composing a narrow
shelf owner into Freight. Views sample only committed active motion, and sleep
when hidden/paused/settled. Canonical root samples and visual Root-bone placement
come from the same approved export; apply the module transform exactly once.
Ordinary rear-worker geometry hides only while its dedicated operator export is
active, preserving the same person identity.

The required direct demonstration will arrange one actual S4 delivery and one
hauler, observe upper clearing, opening, locked lower service, closing and safe
exit using the changed owner, and inspect actual paired imported clips. It is
one bounded current-change check on GitHub, not a regression suite or native/FPS
acceptance. No local engine run.

## Boundaries decided before coding

- Packing uses the actual .18 m lower M05 insert top; upper clearance dependencies
  include all cargo on the same S4 upper deck before a lower pickup.
- Receiving owns source and warehouse claims. A close-only job carries no stock
  claim. Available haulers can finish closing even after the order cooldown
  unlocks at the last actual delivery.
- A return during operation locks remaining original goods and releases the
  uncollected claim, but the same actual worker finishes the safe mechanism cycle
  before exiting. Reassignment never interrupts a supported moving pan.
- No worker means a parked shelf and a waiting truck; no invisible operator.
- Debug delivery retains its explicit bypass, releases the actual operator and
  resets the empty fixture to secured travel state through the debug owner.
- Original seven clips/rig, other rack families, paired timber and independent
  carry-pilot appearance approvals remain separate.

## Engine rationale

Use paired AnimationPlayer manual seek from Receiving's committed activity time,
matching the existing supplier actor adapter. Godot documents manual mixer
processing and update-only seek; skip method/audio tracks so animation cannot
grant stock. Asset timing does not decide simulation completion.

- https://docs.godotengine.org/en/stable/classes/class_animationplayer.html
- https://docs.godotengine.org/en/stable/classes/class_animationmixer.html

Source review, imported animation verification, appearance approval and ordinary
player acceptance are distinct. Actual Game Designer exact-head review and
required checks precede Lead merge.

## Source-discovery amendment

The first edit applied the .18 m support to all S4 cargo. Review against the
existing accepted contract caught that the insert is M05-only before any engine
check/publication. The quote now declares a manual-bale variant and keeps other
S4 cargo on its original static rack/supports. This is a corrected planning
omission, not evidence of a shipped regression. Retain original restraint meshes
for travel and remove them using the existing before-pickup condition.

## Focused connection receipt — 13 November 2026

The first direct run43483595686 stalled after its check script read the optional
raw-order `facing_degrees` key directly. Detailed retained direct.log identifies
that check line; production already uses a zero default for the same field.
The corrected check uses that existing default and has a15-second fail-fast
watchdog for otherwise unhandled check errors, within the unchanged45-second
process limit. No approved animation or production shelf code changed.

Corrected GitHub run43528719333 passed at source
`0ae99026fb2a773ae53b2a8c0ec24b3a7e9938a1`: actual50kg M05, upper-first cargo,
same real operator, manual opening, parked lower service, actual closing/exit,
paired imported animation time/root alignment and paused view sleep. Required
script parsing also passed. This does not establish paired timber, warehouse
delivery, ordinary native input, visual approval of a new animation or60FPS.

The subsequent paired-timber/warehouse plan is separately frozen in
[paired delivery](feature_plans/paired_timber_delivery_v1.json). Preserve this
source-specific receipt when later integration heads change.
