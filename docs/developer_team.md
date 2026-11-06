# Gameplay developer team

Dawson requested three separate persistent Codex chats inside **Trencho v4 experiment**,
all `gpt-6.1-sol` with `medium` reasoning. The earlier temporary helpers are idle.
Read [developer onboarding](developer_onboarding.md) and current AGENTS before work.

| Developer | Chat | Current feature | Isolated checkout |
| --- | --- | --- | --- |
| A — Army Supply | `01a1ae78-5b3a-7993-87ca-7d316595fd7e` | Source/Designer clarification of genuine need versus actionable collection; PR95 remains stable | `trencho_dev_army` |
| B — Operations & Transport | `01a1ae78-6945-7ae0-b03c-f2b5fadb56ad` | Current request selection and truthful truck handling/fuel/crew feedback | `trencho_dev_truck_handoff` |
| C — Player Experience | `01a1ae78-77c2-7822-9322-328161666746` | Mount Getting started guidance and useful destination links | `trencho_dev_guidance_mount` |
| Lead | `01a199a0-f08e-7f23-947f-62655a9ed233` | GitHub cleanup, exact-head review and gameplay integration | `trencho_lead_integration` |

Checkouts are under `C:/Users/dawso/Developer/Projects/Godot/`. Never switch or edit
the shared `trencho_v4` checkout, which was externally returned to main. New feature
work starts from the published6b1dd28 checkpoint plus policy12005e3; approved older
component PR heads remain historical exact-head contracts. Current branches and
reviews are in [team state](team_integration_state.json).

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
`codex/gameplay-demo-integration`. They request lead technical and Game Designer
gameplay review with exact PR/SHA, evidence, limits and usable player steps. Both
role decisions are required at the submitted head; changes require renewed review.
Current shared-account signoffs are COMMENT reviews, not native GitHub APPROVED.
No developer self-merges. Lead integrates; Designer reviews the lead's PR too.

Dawson authorizes direct coordination with lead for delegation/technical review and
Designer for gameplay clarification/design review. UI/UX and Artist retain their
consultant roles. Communicate meaningful progress/handoffs without acknowledgement
loops. Use feature-level Objective / Outcome / Next task briefings. Request the next
bounded task after handoff; no invented feature, nested execution owner, autonomous
heartbeat or always-on service is established by these chats.

## Integrated stage handoff

PRs93–98 are merged into source7fd7ff08f0eb776c1eb7e9f029936fbd462d869e on the review branch. Only PR89 remains open. The bounded combined-source design delta is approved; its brief manual UI demonstration is queued on GitHub, not a runtime pass. Developer A owns the next authoritative collection-readiness explanation, B owns observing that single remote job, and C awaits the next bounded feature. No local engine or regression run is permitted.
