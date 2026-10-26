# Developer onboarding

Prepared 25 October 2026 for the Game Designer's authorized project handoff. This document assigns a safe starting scope and explains the planning gates. It does not select an implementation architecture.

## Read before work

1. [AGENTS.md](../AGENTS.md): working conventions, verification and repository care.
2. [Design brief](design_brief.md): north star, authority and current scope.
3. [GDD](game_design_document.md): full entity and system behaviour; read sections 1-4 and the governing v0.2.1 amendment in section 23 first, then the sections referenced by the assigned G issue.
4. [Design decisions](design_decisions.md): corrected milestone sequencing and open gates.
5. [Foundation decisions](foundation.md): Godot 4.7.2 standard edition, GDScript default and reversible bootstrap choices.

The player supplies capacity and priorities; autonomous workers and military leaders execute. Preserve physical people and goods, distinct reservation/movement/arrival/issue, real crew, local inputs and observable blocking reasons. User-established scope is in GDD section 1.1. Exact defaults in section 1.2 are proposed balance; use the documented baseline and raise proposed changes explicitly.

## First assigned task: G01 physical identity and ownership

State a short plan and acceptance criteria before substantive implementation. Deliver a focused, reviewable first patch proving these behaviours from GDD sections 3-4:

- A person has one visible identity, physical holding/location and exclusive assignment. Moving from rear work to training ends the former duty after any required safe handoff; the same person cannot contribute to both.
- Ownership and control remain distinct, including purchaser-owned goods carried by a supplier-owned carrier. Do not add another battlefield combat faction.
- A counted item has one physical holder. A reservation records claimant and purpose, never moves stock, and cannot exceed physically available stock. Two requests for the same ten rifles cannot reserve more than ten combined; unfilled demand stays explicit.
- Loaded and loose ammunition reconcile exactly once across holders. A move or reservation does not duplicate rounds or turn an intact item into a permanently unusable object.
- Inspection/evidence exposes identity, assignment, holder, actual/reserved/available quantities and the relevant blocking reason. Keep the demonstration understandable within the existing project and chosen reversible implementation details.

G01 is foundation evidence, not an instruction to implement all downstream systems. Use the documented cases to demonstrate safe assignment and holding transitions. Full production, training, manifests, wounds and combat remain their scoped issues. Do not invent capacity rules while D03 is open. A03's complete incapacitation/dropped-weapon/recovery case is an explicit later integration obligation with G16; G01's early closure does not mark that final case passed.

## Follow-on work and gates

After G01, G02 procurement/receiving and G03 staffing/hauling are independently scoped successors; G06 courses follows G03. G08 terrain movement/sight rules can proceed independently with repeatable fixtures. Full-size map requirements remain unchanged.

- D01 allows measured presentation/world prototypes; production world presentation waits for the Game Designer's presentation, platform and performance decision. No 2D/3D choice is imposed here.
- D02 needs the exact cover-capacity fairness fixture before that validator can close.
- D03 needs the reviewed cross-lifecycle people/capacity matrix before related G12/G15 acceptance closes.
- M3 verifies contested objective play, income, retreat and resupply. Full HQ-outcome evidence begins at M5; existing assault capability rules remain mandatory.
- G04/G31, G01/G16 and G07/G23 have staged acceptance under GDD section 23. Retain the complete final A09, A03 and A13 cases, respectively.
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
