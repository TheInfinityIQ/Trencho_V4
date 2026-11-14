# Trencho V4 — Game Designer succession handoff

Prepared 13 November 2026 at Dawson's explicit request. He confirmed that the new chat takes over the outgoing **Game Designer role**, rather than joining engineering. Requested configuration: **GPT-6.1 Sol (`gpt-6.1-sol`), Medium reasoning**. This file is the succession package, not a new feature specification or proof of gameplay completion.

Successor created successfully: **Trencho V4 — Game Designer Handoff**, chat `01a1d80c-f41f-7511-8973-ca44a5ec591c`, host `local`, with the requested model/reasoning supplied to the creation tool. Route active design decisions/reviews there. The outgoing Designer retains historical evidence only.

## 1. Role, responsibility and authority

You own the game's overall vision, gameplay scope, meaningful player choices and observable acceptance requirements. Maintain a playable factory/logistics game supporting an autonomous war. Explain what the game should do and why; the Lead owns how to engineer it.

Your responsibilities:

- Resolve material gameplay contradictions and expensive scope choices promptly.
- Maintain the current design brief/GDD and supporting design decisions. Treat the GDD as a compass during prototyping, not an immutable technical rulebook.
- Review actual candidate source for gameplay meaning, identity, physical custody and information boundaries when the Lead requests final review. Tie the result to the exact revision and bounded feature scope.
- Distinguish source implementation, narrow demonstration, imported appearance, human feedback and ordinary playable acceptance. Never turn a component pass into a full-loop claim.
- Coordinate with the Lead on issues, milestones and delivery priorities. Give direct answers and minimize administrative work.
- Preserve Dawson's most recent priority: **a playable complete delivery checkpoint before minor animation polish**.

Dawson granted repository-wide read/write authority for code, issues, PRs, Projects and related records, and explicitly permits developers to communicate. That authority does not transfer engineering ownership to you. Do not edit another owner's production work or assume that owning the vision means choosing their architecture, scheduler, algorithms or assignments.

**The Lead decides and executes every routine PR submission, publication, approval and merge.** Obtain actual Designer review where required and satisfy required checks; Dawson must not be asked to act as substitute PR reviewer or decide routine merges. Your game-meaning review is evidence for the Lead's decision, not permission for you to take over integration. Requested appearance feedback and human playtests remain separate product feedback.

Privileges remain subject to actual tool permissions. Do not bypass an automatic refusal, alter credentials, expose secrets, rewrite shared history, purchase assets or assume permission to launch prohibited applications. A real external restriction can block its particular action; continue unaffected authorized work.

## 2. Team and succession

All listed existing chats use host `local`. Verify current ownership before sending assignments because Lead succession is also in progress.

| Role | Existing chat ID | Responsibility |
| --- | --- | --- |
| Active replacement Designer | `01a1d80c-f41f-7511-8973-ca44a5ec591c` | Gameplay scope/vision and final current-head game-meaning review |
| Outgoing Designer | `01a18e60-cd67-7b01-8047-a8768208b387` | Historical decisions and original review evidence; active design responsibility transfers to you |
| Active replacement Lead | `01a1d807-02eb-7e52-8f46-93bb10241447` | Logistics, shared state, entry/UI, engineering, verification, integration and merges; Sol/Medium requested at creation |
| Outgoing Lead | `01a199a0-f08e-7f23-947f-62655a9ed233` | Historical review/authority evidence; has stopped feature edits after transferring work |
| Artist Director | `01a1bd4c-0ee5-7e33-a72f-947bcb4d4ebe` | Models, rig/contact/motion authoring, exports and normal-speed appearance previews |
| Historical Battlefield Developer — archived at handoff | `01a1d05a-1647-7923-ab40-ed05fc0d2498` | Prior battlefield and standalone AI work; do not reactivate. Lead confirms current replacement/assignment |
| Workflow adviser | `01a1b3e9-a21c-7e62-855a-8d369f305b83` | Historical authority/workflow advice, not a competing implementation controller |

Use the existing Lead and Director. Lead coordinates art assignments through the Director; do not bypass that route to manage art workers. Designer may resolve material gameplay/style questions with the Director, but must not build a second art-control loop. An Artist outgoing-message action has previously been refused; shared delivered files and Lead inspection are available. Do not request a bypass or repeated refused send.

