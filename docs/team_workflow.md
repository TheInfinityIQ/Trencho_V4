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

## Completion, next assignment and blocked work

Effective 6 November 2026 after Dawson reported an avoidable team stoppage.
The existing rule to request another task was insufficient: completed handoffs
waited on the lead, and the lead ended the active turn without dispatching the
next owned outcome. No gameplay question or requested playtest caused that gap.
The lead owns correcting it; a generic human “continue” is not a prerequisite.

1. Before a bounded task completes, its owner reports the exact revision,
   outcome, actual verification limits and next concrete action with its owner.
   “Ready for more work” alone is not a complete handoff. Propose a source-backed
   successor within the accepted demo; do not invent a feature to stay busy.
2. The lead processes each completion during the active coordination session:
   assign review/integration, dispatch the next ready bounded task, or record the
   exact dependency and who will release it. Preassign a separable successor
   when the next accepted outcome is already known. Developers may start that
   successor after freezing the prior handoff; no new generic resume is needed.
3. A completed trace with no defect closes that trace, not the team's delivery.
   Do not repeat investigations, approval packets or checks to create activity.
   An idle reviewer waiting on an explicitly owned implementation is acceptable;
   the lead continues dispatching and integrating ready work.
4. Keep blockers local to the affected action. A rejected push holds that push;
   it does not hold unrelated authorized implementation or local review.
   Preserve the rejection, never retry by an alternate route, and name the
   precise approval needed. Keep a pending tool approval separate from a
   gameplay question, missing lead assignment or human playtest.
5. A human-wait handoff must contain the actual unanswered question or requested
   playtest, its chat/build location and why dependent work cannot proceed.
   Unverified whole-demo acceptance is not an implicit request for a playtest.
   Continue independent accepted work while an answer or review is pending.
6. Before the lead ends an active work turn, inspect completed team handoffs and
   the existing team state. Every unfinished ready outcome needs a dispatched
   owner; every waiting outcome needs a named dependency owner and next action.
   A completed child or final status message must not silently complete #83.
   If all useful work is genuinely gated, report the exact gates and questions.
7. These are execution responsibilities, not an installed background service.
   Use the existing thread tools to follow active work. Do not promise perpetual
   workers, add a heartbeat/second controller, or schedule a job-tracking
   automation. User pauses, tool permission boundaries and execution limits
   still apply and must be reported honestly.

The current assignments and scoped waits live in
[team integration state](team_integration_state.json). GitHub remains the public
execution record; local unpublished preparation must be labelled as such.

~~~mermaid
flowchart LR
  Work[Owned bounded work] --> Handoff[Exact revision and result]
  Handoff --> Lead[Lead dispatch decision]
  Lead --> Review[Owned review or integration]
  Lead --> Next[Preassigned next accepted task]
  Lead --> Gate[Exact scoped dependency]
  Review --> Lead
  Next --> Work
  Gate --> Independent[Continue independent ready work]
  Gate --> Human[Ask precise question or request playtest if required]
  Human --> Lead
~~~

The plan/execute/review loop is consistent with OpenAI's
[long-horizon task guidance](https://developers.openai.com/blog/run-long-horizon-tasks-with-codex).
The task ownership and stopping rules above are project decisions, not claims
that a Markdown file installs automatic continuation.
