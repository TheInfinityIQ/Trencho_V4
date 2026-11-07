# Gameplay developer team

Dawson requested three separate persistent Codex chats inside **Trencho v4 experiment**,
all `gpt-6.1-sol` with `medium` reasoning. The earlier temporary helpers are idle.
Read [developer onboarding](developer_onboarding.md) and current AGENTS before work.

| Developer | Chat | Stable responsibility |
| --- | --- | --- |
| A — Army Supply | `01a1ae78-5b3a-7993-87ca-7d316595fd7e` | Army supply, receipt reconciliation and assigned integration/review |
| B — Operations & Transport | `01a1ae78-6945-7ae0-b03c-f2b5fadb56ad` | Physical dispatch/transport and assigned integration/review |
| C — Player Experience | `01a1ae78-77c2-7822-9322-328161666746` | Player actions, guidance and production/worker interaction safeguards |
| Lead | `01a199a0-f08e-7f23-947f-62655a9ed233` | Task dispatch, engineering review, integration and publication coordination |

Current tasks, exact branches, checkouts and next-action owners are recorded only
in [team state](team_integration_state.json), under the individual developer
records and lead next action. This roster describes stable roles; it must not
duplicate live assignments that can become stale after the next handoff.

Checkouts are under `C:/Users/dawso/Developer/Projects/Godot/`. Never switch or edit
the shared `trencho_v4` checkout, which was externally returned to main. New feature
work starts from the exact base in its current lead assignment (6 November:
integrationadfa557 unless explicitly stated otherwise). Approved older component
PR heads remain historical exact-head contracts. Current branches, local preparation,
scoped publication waits and reviews are in [team state](team_integration_state.json).

Before editing, agree a bounded outcome, affected files, ownership and observable
acceptance with the lead. Save a prospective diagram and command/event/cancellation
contract. Consult official Godot documentation throughout substantive engine work;
use retained supplied excerpts where present and the official manual for the rest.
Research claims require primary evidence; ChatGPT/Claude advice is not verification.

Use authoritative owners, narrow facts and real events; preserve identity, physical
custody, claims, safe cancellation and actual demand. Hidden views defer reads.
Record and apply [engineering lessons](engineering_lessons.json). Update affected
living maps/diagrams without creating a new test-infrastructure phase.

Current replacement AGENTS governs: until the main game is complete, no regression
writing/runs, broad scenarios, failure injection or coverage matrices. No local
engine. Only changed-production parsing and, if necessary, one brief explicitly
supplied GitHub demonstration of newly changed behavior. Preserve old tests and
known failures for later; do not relabel a suite or weaken acceptance. The former
900-second truck checker proposal is revoked.

Each developer implements, publishes their branch and creates a draft PR against
the lead-specified current target, default `main` after PR89 adoption. They request lead technical and Game Designer
gameplay review with exact PR/SHA, evidence, limits and usable player steps. Both
role decisions are required at the submitted head; changes require renewed review.
Current shared-account signoffs are COMMENT reviews, not native GitHub APPROVED.
No developer self-merges. Lead integrates; Designer reviews the lead's PR too.

Dawson authorizes direct coordination with lead for delegation/technical review and
Designer for gameplay clarification/design review. UI/UX and Artist retain their
consultant roles. Communicate meaningful progress/handoffs without acknowledgement
loops. Use feature-level Objective / Outcome / Next task briefings. Request the next
bounded task after handoff; the lead must dispatch its next owner under the
completion protocol in team_workflow.md, rather than wait for a generic human
continue. No invented feature, nested execution owner, autonomous
heartbeat or always-on service is established by these chats.

## Historical integrated stage handoffs

The entries below retain 5 November checkpoints, not current assignments. As of
the 6 November continuity repair, PR89 and draft PR100 are open; the new combined
candidate is LOCAL preparation, with its own exact-head review still required.


PRs93–98 are merged into source7fd7ff08f0eb776c1eb7e9f029936fbd462d869e on the review branch. Only PR89 remains open. The bounded combined-source design delta is approved; its brief manual UI demonstration is queued on GitHub, not a runtime pass. Developer A owns the next authoritative collection-readiness explanation, B owns observing that single remote job, and C awaits the next bounded feature. No local engine or regression run is permitted.

PR99 is also integrated after exact-head technical5795065501 and Designer5795066498 approval. It records the last authoritative supply-pickup check, preserving actual gate order and physical rules. Operations’ bounded observation of the old combined UI run ended with no runner/jobs/artifacts; no watcher remains. Component99 direct evidence is separate and does not establish the ordinary supply loop.


Dawson's 6 November standing PR rule is in [review and merge decisions](team_workflow.md#pr-review-and-merge-decisions): submit, request both reviews, correct concrete findings, then lead merges the current approved head after required checks. No routine per-merge human permission is added. Exact-head rejection/pending/change/failure routes have named owners; independent ready work continues.
