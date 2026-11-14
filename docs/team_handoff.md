# Team transition handoff

## Current consolidated handoff — 10 November 2026

Dawson authorized the bounded consolidation in adviser chat
`01a1b3e9-a21c-7e62-855a-8d369f305b83`, human turn
`01a1c6de-2e95-7312-bc28-cd14c7add017`. [Current workflow](team_workflow.md)
and [existing roster/state](team_integration_state.json) govern. Lead is the sole
programmer/integrator and owns routine UI/UX; the separate UI role completed its
handoff and receives no further tasks. Designer retains material gameplay
decisions and required exact-head review; Artist retains bounded asset ownership.
A/B/C and the original 2D Artist remain inactive. Requested model/speed defaults
are recorded separately from observed settings in team state.

Transferred UI decisions, preserved from the completed handoff:

- Building E opens that actual building's controls; inspection never starts a
  blueprint. Relevant edits require explicit confirmation.
- Build mode uses an overhead grid and explicit placement. Cancelling a preview
  differs from cancelling a committed site; the latter discloses actual losses.
- Hauling priorities are top-first, grip-reorderable with fallback controls and
  confirmed as a draft. Actual carries finish safely.
- Construction distinguishes earned work, consumed materials, on-site stock and
  physical goods in transit.
- Warehouse inspection reports actual readiness/inventory. Full, preparing,
  route blocked and waiting for haulers remain distinct; an unprepared position
  is not ready storage.
- Rear first/third person share one player; battlefield uses its independent RTS
  camera. Menu/mode changes preserve player and simulation state.

Current product references: [design brief](design_brief.md),
[playable delivery](playable_delivery.md), [construction](place_manage_buildings.md),
[hauling](hauling_priorities.md) and [warehouse](warehousing.md).
Existing UI sources: `game/rear_base/base_demo.gd`,
`game/rear_base/workforce_panel.gd`, `game/rear_base/hauling_priority_list.gd`,
`game/logistics/army_supply_panel.gd` and `game/preview_3d/preview.gd`.
`C:/Users/dawso/Developer/Projects/Godot/trencho_ui_workspace` is a separate mockup
reference, not current game authority.

PR145 is **merged**, with warehouse-core main adoption at
`a2d182f367bf584315f9e516a91152198e333204`; the UI handoff's draft status is stale.
Return cargo and Clear a bay remain **proposals/open follow-ups**, not shipped
controls. Preserve the [recovery proposal](warehouse_recovery_menu.md): return
uses the same present truck, finishes safe carries, retains the transport fee and
refunds eligible goods once on actual exit. Optional reload obeys actual packing
space. Clearing a bay reserves and physically relocates one whole batch to bounded
staging, prevents refilling and admits no second batch until staging empties.
Unloading, finishing carries, reloading, departing and actually exited/refunded
are distinct states; an estimated refund is not available balance. Staging is
neither a refund nor automatic overflow. Numbered human playtests and wider-loop,
paired-timber, recovery and 60 FPS acceptance remain open as documented.

Full supplied handoff provenance:
`C:/Users/dawso/Documents/Codex/2026-11-06/you-ll-be-responsible-for-keeping/work/trencho-consolidation-2026-11-10.json`,
field `ui_handoff`. This compact transfer preserves decisions without duplicating
the instruction library. The transition changes documentation only; no gameplay
work, animation, verification run or publication is resumed by this record.

## Historical transition — 30 October 2026

Everything below retains the original transition's provenance. Its roster,
baseline, bootstrap restrictions and assignments are not current instructions.

30 October 2026. Live work: [#83](https://github.com/TheInfinityIQ/Trencho_V4/issues/83). Operating authority: [team_workflow.md](team_workflow.md).

## Baseline and preservation
Main ecac1f16dc77f81191aa30f1d32fd9fad0015046 includes PRs #77, #80, #81 and #82. PR82 reviewed head 50503bb passed recorded PR validation. This is historical evidence, not a new playtest.
Existing shared services and rear economy are substantial. Diagnostic fixtures do not establish a connected engagement. Lead must verify exact remaining world, autonomy and supply-loop connections. Persistence and full D01 certification remain open.
Root C:/Users/dawso/Developer/Projects/Godot/trencho_v4 is stale with a human project.godot edit. Preserve it. All outgoing branches/worktrees/archives remain. Transition checkout .artifacts/team-delivery-transition is not a shared developer write location.
Outgoing historical chats: designer 01a1808e-aa30-7cd1-9f5b-81bce5a8c6c9; A 01a18def-ac27-72a0-af10-62175da491af; B 01a18df1-0228-7332-82f1-a9af71e56502; C 01a18df2-3eaa-75b2-b0fe-805519216851. Old private coordination/onboarding instructions are superseded.

## Fresh roster

All host local, project Trencho v4 experiment.
- Game Designer: 01a18e60-cd67-7b01-8047-a8768208b387
- Lead Developer: 01a18e60-e281-7de0-9169-ac9d4db14f3e
- Developer B: 01a18e60-ef39-7af1-8281-a9ab8825a6ba
- Developer C: 01a18e60-fe63-7da0-a1a6-8557effd2d65
- Transition/follow-up reviewer: 01a18e11-8008-7883-b712-89d1d81dc0bc

Human authorized direct coordination among these four chats. Lead owns assignments/engineering merges; designer owns gameplay/experience. Bootstrap assessments are read-only until transition owner sends activation. Thereafter work proceeds under #83 without waiting for additional routine human confirmation.

## Outgoing factual handoff

Outgoing designer checked 19 worktrees: only original root project.godot was modified; all other reviewed worktrees clean. No open PRs remain at baseline. Unmerged codex/d01-presentation-readiness d25556075847c0a893c62f77ed9423d5741a47b2 retains the engineering evidence packet; preserve and consult it, do not treat it as production certification. M0 remains unreleased and literal APC capture A30 belongs to G25 #33. Local automation inventory had zero definitions; no active old-team automation IDs were known.

## Initial assignments
- Designer: declare representative scenario and player decisions/pacing under #83; inspect build and raise only material choices with recommendations.
- Lead: own isolated worktree, bounded baseline inventory, shortest playable increment and engineering assignments. Review transition documentation PR before integrating it.
- B: read-only inspection of dispatch-to-battlefield supply continuity, reusable owners and concrete gaps; send findings to lead, then implement only with assigned write ownership.
- C: read-only inspection of unit activity/occupancy and damage/movement interruptions, specific risks and useful regressions; send findings to lead, then implement only with assigned write ownership.
No exhaustive audit or unrelated self-assignment. Team implementation proceeds under #83.
