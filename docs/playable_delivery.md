# Connected playable delivery

## Worker and soldier integration — 9 November 2026

[Character integration](character_animation.md) connects the3D Artist's actual
worker/soldier models, clips and separate rifle to existing game state. Rear
workers now reserve distinct actual spawn/handling points instead of occupying
the Table centre. Existing cargo, timing, labour and army authority remain.
Scoped evidence and full limits are in that handoff; stages1/2 still await
Dawson's manual acceptance, and full-loop/60FPS acceptance remains open.

## Current 3D launch and player acceptance — 9 November 2026

The configured main scene now instances the existing 3D scene. Open the root
`project.godot` and use **F5 / Run Project**; F6 on `game/main/main.tscn` reaches
the same 3D opening. It uses the common session/controller, not a separate game.
The opening remains paused; Tab opens management to choose 1x. See the short
[controls and stage checkpoints](default_3d_playtest.md).

Stages **1 — buy people/raw materials** and **2 — place/manage buildings** are
implemented with prior scoped convoy/grid evidence, but remain **pending Dawson's
playtest acceptance**. Source/CI success is not completion of those game-loop
stages. Deliver a playable checkpoint after each numbered stage and record his
feedback before its dependent expansion. Independent authorized work can continue.
Normal configured-entry observation is a separate narrow receipt; it does not
prove native input, the full loop or 60 FPS. Earlier opt-in/old launch notes and
source receipts below are historical. Current ownership is Lead-only.

Configured-entry run42649451270 and required run42649450688 passed at `db61a78`.
The [verified receipt and image](evidence/default_3d_entry/startup_result.json)
establish one shared 3D session and the unchanged paused opening through the
normal project entry. The required job had no changed production scripts; actual
startup loaded the game dependencies. Neither job establishes player acceptance.

## Scoped convoy and planning-workflow increment — 9 November 2026