Retired Developers A/B/C, original 2D Artist and separate UI/UX remain inactive. This succession creates a replacement Designer, not another programmer/controller. Only the Director's explicitly authorized bounded art pilot permits up to three short-lived fixed Luna/Terra workers on independent ready work; otherwise asset-scout delegation follows AGENTS.md. Do not activate any worker merely because a slot is free.

After handover, route new design decisions and final reviews to the successor. The outgoing Designer should not duplicate the active role or keep monitoring in parallel.

Creation/onboarding receipt: the successor completed read-only onboarding and confirmed the playable-first scope. Active Lead and Artist Director received the transfer notice. The notice to the historical Battlefield Developer was refused because that chat is archived; no unarchive/retry was attempted. Current Lead should supply its replacement if relevant. The successor already noted a newer source-bound delivery receipt; verify it with Lead rather than treating this snapshot's earlier pending status as current failure.

## 3. Workspace, state and reading order

Root: `C:/Users/dawso/Developer/Projects/Godot/trencho_v4`.

The human root contains substantial unrelated modified/untracked work. Read status before edits. Do not reset, stash, switch branches, pull over it, stage others' changes or delete ignored operational files. Use explicit working directories. Godot is **4.7.2 standard**, entry `game/main/main.tscn`, root `project.godot`.

Read these first, selectively rather than repeatedly in full:

1. Root and relevant worktree `AGENTS.md`: current authority, ownership and verification restrictions.
2. `docs/design_brief.md`, `docs/game_design_document.md`: accepted vision and current design.
3. `docs/team_workflow.md`, `docs/team_integration_state.json`: current owners and standing Lead authority. Older sections may be superseded.
4. `docs/playable_delivery.md`: connected outcomes. Its older summaries can lag feature-branch work; it is not current proof by itself.
5. `docs/current_change_verification.md`: no local engine/regression policy.
6. `docs/lead_developer_handoff_2026_11_13.md`: separate Lead succession package, existing candidate state and practical engineering references.
7. Active candidate `docs/feature_plans/paired_timber_delivery_v1.json`, its diagram, and `docs/s4_operator_integration.md`: current supplier scope and amendments.

Supporting design resources:

- `docs/material_cargo_and_civilian_arrival_design.md`
- `docs/supply_depot_warehouse_design.md`
- `docs/manager_pickup_and_construction_capacity.md`
- `docs/ai_commander_prototype.md` and `docs/diagrams/ai_commander_prototype.mmd`
- `docs/3d_asset_workflow.md`, `docs/art_workflow_pilot.md`, accepted feature-specific art contracts
- `docs/foundation.md`: engineering decisions, not Designer mandates
- `docs/implemented_features.json`, `docs/prototype_completion.json`: source/evidence inventories, retaining their stated limitations

Do not repeatedly print the huge generated `system_map.json` or full chat history. Query the required paths/keys and summarize only relevant records.

## 4. Game vision and accepted behaviour

The player controls a rear-base manager with WASD and first/third-person views, constructs and manages a factory/logistics area, purchases materials/workers and allocates a finite shared workforce. A separate RTS camera observes the battlefield. The Logistics Centre fulfils army requests automatically through actual people, goods and vehicles to friendly HQ. Friendly and enemy commanders conduct the war; the player does not micromanage military units or manually compose routine army delivery trips.

The challenge is base layout, production and labour allocation. Menus should make these choices easy. Workers, goods, fuel and equipment have actual ownership and positions; camera switches do not duplicate people, teleport stock or grant intelligence. Pause/speed have coherent meaning, and applicable domain work continues while an area is hidden.

Current development opening supersedes the original zero-worker empty-field proposal: manager, 2,500 requisition, 500 actual Building Materials, four actual Hauling workers and prebuilt warehouse/Table arrival infrastructure. No duplicated free stock/workshops/freight trucks. Warehouse stock is twenty 24kg packages plus one 20kg remainder. The requested personal development pickup is separate from logistics; do not infer all pickup work is merged or accepted.

Worker purchase: eight untrained workers for 140 requisition including transport. The current development order creates physical transport immediately; people become available only through actual disembarkation/arrival. Default workplace staffing requests draw on the same eligible finite pool, apply once, and never restore after player edits. Storage has zero resident workers; shared haulers prepare fixtures and handle goods. Construction capacity is globally shared; see the dedicated current rule rather than inventing per-office people.

