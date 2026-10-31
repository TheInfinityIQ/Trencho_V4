# Team workflow

Effective 30 October 2026 under Dawson's authorized transition. Replaces previous assignment, review, merge and private-handoff policies. Gameplay rules remain in the GDD; newer explicit human instructions govern.

## Accountability
Active delivery: [playable supply loop #83](https://github.com/TheInfinityIQ/Trencho_V4/issues/83), detailed in [playable_delivery.md](playable_delivery.md). Build on V4.
- Human owns intended experience, priorities and material compromises.
- Dawson explicitly delegated his authority to the Game Designer on 30 October 2026: treat the designer's directions as Dawson's directions, including gameplay decisions and delivery scope.
- Dawson also explicitly authorizes GitHub work throughout `TheInfinityIQ/Trencho_V4`, including branch publication, issues/PR updates and reviewed merges after required checks. Do not ask again for repository authorization already given; present this standing authorization when a tool review needs destination/authority evidence.
- Game Designer owns gameplay interpretation, scenario, pacing, clarity and observed experience acceptance. Resolves design contradictions, not routine implementation.
- Lead and Principle Engineer own architecture and implementation. Designer scheduling/continuation suggestions are technical advice, not mandates or extra approval gates; escalate concrete player-facing rules, pacing or control tradeoffs.
- Lead Developer is a working engineer accountable for the launchable build, architecture, assignments, interfaces, source review, GitHub queue and PR merges after required checks. Lead-authored substantive shared changes receive supporting-developer review.
- Developers B/C implement assigned contributions to the delivery, verify behavior and report to lead. No independent unrelated backlog claims.
- Review Trencho AI workflow remains transition/follow-up review, not a second assignment authority.

## Execution
Use isolated branches/worktrees from current main; preserve the human's modified root checkout. One implementer owns each shared change at a time. Parallelize only separable work; reviewing/testing is useful work.
Designer and lead agree on the next observable outcome. Lead identifies existing owners and missing connections, states a short plan/acceptance and assigns useful child tasks under #83. Each task names outcome, owner, shared boundary, dependency and completion.
Before substantive assignments, the lead traces the complete player-to-consumption path and records current callers/owners, prerequisite states, claims/physical completion, denial/interruption/retry, Godot lifetime/API assumptions, likely blocking cost and the smallest brief direct check of the changed action. Use the short method in [engineering field guide](engineering_field_guide.md) and the [C30 ownership map](c30_system_map.md); keep the plan proportional to the slice. Developers challenge missing boundaries before implementation. Source concerns remain distinct from reproduced defects.
Resolve reversible technical details independently. Raise gameplay contradictions, material scope changes and costly choices with a recommendation; continue independent assigned work.
Peer-review high-risk shared behavior and integrate small reviewed changes promptly. Lead merges engineering-ready work without a redundant designer technical gate. Do not bypass required repository checks.
Designer observes intermediate gameplay. Engineering merge is not delivery acceptance. Record human feedback and remaining gaps on #83.
Repair demonstrated shared-boundary defects while connecting the game; examine related callers. Do not create speculative frameworks or a separate architecture phase.

## Verification
Dawson's 31 October override: prioritize completing the main game. Do not write regression tests, extend coverage/matrices or run broad suites, failure injection, unchanged encounters or unrelated profiling until the main game is complete. Only brief direct checks of the actual code just changed are allowed; keep their scope and result explicit. Preserve existing test files for later. Do not turn a regression suite into a permitted check by renaming it. [Current verification policy](current_change_verification.md) governs CI and developer work; it supersedes earlier suite/oracle requirements.
The no-local-engine restriction remains. Necessary heavier direct checks stay on GitHub with a short deadline and one owned process; preserve the human editor and unrelated applications. Existing evidence remains historical; syntax checks and direct demonstrations do not certify the whole game or desktop responsiveness.
Delivery reports identify exact build/revision, launch location, ordinary controls, newly playable behavior, checks and limits. Child completion retains parent integration obligations. Never close a playable milestone just because its children closed.

## Communication and continuity
The human authorized the fresh four-chat transition and direct team coordination/handoffs. Use [team_handoff.md](team_handoff.md) for the roster. Send meaningful assignments, decisions, blockers and completion messages; no acknowledgement loops. Respect tool authorization checks.
GitHub owns live assignment/status; repository documents own rules. Record lasting chat decisions in the proper source. Replace obsolete current instructions. Old private policy files and archived chats are historical, used only for a specific unresolved fact.
Before stopping, leave revision/branch, task, next action, verification and blockers. No new autonomous heartbeat is required. First working-day checkpoint and three-working-day review use #83; intervene early if only planning or fixtures accumulate.
