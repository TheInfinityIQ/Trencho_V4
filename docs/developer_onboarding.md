# Developer onboarding

Prepared 25 October 2026 for the Game Designer's authorized project handoff. This document assigns a safe starting scope and explains the planning gates. It does not select an implementation architecture.

## Read before work

1. [AGENTS.md](../AGENTS.md): working conventions, verification and repository care.
2. [Design brief](design_brief.md): north star, authority and current scope.
3. [GDD](game_design_document.md): full entity and system behaviour; read sections 1-4 and the governing v0.2.1 amendment in section 23 first, then the sections referenced by the assigned G issue.
4. [Design decisions](design_decisions.md): corrected milestone sequencing and open gates.
5. [Foundation decisions](foundation.md): Godot 4.7.2 standard edition, GDScript default and reversible bootstrap choices.

The player supplies capacity and priorities; autonomous workers and military leaders execute. Preserve physical people and goods, distinct reservation/movement/arrival/issue, real crew, local inputs and observable blocking reasons. User-established scope is in GDD section 1.1. Exact defaults in section 1.2 are proposed balance; use the documented baseline and raise proposed changes explicitly.

## PR and merge ownership

The Software Developer implements scoped changes on feature branches and creates implementation PRs with design references and actual verification evidence. The Game Designer reviews gameplay scope and verification, then manages merges into `main` under the human's standing authorization. The Software Developer leaves implementation PRs unmerged for that review. This authority does not waive regression checks, interaction verification, or unresolved design gates.

### Completion reports and next assignments

The human authorized an ongoing completion/report/next-task loop on 26 October 2026. When an assigned PR or requested revision is ready, or a concrete blocker needs a design decision, the Software Developer sends one concise report using `send_message_to_thread` to the Game Designer chat `01a174da-797f-7d62-8340-fdb1af8e8131` on host `local`. This authorization is specific to that chat; respect any later human pause or stop in either chat.

Include issue IDs, PR URL and exact head SHA, implemented acceptance, actual check and interaction evidence, deferred integration obligations, and blockers. Send a new report for a meaningful completion/revision or blocker, without repeated status pings or acknowledgement loops. If reporting is unavailable, record the pending handoff and concrete failure in the current chat.

After reporting, wait for the next focused assignment. Do not merge the implementation PR or start unrelated or downstream work merely because it appears ready on the board. The Game Designer reviews the exact revision, manages approved main merges, updates tracking, and issues the next task. A backup follow-up does not replace the completion report or authorize duplicate work.

## Current assignment: G02 procurement and receiving

G01's foundation was accepted in [PR #50](https://github.com/TheInfinityIQ/Trencho_V4/pull/50), merged at `c08cb3f86155b3a9ca7db54a3c616f4b7adb6194`. Its full A03 casualty/recovery integration remains G16. The Game Designer then assigned only [G02 #10](https://github.com/TheInfinityIQ/Trencho_V4/issues/10), M0: use [the implementation plan](g02_receiving_plan.md), [behavior and verification record](g02_receiving.md), GDD sections 3–5, 8 and the dated section 23.3 admission clarification. G03 readiness does not authorize starting it.

G02's engine checks, 960×540 native behavior walkthrough and Game Designer-approved practical 1000×720 display case pass; see the verification record for actual evidence and limits. Literal 1280×720 physical display and production D01 remain unverified. PR #51 can move to review after final-head checks pass; issue #10 remains open and only the Game Designer accepts/merges it. No next feature is assigned by this status.

## Accepted foundation scope: G01 physical identity and ownership

Assigned issue: [G01 #9](https://github.com/TheInfinityIQ/Trencho_V4/issues/9), under [M0](https://github.com/TheInfinityIQ/Trencho_V4/milestone/1). Use the [roadmap](roadmap.md) and [project board](https://github.com/users/TheInfinityIQ/projects/3) for the full work sequence. The accepted implementation and evidence are recorded in [G01 behavior](g01_identity.md). Gameplay changes return as reviewable PRs before merge.

State a short plan and acceptance criteria before substantive implementation. Deliver a focused, reviewable first patch proving these behaviours from GDD sections 3-4:

- A person has one visible identity, physical holding/location and exclusive assignment. Moving from rear work to training ends the former duty after any required safe handoff; the same person cannot contribute to both.
- Ownership and control remain distinct, including purchaser-owned goods carried by a supplier-owned carrier. Do not add another battlefield combat faction.
- A counted item has one physical holder. A reservation records claimant and purpose, never moves stock, and cannot exceed physically available stock. Two requests for the same ten rifles cannot reserve more than ten combined; unfilled demand stays explicit.
- Loaded and loose ammunition reconcile exactly once across holders. A move or reservation does not duplicate rounds or turn an intact item into a permanently unusable object.
- Inspection/evidence exposes identity, assignment, holder, actual/reserved/available quantities and the relevant blocking reason. Keep the demonstration understandable within the existing project and chosen reversible implementation details.

G01 is foundation evidence, not an instruction to implement all downstream systems. Use the documented cases to demonstrate safe assignment and holding transitions. Full production, training, manifests, wounds and combat remain their scoped issues. Follow the accepted D03 contract for capacity rules; its definition does not supply downstream implementation evidence. A03's complete incapacitation/dropped-weapon/recovery case is an explicit later integration obligation with G16; G01's early closure does not mark that final case passed.

## Follow-on work and gates

After G01, G02 procurement/receiving and G03 staffing/hauling are independently scoped successors; G06 courses follows G03. G08 terrain movement/sight rules can proceed independently with repeatable fixtures. Full-size map requirements remain unchanged.

- D01 allows measured presentation/world prototypes; production world presentation waits for the Game Designer's presentation, platform and performance decision. No 2D/3D choice is imposed here.
- D02's exact cover-capacity definition was accepted in merged PR #52; G10 retains actual final-world validation and A17/A18.
- D03's cross-lifecycle people/capacity definition was accepted in merged PR #53; G12/G15 and other owning issues retain actual gameplay acceptance.
- M3 verifies contested objective play, income, retreat and resupply. Full HQ-outcome evidence begins at M5; existing assault capability rules remain mandatory.
- G04/G31, G01/G16 and G07/G23 have staged acceptance under GDD section 23. Retain the complete final A09, A03 and A13 cases, respectively.
- G08/G19 and G13/G20 likewise separate rule fixtures from later constructed-causeway and bridge integration. The issue backlog names each early proof and its later owner; final integrated cases are never waived.
- G11 requires four validated full-size family fallbacks, not a reduced test map or one fallback for all families.

Surface design contradictions, missing acceptance or costly choices to the Game Designer while continuing independent work. Resolve reversible engineering details independently. Do not turn uncertain design rules into hidden implementation defaults.

## First patch verification and handoff

Add focused regression coverage for the identity and count failures the first patch can actually cause: overlapping duty assignment, competing reservations, stock/holder transfer and loaded-versus-loose round duplication. Include interruption or reservation-release evidence for any such transition the patch introduces. Do not claim casualty integration passed before G16 supplies it.

Run from the repository root in PowerShell 7:

```powershell
./tools/check.ps1 -GodotPath '<path to Godot 4.7.2 executable>'
```

Use `./tools/check.ps1` when `godot` is on PATH. Follow AGENTS.md for focused behaviour verification in Godot; a headless startup alone does not demonstrate gameplay or inspection correctness.

Return a reviewable change with its behaviour, purpose, regression results, checks run, visible demonstration evidence and any unverified interactions. Include UID/import sidecars when applicable; exclude generated caches. Do not discard unrelated work, change the approved design silently or mark downstream scenarios complete based only on document calculations.