[PR138](https://github.com/TheInfinityIQ/Trencho_V4/pull/138) contains the development
opening with four real unloaders, paid immediate supplier convoys, last-handover
ordering readiness, contextual site E and explicit overhead grid placement. Game
source `60925c72c3cbd6d33f48a5286a0b93d8be999cf7` passed required run42638041856
and the existing bounded current-change episode42638052133. The episode observed
25Metal/eight-worker arrival, order unlock, one real site, its E/Set-builders
controls and harmless subsequent draft cancellation. It used injected input and
explicit same-model elapsed intervals, with current Purchase/grid captures;
native controls, wall-time/FPS and the full factory/army loop remain unverified.
See [retained scoped result](evidence/development_convoys/scoped_result.json).

The first planning/accounting protocol is in [development workflow](development_workflow.md),
with three [candidate alternatives](workflow_experiments.json) prepared for later
comparison and a [partial resume-pilot snapshot](evidence/workflow/convoys_resume_snapshot.json).
Historical repair costs remain unknown; source/visual findings and failed receipts
are retained. This increment does not close #90/#91/#92 or adopt the MCP plugin.
Use the PR's actual merge state/current main for adoption; the dated snapshots
below retain their historical scope and do not reactivate archived developers.

Updated 6 November 2026. Parent: [#83](https://github.com/TheInfinityIQ/Trencho_V4/issues/83). The partial prototype is merged into `main` at `ab2a4063d2c3d309ce4ad37a860fc9804ebd58dc` through [PR #89](https://github.com/TheInfinityIQ/Trencho_V4/pull/89). Design: [current GDD](game_design_document.md). Developer publication/status: [team integration state](team_integration_state.json), [implemented features](implemented_features.json) and [prototype completion](prototype_completion.json).

The four current delivery goals #83/#90/#91/#92 are grouped in [demo milestone #9](https://github.com/TheInfinityIQ/Trencho_V4/milestone/9) and the Project #3 **Current demo** view. Wider requirements remain in the eight later milestones and **Later backlog**; retaining them does not make each one a present demo blocker.

## Main adoption and launch

PR #89 merged after supporting technical review `5809571546`, lead technical review `5809571664` and Designer review `5809571746` at the same exact head `3859e9b7670c1350d12a2b15c9f4d0a20dc8c95a`. These decisions preceded source merge `ab2a406`; they are role COMMENT reviews, not native GitHub APPROVED. Required validation `42330520766` passed at that head; production validation `42330067869` also passed. Main validation `42330742832` / job `128276446850` also completed successfully at exact `ab2a406`, with changed-production parsing passed and the optional demonstration skipped; B independently observed the actual head/jobs/steps and no watcher remains. These source/parsing receipts do not establish ordinary full-loop or native/FPS acceptance.

[PR #101](https://github.com/TheInfinityIQ/Trencho_V4/pull/101) was merged into integration at `65006544f27055875008d3c83408094d77b0dd21` and is included in main. [PR #100](https://github.com/TheInfinityIQ/Trencho_V4/pull/100) was closed unmerged as superseded. The 6 November main-adoption snapshot has zero open code PRs after these dispositions; the forthcoming documentation handoff and new feature PRs are separate. This is a dated snapshot, not a perpetual live PR count. The lead owns live repository readback.

For the player: update a clean local `main`, open `project.godot` in Godot and press **F5**. The main scene starts in the paused empty field. Preserve local changes before updating; this handoff did not pull, reset or overwrite the human root checkout. This is a launch note, not a new playtest request or a claim that the game was run.

The source handoff is a partial prototype. Goals #83/#90/#91/#92, ordinary complete and repeated supply, pacing/readability, native input/rendering and strict 60 FPS acceptance remain open. Historical component results and failures retain their original scope; queued or unrun checks do not become passes because source merged.

## Intended experience

Start in the approved empty field as a controllable character. Buy workers and raw materials, place buildings, allocate jobs and produce useful goods. The Logistics Centre automatically fulfils actual army requests through physical loading, transport and HQ receipt. The autonomous army collects and uses supply, continues feasible resource operations and generates later needs in the same session.

Rear and battlefield keep their applicable work progressing while hidden. Waiting in one area must not silently halt the other. Pause allows inspection and management while stopping timed gameplay. The Developer owns the implementation of that behaviour.

## Next three gameplay outcomes

### 1. Self-sustaining factory — [#90](https://github.com/TheInfinityIQ/Trencho_V4/issues/90)

- From an ordinary new game, hire and receive workers, place facilities and allocate actual labour.
- Purchase ingredients and have eligible haulers supply staffed production automatically.
- Produce new Building Materials for further construction and usable military output.
- Show what changes when workers are reassigned and why input, labour or storage shortages stop work.
- Complete the sequence without diagnostic setup, grants, resets or a manual carry order for every routine load.

### 2. First useful automatic army supply — [#91](https://github.com/TheInfinityIQ/Trencho_V4/issues/91)

- A genuine army need identifies item, quantity, destination, priority and the capability waiting for it.
- The player can choose production and labour to address it; normal freight does not require a manual manifest or Depart command.
- Actual goods pass from the rear through physical loading, transport, HQ unloading, forward delivery and local issue.
- Withheld supply leaves a clear shortage. Received supply permits the recipient to regain the relevant actual capability when its other requirements are met.
- Distinguish newly manufactured supply from starting stock and HQ receipt from actual frontline use.

### 3. Continued operations and repeat replenishment — [#92](https://github.com/TheInfinityIQ/Trencho_V4/issues/92)

- The real transport returns and later genuine need can trigger another newly prepared physical shipment in the same session.
- Troops collect supply and resume their latest feasible acknowledged task; obsolete orders are not restored.
- Real objective capture, contest or loss changes ownership/income. A loss of personnel or capability remains a real limitation and may require replacement or withdrawal.
- Supply does not script a victory, create an enemy wave or bypass combat, route, crew and survival rules.

These are gameplay outcomes, not assertions that their whole ordinary path already works. The Developer maintains actual implementation/verification status and chooses bounded implementation tasks. Existing component results must not close these goals by themselves.

## What this demo does not wait for

The authored full-size Farmland scenario is sufficient. C30 manufacture-to-first-shot, a tank, the complete support roster, every procedural family, campaign and persistence remain wider requirements rather than prerequisites to the first connected demo. The [C30 child #87](https://github.com/TheInfinityIQ/Trencho_V4/issues/87) retains its own unfinished outcome.

The approved rear package and automatic shipping policy stand. Existing battlefield stocks, including 6,000 HQ rifle rounds, are unchanged. Any adjustment to when production becomes necessary is a separate explicit pacing decision with Dawson; do not manufacture urgency by silently removing stock or inventing consumption.

## Ownership and completion reporting

The Designer owns the intended experience, requirements and pacing choices. The Developer owns systems, implementation, permitted verification, integration, each new PR and a usable handoff. UI/UX owns presentation and interaction design in coordination with both. Historical B/C/Lead/Principle assignments do not activate new work; use the current roster.

Report Objective, Outcome and Next task, with exact published branch/commit and actual checks/limits. Publication is not gameplay acceptance. Keep foundation closure, connected implementation, observed ordinary gameplay and Dawson's feedback distinct.

Polishing, optimization and benchmark-driven work are paused. Keep known defects/performance results and the eventual 60 FPS target visible. Use brief direct checks of changed behaviour when needed; no routine full-suite or new test-infrastructure phase is introduced here. Living-map maintenance and current AGENTS.md still apply.

The lead next processes this separate documentation handoff, and continues A already preassigned Designer-accepted #91/#92 outcome: reconcile decreased or zero genuine Army demand before additional **automatic** shipment commitments. Preserve accepted cargo/crew/site/return rules, fixed manual quantities and explicit cancellation holds; zero demand must not create a player hold. No rates, starting HQ 6,000 rounds or threshold changes are included. The Designer identified a conditional source gap, not an observed ordinary-play result; A owns the bounded implementation, B its final source peer review, C read-only feedback/guard review using the existing Complete request lifecycle, and lead integration. This separate documentation PR is not a prerequisite for that independent work. Completed PR89/101 source reviews and the old two-trip/mounted-guidance sequences are not current tasks. No generic human continue, additional routine merge permission or implied playtest gate is introduced. Current instructions prohibit local engine runs and regression/broad-scenario campaigns; historical evidence is retained for later.
