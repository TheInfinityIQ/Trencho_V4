# Team workflow

Updated 6 November 2026 under Dawson's direct instruction to align design and development. [Current participants and publication](team_integration_state.json) govern; historical assignments are context, not active authority.

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

### Responsibility and permission questions

Dawson's direct 6 November instruction: all developers, including UI/UX, bring
questions about responsibilities, permissions, repository access and PR submission
to the Lead Developer. Contributors use the same routing for integration questions.
Do not ask Dawson directly for routine engineering or repository authorization.
The lead resolves matters within standing authority, coordinates gameplay questions
with the Game Designer and owns the established PR review and merge process.

Report a rejected action to the lead with its exact revision/payload, destination,
stated reason and work that can continue independently. Hold that action without
bypassing its rejection. If direct human approval or a decision beyond delegated
authority is genuinely required, the lead presents the concrete question to Dawson
in the lead chat. Existing direct restrictions on whom an individual developer may
contact remain binding; send peer-review coordination through the lead when needed.
The Game Designer retains direct communication with Dawson about game design.

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


## PR review and merge decisions

Dawson's standing 6 November instruction: developer submits a PR, then requests
Lead Developer technical review and Game Designer game-identity review. The lead
merges after both approve the current version and required repository checks
pass. Routine publication, recording these role decisions and an eligible merge
do not require another permission question to Dawson. This supersedes the
earlier per-action publication/merge holds; genuine new tool rejections still
must be respected and explained.

The [review lifecycle diagram](diagrams/pr_review_lifecycle.mmd) was recorded
before this decision table. These are project responsibilities, not a new
scheduler or automatic merge service.

| Lead decision | Designer decision | Next action and owner |
| --- | --- | --- |
| Approve | Approve | Lead checks current head, required checks, draft/merge state and unresolved blocking findings; records decisions, makes ready and merges when eligible. |
| Approve | Changes requested | Developer addresses the concrete design requirement. Lead checks engineering implications; both review the resulting head. Lead does not override game identity. |
| Changes requested | Approve | Developer fixes the technical finding. Designer approval does not bypass it; both review the resulting head with attention proportional to the delta. |
| Changes requested | Changes requested | Lead consolidates both finding sets into one owned correction plan. Developer implements it; reviewers decide the new head. |
| Approve | Pending | Designer owns the missing review; lead dispatches/follows it. No implicit approval from silence or elapsed time. |
| Pending | Approve | Lead owns the missing technical review and its disposition. |
| Changes requested | Pending | Developer can fix the known technical issue; Designer reviews the resulting version. Lead keeps the design reviewer assigned. |
| Pending | Changes requested | Developer can address the known design requirement; lead reviews the resulting version. |
| Pending | Pending | Developer requests both named reviews with exact PR/head, outcome, evidence and limits; lead owns dispatch and follows the actual review dependency. |

An explicit approval, a request for changes and a pending decision are distinct.
General comments or an old head's approval do not imply current approval.
Reviewers separate blocking findings from optional suggestions. A suggestion
must not silently become an unowned merge hold; required corrections state the
observed problem, expected result and responsible developer.

### Changes, disagreement and operational failures

- **New commits or a substantive merge conflict resolution:** re-evaluate both
  decisions at the new exact head. Review the actual delta and affected
  interactions; preserve earlier evidence without rerunning unchanged work.
  A reviewer may reaffirm an unchanged area explicitly. Never use stale approval.
- **Technical/design requirements conflict:** lead and Designer compare feasible
  alternatives against the accepted game. Lead owns engineering feasibility;
  Designer owns game identity. Developer does not guess between contradictory
  instructions. Escalate to Dawson only for an unresolved change to his intent,
  material compromise or authority question, with a recommendation and precise
  affected scope. Neither reviewer can silently overrule the other.
- **Required check fails:** developer owns a current-code failure; lead owns
  diagnosing an infrastructure/permission failure and routing its actual
  remedy. Do not raise limits, remove checks, run deferred regression suites or
  broaden verification to make a green result. A queued/missing result is not a
  pass. Observe the owned run and act on a real change rather than busy polling.
- **Draft, conflict, stale head or merge race:** lead makes an approved PR ready,
  coordinates ordinary conflict resolution in the developer branch, and reads
  the current head/checks again. Merge uses the expected-head guard. A refusal
  causes state refresh and appropriate correction/review, not a blind retry,
  force push or branch-protection bypass.
- **Reviewer unavailable or review still pending:** lead requests the specific
  review and continues other ready accepted work. A task may wait on a named
  review; the team does not require a generic human continue. If no independent
  work remains, state who owns the missing review and the exact next action.
- **Duplicate or superseded PR:** lead identifies the real successor and
  preserved work, then closes the redundant PR with an explanation. Do not
  merge the same feature twice or delete its branch/evidence to hide history.
- **Closed/reopened or withdrawn scope:** inspect the actual current head,
  unresolved findings and remaining requirement before resuming. Closure is not
  proof the feature was delivered; a still-valid missing outcome gets an owner.
- **Tool/authentication rejection:** hold only the rejected action, retain its
  stated reason and ask for the precise missing authority when actually needed.
  Continue independent work; do not probe credentials, switch routes to bypass
  rejection or invent a repeated per-merge consent gate after standing authority
  already covers the action.
- **Human question or playtest genuinely required:** state the question or exact
  build/action to try, why it is required, and what can continue independently.
  Unverified whole-demo acceptance alone does not create a new playtest gate.

Record each role, exact SHA, decision, blocking findings and actual verification
scope on the PR. With the current shared GitHub account, explicit role approvals
are recorded as COMMENT reviews; they are not native GitHub APPROVED. Repository
protections remain binding: if a native independent approval is required, obtain
it through a supported authorized identity instead of treating a comment as a
platform override. Lead-authored substantive code also receives supporting
developer review; the Designer still reviews its game identity.

Immediately before merge, the lead confirms the PR is open/ready, the current
head matches both role decisions, required checks have passed and blocking
findings are resolved. Immediately afterward, read back the merged commit/state,
update the integration handoff and dispatch the next accepted outcome. A merge
is source integration, not full-game, playtest or FPS acceptance.

Primary references: GitHub's
[pull request review decisions](https://docs.github.com/en/pull-requests/reference/pull-request-reviews)
and [merge API](https://docs.github.com/en/rest/pulls/pulls#merge-a-pull-request).
The two-role policy and continuation routes above implement Dawson's project
instruction; they are not claims that GitHub COMMENT reviews are native approval.
