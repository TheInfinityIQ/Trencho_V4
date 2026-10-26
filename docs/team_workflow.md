# Team workflow

This document records how the project team assigns, implements, reviews, and reports work. The Game Design Document, accepted design decisions, and the current GitHub issue remain authoritative for gameplay scope.

## Responsibilities

- **Game Designer:** owns gameplay scope, parent-ticket assignments, design clarifications, issue and milestone status, and final gameplay acceptance. Reviews the exact final pull-request head and alone manages merges into main after required checks and evidence pass.
- **Software Developer:** implements assigned runtime/gameplay work and prepares reviewable pull requests with issue links, scope, actual verification, and remaining limits or deferred integration. For a Designer-assigned parent ticket, may decompose work and delegate bounded, separable subtasks to the two light developers; owns their interfaces, review, integration, and end-to-end acceptance.
- **Light Developer 1** and **Light Developer 2:** complete only a bounded task assigned by the Game Designer or delegated by the Software Developer within its assigned parent ticket. Report subtask completion, revision readiness, a genuine blocker, or a concrete design question to the designated owner and include the Game Designer at meaningful completion/blocker or pull-request events.

The Software Developer keeps ambiguous design choices, physical lifecycle invariants, cross-system integration, and complex review with the lead until evidence supports a bounded handoff. Delegate useful work with clear ownership and inputs/outputs; do not create work merely to distribute a large ticket. Keep at most one active assignment per light developer, avoid overlapping writes, and do not interrupt, duplicate, or reassign Designer-owned work. Suitability depends on separability and reviewable acceptance, not task size alone. The lead adjusts future delegation using independently reviewed outcomes and actual correction/integration burden. No additional developers or model changes are implied.

## Branches, pull requests, and review

1. Before substantive work, state a short plan and observable acceptance criteria. Raise contradictions, missing acceptance criteria, or costly design choices to the Game Designer while continuing independent authorized work.
2. Use a clean isolated branch/worktree based on current accepted main. Keep each change focused on its assigned issue. Do not use the human's modified root checkout or another developer's active worktree for writes.
3. Do not compete for a shared desktop or native application session. Report an actual input/tool blocker to the Game Designer; do not change permissions or repeat an unchanged failed input attempt.
4. Create and attach a reviewable pull request that links the assigned issue and states what changed, what was actually checked, and what remains unverified or deferred. Light-developer contributions may be separate linked PRs or specified commit handoffs. The Software Developer reviews and may integrate reviewed work into its parent branch with provenance, then verifies the combined result. Integration is not final acceptance. Developers do not merge PRs, enable auto-merge, close gameplay issues, alter permissions, or rewrite shared history.
5. The Game Designer reviews the exact final pull-request head and required evidence. A code-review correction or a headless check alone is not final gameplay/native acceptance.

## Direct reporting and handoff

For a delegated subtask, the light developer sends one concise report to the Software Developer and includes the Game Designer at a meaningful completion, blocker, or pull-request event. The Software Developer reports parent-ticket readiness, a genuine blocker, or a design question directly to the Game Designer. Include parent/child issue IDs, pull-request URL and exact head revision when applicable, actual check/CI results, observed evidence, limitations, deferred integration cases, and the specific blocker or decision needed. Never describe unverified behavior as passed.

After reporting, wait for the designated owner; light developers do not self-assign downstream work. After a blocker or design question, continue independent authorized work and await direction on the blocked portion. Do not send acknowledgement-only or repeated unchanged status messages. The Game Designer reviews the final exact head, current required CI, and required behavior evidence and alone manages main merges and issue acceptance. Respect any later human pause or stop immediately.
