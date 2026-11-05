# Team workflow

Updated 5 November 2026 under Dawson's direct instruction to align design and development. [Current participants and publication](team_integration_state.json) govern; historical assignments are context, not active authority.

## Responsibilities

- **Dawson:** intended experience, priorities and material compromises.
- **Game Designer:** overall vision, gameplay scope, meaningful decisions, rules, pacing and observable requisites. Owns the [GDD](game_design_document.md), resolves real gameplay contradictions and reviews player-facing consequences.
- **Developer:** creates the systems, chooses technical specifications/architecture, implements features, selects appropriate checks, owns integration, the current review PR and published delivery. Maintains implementation status and technical records. The Designer does not approve routine engineering choices.
- **UI/UX developer:** interaction, menu flow, visual information hierarchy and reusable presentation, coordinated with gameplay requirements and actual system state.
- **2D Artist:** sourced assets and their origin, license, attribution and modifications, coordinated with the Developer.

Consultants contribute through explicitly agreed work. Do not activate archived developers, old review authorities or competing integration loops. The current Developer remains the integration owner.

## From a goal to an implementation

The Designer defines the player-facing outcome, applicable rules and what a player should be able to observe. The Developer traces the existing implementation, identifies the missing connection, plans a bounded increment and chooses how to create and verify it. Technical diagrams/contracts, purpose reviews and the manual objective controller follow current AGENTS.md and [agent workflow](agent_workflow.md), not a GDD-prescribed architecture.

Bring actual gameplay ambiguity or a costly experience tradeoff to the Designer with a recommendation. Resolve reversible engineering choices independently. Reuse existing working systems; do not turn an unverified end-to-end outcome into an assumption that all its components need rewriting.

One owner edits each shared change. Preserve unrelated work and publish authorized results on the dedicated review branch. Identify the exact branch and commit. The Developer owns PR creation, supersession and merges; no force-push or silent history rewrite.

## Status, evidence and verification

[Delivery #83](https://github.com/TheInfinityIQ/Trencho_V4/issues/83) tracks the connected demo. [Implemented features](implemented_features.json) describes source-observed scope; [prototype completion](prototype_completion.json) records acceptance and limitations. GitHub issue/PR state is the execution record, not proof of the whole game.

A foundation issue can be closed while its later connected milestone remains open. Repair child checklists to reflect actual issue state without checking an unobserved milestone outcome. Preserve historical evidence and identify the exact limits of component or standalone demonstrations.

Dawson's current priority is gameplay. Polishing, optimization and benchmark-driven work are paused. Fix defects that prevent the current feature or corrupt state. The eventual 60 FPS target and known failures remain visible. Use brief direct verification of changed behaviour when needed; defer routine full suites and new coverage infrastructure. The Developer owns suitable testing within current human instructions.

Routine checks run headless or without taking desktop focus/cursor. Explicit foreground investigation is reserved for a reported issue when needed; background results do not certify native rendering/input or 60 FPS. Keep normal F5 behaviour unchanged. Follow the latest AGENTS.md and [verification policy](current_change_verification.md) where applicable.

Maintain the living system map and UI flowchart for project changes. The integration owner regenerates them against the final combined source; do not overwrite new maps with a consultant's older generated snapshot.

## Communication

Use Objective, Outcome and Next task in progress/completion handoffs. Say Completed only for the particular result actually verified. Provide exact published revision, changed scope, actual checks, remaining limits and next task. Keep human feedback distinct from engineering results.

GitHub carries current goals and status; repository documents carry lasting design and engineering decisions. The current GDD describes gameplay; historical detailed specifications preserve reference values and provenance rather than controlling implementation. Do not send acknowledgement-only loops or introduce another approval gate for ordinary work already authorized.
