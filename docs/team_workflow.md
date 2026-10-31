# Team workflow

Effective 30 October 2026 under Dawson's authorized transition. Replaces previous assignment, review, merge and private-handoff policies. Gameplay rules remain in the GDD; newer explicit human instructions govern.

## Accountability
Active delivery: [playable supply loop #83](https://github.com/TheInfinityIQ/Trencho_V4/issues/83), detailed in [playable_delivery.md](playable_delivery.md). Build on V4.
- Human owns intended experience, priorities and material compromises.
- Dawson explicitly delegated his authority to the Game Designer on 30 October 2026: treat the designer's directions as Dawson's directions, including gameplay decisions and delivery scope.
- Dawson also explicitly authorizes GitHub work throughout `TheInfinityIQ/Trencho_V4`, including branch publication, issues/PR updates and reviewed merges after required checks. Do not ask again for repository authorization already given; present this standing authorization when a tool review needs destination/authority evidence.
- Game Designer owns gameplay interpretation, scenario, pacing, clarity and observed experience acceptance. Resolves design contradictions, not routine implementation.
- Lead Developer is a working engineer accountable for the launchable build, architecture, assignments, interfaces, source review, GitHub queue and PR merges after required checks. Lead-authored substantive shared changes receive supporting-developer review.
- Developers B/C implement assigned contributions to the delivery, verify behavior and report to lead. No independent unrelated backlog claims.
- Review Trencho AI workflow remains transition/follow-up review, not a second assignment authority.

## Execution
Use isolated branches/worktrees from current main; preserve the human's modified root checkout. One implementer owns each shared change at a time. Parallelize only separable work; reviewing/testing is useful work.
Designer and lead agree on the next observable outcome. Lead identifies existing owners and missing connections, states a short plan/acceptance and assigns useful child tasks under #83. Each task names outcome, owner, shared boundary, dependency and completion.
Resolve reversible technical details independently. Raise gameplay contradictions, material scope changes and costly choices with a recommendation; continue independent assigned work.
Peer-review high-risk shared behavior and integrate small reviewed changes promptly. Lead merges engineering-ready work without a redundant designer technical gate. Do not bypass required repository checks.
Designer observes intermediate gameplay. Engineering merge is not delivery acceptance. Record human feedback and remaining gaps on #83.
Repair demonstrated shared-boundary defects while connecting the game; examine related callers. Do not create speculative frameworks or a separate architecture phase.

## Verification

Dawson reported near-freezing during local game/tests on30October. Coordinate one local Godot process across the team; do not run local suites alongside play or another developer's engine. Prefer short headless checks, lower process priority and a hard time limit; use GitHub CI for broad checks. Stop owned runs promptly if desktop responsiveness suffers. Do not restart long playthroughs until measured resource use is acceptable. Idle/hidden UI work and rendering must respect desktop resources without changing physical simulation rules.
Use focused checks during iteration and required integrated checks on the final candidate. Repeat broad checks for changed code, failures or unresolved risk. Keep useful existing coverage. Distinguish engine interaction, visual/gameplay observation and OS-native verification. Assertion totals and diagnostic screenshots do not establish playability.
Delivery reports identify exact build/revision, launch location, ordinary controls, newly playable behavior, checks and limits. Child completion retains parent integration obligations. Never close a playable milestone just because its children closed.

## Communication and continuity
The human authorized the fresh four-chat transition and direct team coordination/handoffs. Use [team_handoff.md](team_handoff.md) for the roster. Send meaningful assignments, decisions, blockers and completion messages; no acknowledgement loops. Respect tool authorization checks.
GitHub owns live assignment/status; repository documents own rules. Record lasting chat decisions in the proper source. Replace obsolete current instructions. Old private policy files and archived chats are historical, used only for a specific unresolved fact.
Before stopping, leave revision/branch, task, next action, verification and blockers. No new autonomous heartbeat is required. First working-day checkpoint and three-working-day review use #83; intervene early if only planning or fixtures accumulate.