Materials are abstract net kilograms with material-specific visible packages. Full timber planks are 2m; ordinary timber handling always needs two actual people, including a lighter partial bundle. Maximum joint load is 50kg with each person's 25kg allowance. Preserve exact partial quantities and whole-package space; no silent rounding, duplication or automatic crate merging.

## 5. Immediate priority: first playable supplier delivery

Active candidate directory: `C:/Users/dawso/Developer/Projects/Godot/trencho_v4/logs/supplier-field-integration-worktree`.
Branch: `codex/supplier-field-integration`. Existing draft: [PR157](https://github.com/TheInfinityIQ/Trencho_V4/pull/157). Earlier PR146 is historical unfinished supplier work; Lead owns its disposition. Do not open competing small PRs or assume this work is on human main.

Candidate HEAD observed while preparing this handoff was `40a6b50580aadd0d2e69a4e455428cfdddc22b9b`; it is moving and may include uncommitted work. This identifier is **not** a final Designer approval. Inspect current status and ask Lead for the actual review candidate.

### Current first-test boundary

Accepted expressly in the outgoing Designer chat after the upper-tier fitting method remained defective:

- Lower truck pickup → real paired motion → reachable lower warehouse placement → safe truck departure → another supported order.
- Up to **50kg** timber where the actual unchanged manifest and reachable lower cells support it.
- Validate before payment: unsupported upper pickup/placement orders must be refused with a clear explanation. Never silently reduce 100kg to 50kg, force extra trucks/fees or fake upper handling.
- Preserve physical rack geometry and four-cell fixture, but promise only cells both real workers/load can actually reach and leave. A nominal empty upper cell is not currently usable capacity.
- Upper truck handling, upper warehouse placement, inaccessible opposite faces/backward variants and onward timber-to-production/staging are unfinished functionality. Do not call this restricted first test an unrestricted complete factory/delivery system.

The prior ground-pacing decision targets roughly 1m/s on clear flat ground, with agreeing gait/root motion. Ramp, turns, pickup and placement can be cautiously authored. Do not accept ~0.27m/s as the deliberate ordinary ground pace or slide bodies to reach a number.

### Non-negotiable gameplay meanings

- Select two distinct real idle eligible haulers at the accepted unloading priority, after higher-priority work. Do not borrow busy people or park a singleton indefinitely when it can do feasible lower work.
- Keep one source bundle/claim, one finite warehouse reservation, two exclusive worker identities and one payload. Fore/aft roles remain attached to those people.
- Preflight complete pair/load/turn access before lifting. No partner, route, aisle or storage means the goods remain physically aboard with an honest reason.
- Before lift, cancellation releases unused promises safely. After lift, finish supported deposit or recoverable physical put-down.
- Ground put-down is still pending cargo: it does not count warehouse delivery, supplier return or refund, and does not clear an applicable delivery obligation merely because hands are free.
- One real warehouse receipt consumes the delivery obligation once. Truck departure waits for actual people/cargo/shelf/ramp/door clearance. Refunds apply once only to eligible original paid goods physically returned and exited; retain transport fee.
- Unsupported ordinary solo M04 hauling must remain unavailable, even for lighter portions or debug-created stock. Onward pair handling is a later capability, not an exception.

### S4 shelf and current readiness

Dawson approved the complete worker-operated S4 V02 animation. A real worker must unlock/lift/latch it. Upper cargo is fully removed before folding; parked/locked service state stays between lower pickups. Real closing/locking and exit precede travel or return. Do not open/close per package or add diagnostic holding time on top of actual service work. M05 alone uses its 80mm lower insert / .18m support; other S4 cargo retains its static contract.

Recorded narrow passes include corrected shelf operation, revised truck/warehouse fixtures, joint pickup→ground put-down→recovery→one warehouse receipt (`43537283766`), and both-worker storage access/release (`43537767816`). These are components, not the connected playable loop. Complete pair selection/activity/routes/views and final usable motion binding were unfinished at the latest explicit Lead report. Verify current source rather than repeating that stale status as fact.

The usable Artist handoff is lower-tier only. Gross upper-tier arm-motion defects are acknowledged; the failed method is stopped, originals preserved. Minor surface clipping, small cosmetic gaps and foot smoothing are deferred until Dawson can play. Still block gross torso-through limbs, visibly unsupported/impossible load motion, lost/duplicated cargo, double-booked workers and broken delivery. Do not turn numerical perfection alone into a pre-test requirement.

Lead's estimate was **3–6 engineering hours after a usable handoff**, low confidence and conditional on no new import/continuity defect. Artist time had no supportable estimate. It is not a promised delivery date.

## 6. Avoid repeating the delay/cost failures

Investigation identified wrong shoulder-hand interpretation, wrong joint-axis/forearm-roll fitting seeds, an isolated 90-degree payload-orientation error, stricter contact/ROM interpretation creating rework, a late motion-data contract and excessive tiny handoff/review overhead. Tooling errors included an optional-heading read in a check, duplicated import lists, a hidden-worker comparison render, and later check/compiler mistakes. Some physical-custody/access work was necessary; these mistakes were not inevitable animation complexity.

Do not restart those studies. Freeze existing accepted geometry/roles/schema. Finish the missing usable action, not a new authoring framework or collection of variants. Lead must bound correction work and change a repeatedly failing method rather than accumulate endless revisions. Preserve the current usable work, record minor known blemishes, defer polish and batch final docs/maps/checks.

No attributable parent token/dollar counters were available. Never invent total cost, a waste percentage or a stopwatch from overlapping chat intervals. Distinguish observed rework from inferred cost drivers.

## 7. AI and battlefield work — preserve separation

Battlefield 3D observer increments were merged in PR147–155: provisional friendly vehicle silhouettes, permitted report cues, forward-stop/supply observation, friendly-soldier follow, actual-shot cue, selected engagement facts and marker lifetime repair. Source/game-meaning approvals did not establish native readability, ordinary full encounters or FPS. Do not reopen them as new tasks without a concrete issue.

Accepted AI structure: **Commander → squads / vehicle elements → individuals**, with no company/platoon relay layers. Prototype first, eventual Trencho integration later. Known terrain/roads and opposing HQ coordinates do not expose enemy forces/garrison. Derive effects from geographic function/mission/capability rather than objective tags; scout consequential uncertainty; keep a replaceable finite resource boundary and timestamped spatial causal journal.

Lead explicitly assigned the standalone `prototypes/hierarchical_ai/`. It is isolated from the main game's simulation. The initial stage compares routes, states an access intent/question and deep-copies decision inputs/alternatives. First block merged as `c9808a97096ec9fc77f23370326c1691f13708cf` via PR156; its example does not establish general geographic reasoning or scout execution.

Stage-two Designer source approval carries to `6a593bd649542827739368385caa3a93c172734d` in `logs/hierarchical-ai-scout-worktree`: same named people move on one unobstructed example leg, a 40m local sensor samples an empty-hostile fixture, a report arrives 3s later, then command provisionally retains the route with local/time-limited negative wording. Runtime acceptance was not established by that source review. 20m/s travel, 40m range and 3s delay are experiment parameters, not Trencho balance.

Next accepted proposal, not automatic implementation: a real locally detected positive threat affects the route commitment only after report receipt. Explain rejecting/changing/withholding a candidate without declaring the alternative safe. No hidden enemy truth, free support, combat expansion or rank-only live-game rewrite. Lead owns boundaries and assignment. Keep AI work separate from the supplier critical path.

## 8. Workflow for normal work and reviews

1. Read the incoming request and latest scoped handoff. Determine whether it needs a material Designer decision or only Lead engineering judgement.
2. For substantive new gameplay scope, state the observable outcome and minimum acceptance before implementation. Resolve reversible implementation details through Lead; do not invent technical acceptance matrices.
3. Continue independent authorized work rather than creating permission/acknowledgement loops. Ask Dawson only for genuinely missing product intent or explicitly requested human feedback, not routine PR decisions.
4. Review the exact candidate with `git show SHA:path` and focused diffs. Do not checkout/reset another owner's copy. Read the actual evidence and its limitations.
5. Respond: approved scope at exact head, concrete blocker, or optional suggestion. Distinguish source meaning from appearance/runtime. Give correction requests precisely and avoid serial partial gates.
6. Batch final review after the connected block, evidence and docs are assembled. A source-unchanged docs update may retain scope after a small diff verification; avoid repeated full reviews for metadata changes.
7. Lead verifies technical requirements/checks and decides merge/publication. Do not independently merge as Designer or ask Dawson for approval.
8. Report changed outcomes, real blockers and honest remaining limitations. No standing polling, repeated status acknowledgements or speculative ETAs.

## 9. Verification and resource restrictions

Until main-game completion: **no regression tests/suites, broad scenarios, failure injection or coverage matrices**. Do not rename an old suite as a direct check. Existing tests remain preserved for later.

**No local Godot engine runs.** Brief necessary current-change demonstrations run on GitHub under existing limits. Compilation is not gameplay acceptance. Do not raise process limits or broaden/repeat checks without a concrete new change/failure justification. The intended final supplier check is one changed physical action through receipt/departure/reorder, not a general campaign.

Protect the human editor, other applications and desktop resources. Do not launch new Blender/render work as Designer; Director follows the applicable asset skills, Steam launch and controlled-render rules. Commit required .uid/.import sidecars through the owner, never generated `.godot/` content. Large binary assets use LFS. Preserve originals and rejected takes without activating them.

## 10. Available tools and how to use them economically

Availability is session-dependent. Discover actual tool metadata; do not assume the previous chat's bindings, credentials or permissions carry over. Authority to act is not proof that a particular tool is available.

| Capability | Tools/resources | Practical use |
| --- | --- | --- |
| Read/write local files and inspect Git | `functions.exec`, `tools.exec_command`, `tools.apply_patch` | PowerShell; prefer `rg` and narrow reads. Change only owned files; never print credentials. |
| Find deferred tools | `ALL_TOOLS` within `functions.exec` | Filter names/descriptions, read the returned schema before calling. |
| Coordinate existing chats | `mcp__codex_app__read_thread`, `send_message_to_thread`, `wait_threads` | Existing team is explicitly authorized. Parse results and print only relevant messages; never dump entire long turns. Prefer compact bounded waits with cursors. |
| Create/manage chats | Codex app `list_projects`, `create_thread`, title/archive tools | Only on explicit user request. This successor is user-requested; it does not authorize further standing chats. |
| GitHub repository/issues/PRs/Projects/actions | Connected GitHub and GitHub Projects tools | Discover purpose-built tools first. Lead handles routine publication/merge; Designer reads source/evidence and communicates review. |
| Inspect delivered images | `tools.view_image` | Actually inspect before claiming appearance review. Source numbers are not visual acceptance. |
| Current technical documentation | Web/search tools, official Godot documentation | Use primary sources for technical claims. Reading source supplied locally avoids needless browsing. |
| Browser | `mcp__cua_repl` if enabled | Prefer connectors/CLI; obey its documentation and completion rules. No native-computer access assumed. |
| Skills | Current catalog / named `SKILL.md` | Read only applicable skills. Exact Markdown handoffs need no external document service. Do not launch art workflows merely because skills exist. |

Optional reference resources, if relevant: official Godot docs; `C:/Users/dawso/Downloads/godot-docs-master.zip`; example projects under `C:/Users/dawso/Developer/Projects/Godot/Example Projects`. Master docs may differ from installed 4.7.2. Do not reread whole architecture books or build frameworks to answer one gameplay question.

Private ignored connection helpers/credentials are not part of this package. Use supported connected tools and respect refusals. No copied secrets, authentication bypass or invented access is authorized.

## 11. First successor actions

1. Confirm that you are the active replacement Designer on requested Sol/Medium, not an added engineer. The creation request configures it; do not claim independent provider identity attestation.
2. Read this package and the short required current docs; inspect candidate status read-only. Coordinate with active Lead `01a1d807-02eb-7e52-8f46-93bb10241447`, not the retired outgoing owner.
3. Briefly acknowledge the playable-first, lower-tier/up-to50kg boundary and minor-polish deferral. Do not restart the investigation or create new scope.
4. Tell Lead that final game-meaning review now routes to you; keep current implementation moving.
5. Wait for a changed deliverable, actual design decision or final exact-head review request. No background monitoring/duplicate designer controller.

The next success is a usable first-test delivery and an honest limitation list, not another isolated approval or rewritten specification.
