# Gameplay developer team

Authority: Dawson's explicit request on 5 November 2026 adds three developers,
all `gpt-6.1-sol` with `xhigh` reasoning. The lead delegates and integrates;
developers test their own work and create draft pull requests. The current
delivery remains the connected demo in issues #83, #90, #91 and #92. Broader
features require an actual assignment, not a historical issue or old role.

## Active assignments

| Developer | Initial feature | Isolated worktree | Branch |
| --- | --- | --- | --- |
| army_supply_developer | First genuine Army need, physical recipient issue and capability feedback (#91) | `C:/Users/dawso/Developer/Projects/Godot/trencho_dev_army` | `codex/dev-army-loop` |
| operations_developer | Continued feasible operations and real objective/replenishment feedback (#92) | `C:/Users/dawso/Developer/Projects/Godot/trencho_dev_transport` | `codex/dev-troop-transport` |
| player_experience_developer | Discoverable next actions through the actual demo (#90/#83) | `C:/Users/dawso/Developer/Projects/Godot/trencho_dev_onboarding` | `codex/dev-player-onboarding` |
| Lead | Factory expansion, actual school/Driver, manufactured supply truck and repeated rear-to-HQ delivery | `C:/Users/dawso/Developer/Projects/Godot/trencho_v4` | `codex/gameplay-demo-integration` |

Initial developer branches start at `8cafd45294c2c72dc872c33e05bd3619c4cf3b2c`.
They do not contain the lead's uncommitted truck changes. No developer may
assume those changes are published, approved or tested. Shared UI integration
in `base_demo.gd` and `command_shell.gd` remains with the lead until explicitly
reassigned. Claim shared military files before editing. Generated maps belong
to each branch; regenerate and review after integration instead of copying a
different branch's stale generated results.

## Onboarding and delivery

1. Read AGENTS, the current GDD/playable delivery, team state, engineering
   lessons, objective workflow and relevant overhaul records. Read actual
   source and query the relevant map entries before editing.
2. Trace one current player outcome, identify the actual gap and agree bounded
   ownership and observable acceptance with the lead. Save the prospective flow
   diagram and state/command/event/cancellation contract before implementation.
3. Research specific engine decisions in official Godot documentation or the
   supplied local documentation. Record the source and why it applies. A design
   pattern is a means to solve a concrete problem, not a reason to expand scope.
4. Implement against authoritative owners. Use narrow current facts and actual
   events. Preserve identity, physical custody, cancellation, pending work and
   late/duplicate-event safety. Avoid broad snapshots, idle polling and redundant
   state owners. Preserve opening resources, recipes, prices and real army need.
5. Run brief headless checks of the changed behavior and necessary regressions.
   Freeze meaningful acceptance before editing, retain failures and correct an
   invalid verifier as a reviewed new contract. Do not weaken limits, fabricate
   supplies or call a component demonstration ordinary whole-game acceptance.
   Do not launch broad benchmark campaigns or steal desktop focus/cursor.
6. Update living map, clickable diagram and button contracts. Examine every
   changed/new function's purpose and current implementation hash; both strict
   checks must pass. Report actual checks, unresolved failures and evidence limits.
7. Commit, push a dedicated branch and create a draft PR against
   `codex/gameplay-demo-integration`. Describe resulting player behavior,
   design diagram, verification, risks and remaining acceptance. Provide exact
   PR, commit and usable test steps. Retain UID files and unrelated work.

Use feature-level Objective / Outcome / Next task updates. Work toward a
testable increment rather than stopping at an internal implementation step.
When a task finishes or is blocked, report to the lead for the next approved
task; do not invent a new feature or start a scheduled continuation loop.
The lead keeps useful assignments active while this session and available
capacity permit. These agents are not an always-on background service.

## Review and integration

The lead reviews each developer's exact PR commit for correctness, Godot
lifecycle use, ownership, regression risks, event-driven behavior, physical
invariants and meaningful test evidence. The Game Designer named in
`team_integration_state.json` reviews every PR, including the lead's, for
gameplay, scope, pacing and player-visible behavior. UI/UX and Artist remain
consultants for their existing roles; consultation is not design approval.

Both reviews must name the PR and exact SHA and state approved, changes
requested or blocked with reasons. A new commit requires review of its changes;
an old approval does not silently cover new behavior. Keep approval pending
until explicitly received. CI, a green map, a draft, publication, a worker claim
and a design diagram do not substitute for a role's approval. Never claim a
native GitHub approval was submitted if only a review note was recorded.

No developer self-merges. The lead resolves integration conflicts, regenerates
maps and verifies the combined behavior before proposing merge. The lead's
technical review cannot establish their own independent review; request a peer
when that independence is needed. Game Designer approval is still mandatory.
No automated merge, bypass, credential change or repository-policy change is
authorized by this workflow.

Each worktree has one bounded task execution/retry owner. Parallel developers
do not nest native Goals, manual controllers, CLI workers or scheduled retries.
Keep durable feature/evidence records and a small handoff describing ownership,
next action and blockers, so interrupted work can resume without guessing.
