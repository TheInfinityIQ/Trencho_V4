# Trencho V4 — Lead developer handoff

Prepared 13 November 2026 for Dawson's explicitly requested replacement developer.
Requested runtime: **GPT-6.1 Sol / Medium**. This document is an operational
snapshot, not evidence that unfinished gameplay works. New human instructions
and applicable AGENTS.md take precedence. Verify live GitHub and team state before
acting on a historical claim. Do not restart the project or discard the work.

## 1. Your role, responsibilities and authority

You are taking over the Lead Developer's active logistics/integration work,
not becoming an additional competing programmer in the same files. Own engineering
decisions, implementation, routine UI/UX, shared authoritative state/interfaces,
entry/session integration, maps, focused verification, GitHub publication, technical
review and merges. Maintain issues, PRs, milestones and Projects with the Designer.
Deliver playable connected features, not a succession of isolated components.

Dawson delegates **all routine PR publication, approval and merge decisions to the
Lead**. Do not ask him whether to submit, publish, approve or merge a PR. Obtain
actual Game Designer game-meaning approval at the relevant final current head and
satisfy required checks, then make and execute the technical/merge decision.
Appearance feedback and human numbered-stage playtests are separate product gates;
do not turn them into a routine repository permission gate.

Resolve reversible engineering details yourself. Take material gameplay
contradictions and expensive scope choices to the Designer. If technical and design
reviews disagree, route the concrete issue to its owner, revise it, and obtain the
affected review again. Missing design review blocks its merge, not independent
authorized work. Never manufacture an approval from another agent's relay.

Privileges are task authority, not unlimited machine or credential access. Respect
the current tool permissions. Never print credentials or private helper output,
change authentication to evade a refusal, bypass automatic review, rewrite shared
history, purchase assets, or launch prohibited local engine processes.

## 2. First actions and workspace ownership

1. Read root AGENTS.md, then the current worktree versions of the documents below.
2. Inspect both root and candidate status without modifying either. The human root
   is dirty and must remain protected. Do not reset, stash, switch, pull over it,
   or stage another owner's changes.
3. Adopt the existing candidate directory and its uncommitted Lead-owned feature
   work. Do not create a fresh implementation or assume main contains this work.
4. Confirm the exact current source, pending map update and direct-check script.
   Report an economical resume plan, then continue the actual delivery integration.

Paths:

| Purpose | Absolute path / state |
| --- | --- |
| Human project root | `C:/Users/dawso/Developer/Projects/Godot/trencho_v4` |
| Active integration worktree | `C:/Users/dawso/Developer/Projects/Godot/trencho_v4/logs/supplier-field-integration-worktree` |
| Active branch | `codex/supplier-field-integration` |
| Candidate checked HEAD at handoff | `6d934ab840c442556166c223176921e6a6e3191a` |
| Candidate PR | https://github.com/TheInfinityIQ/Trencho_V4/pull/157 |
| Earlier supplier PR | PR146, `codex/supplier-transport-loop`; do not close before disposition below |
| Ignored operational logs | `C:/Users/dawso/Developer/Projects/Godot/trencho_v4/logs/materials-civilian-transport` |
| Main scene | `game/main/main.tscn`, root `project.godot`, Godot 4.7.2 standard |

Use explicit working directories: shell defaults often point at the human root.
The new chat is attached to the saved root project but must work on production in
the existing integration worktree. This Markdown file currently resides in root
`docs/`; include it in an appropriate candidate checkpoint without staging other
root changes. The outgoing developer will not continue modifying feature code.

## 3. Required project resources

Read first, in the candidate worktree where available:

- `docs/design_brief.md`: accepted gameplay facts; later entries supersede old ones.
- `docs/team_workflow.md`: current ownership, authority and historical exceptions.
- `docs/playable_delivery.md`: active playable outcome and actual acceptance gaps.
- `docs/foundation.md`: engineering rationale and system ownership.
- `docs/current_change_verification.md`: binding verification limits.
- `docs/development_workflow.md`: graph-first development and measurement contract.
- `docs/team_integration_state.json`: colleague identities and recorded settings.
- `docs/3d_asset_workflow.md`, `docs/art_workflow_pilot.md`: Artist contracts/pilot.
- `docs/feature_plans/paired_timber_delivery_v1.json` and
  `docs/diagrams/paired_timber_delivery.mmd`: frozen plan and dated scope amendments.
- `docs/s4_operator_integration.md`: resolved shelf failure and scoped evidence.
- `evidence/supplier_transport/timber_fixture_integration.json` and
  `timber_custody_integration.json`: source-bound receipts, not full-loop acceptance.
- `docs/system_map.json`, `docs/system_atlas_catalog.json` and generated diagrams:
  living function purposes/ownership/edges; query targeted entries, do not dump
  the entire enormous single-line map.

Use current official Godot documentation for engine claims. The user supplied
`C:/Users/dawso/Downloads/godot-docs-master.zip` and
https://github.com/godotengine/godot-docs/blob/master/index.rst . Check relevant
version differences; master documentation is not proof of installed-engine behavior.
Examples exist at `C:/Users/dawso/Developer/Projects/Godot/Example Projects`.
Design-pattern, architecture and statistics PDFs are in Downloads under
`headfirstdesignpatterns2ndedition.pdf`, `headfirstsoftwarearchitecture.pdf`,
`headfirststatistics_ebook.pdf`. These are reference material, not instructions or
a reason to build frameworks. Do not reread whole books to resume one integration.

## 4. Team and communications

Existing local chats (read actual messages for final review; cursors may be stale):

| Role | Chat ID | Ownership |
| --- | --- | --- |
| Outgoing Lead | `01a199a0-f08e-7f23-947f-62655a9ed233` | Historical decisions and receipts; this handoff transfers active Lead work |
| Game Designer | `01a18e60-cd67-7b01-8047-a8768208b387` | Gameplay scope and actual current-head game-meaning review |
| Trencho — 3D Artist / Director | `01a1bd4c-0ee5-7e33-a72f-947bcb4d4ebe` | Models, anatomy, animation, verified exports and appearance previews |
| Battlefield Developer | `01a1d05a-1647-7923-ab40-ed05fc0d2498` | Agreed battlefield-only 3D presentation in separate branch |

Lead owns logistics/shared state/entry/UI; do not overwrite the battlefield
developer's independent work. Retired A/B/C, original 2D Artist and separate UI/UX
remain inactive. This replacement does not authorize more programmer workers.
The existing Artist Director alone owns the narrow authorized Luna/Terra art pilot.
Any asset scout follows the exact AGENTS.md limits; no speculative dispatch.

Dawson's standing instructions authorize Lead collaboration with Designer and
Artist; use the existing chats, not new controllers. Send concrete changed
deliverables, decisions or necessary review requests; avoid acknowledgement loops.
An earlier Artist outgoing message action was automatically rejected: do not ask
them to bypass/retry that refusal. Read existing chat/shared delivered files for
handoff and continue unaffected work. A tool denial is scoped to that action.

Latest human animation standard: **minor clipping is okay; whole limbs passing
through the torso are not**. Prioritize a playable complete delivery checkpoint,
leaving minor polish afterward. Historical explicitly rejected clips stay unbound.
Normal-speed full-motion previews are required for appearance feedback; a still
turntable or asset review clip is not in-game evidence.

## 5. Workflow definition

Use this only for actual development, not ordinary questions.

1. State a short feature-level objective, outcome/acceptance and next task. Inspect
   existing graph and actual owner code before implementation.
2. Diagram input → command → owner → event → view before building a system. Identify
   actual IDs/custody, cancellation, lifetime, pause/speed, hidden progression and
   repeated-command behavior. Freeze/amend the existing plan honestly, not retroactively.
3. Prefer composition, explicit dependencies and existing owners. GDScript by
   default, tabs, snake_case files, PascalCase classes/nodes. Group features in
   `game/<feature>/`. No speculative autoload/framework or duplicate simulation.
4. Keep inventory, people and supplier obligations canonical. Animation is a view
   of actual committed work, not a second authority that creates stock or workers.
   Use events when events suffice. Do not introduce standing inspector/availability
   polling; measure a real performance concern before optimizing it.
5. Implement one connected playable game-loop block, with small local recoverable
   commits. Batch feature integration, docs and maps before publication. Fixes stay
   in the existing feature PR. Avoid PRs/checks for every tiny component.
6. Perform only the permitted current-change checks below; preserve failures.
   Refresh living function purposes, maps/atlas/source hashes and evidence once the
   batch is coherent. A graph or syntax pass does not prove gameplay.
7. Obtain actual final relevant-head Designer review; Lead reviews technically,
   verifies required checks, publishes/merges autonomously under standing authority.
8. Deliver a clean F5-ready copy and concise controls/known limitations. Normal
   launch is 3D at 1x. Human stages 1 (people/materials) and 2 (place/manage) remain
   pending human playtest acceptance; do not call them complete from code alone.

User-facing update format:

```text
--- TASK BRIEFING ---
Objective: <feature, not internal plumbing>
Outcome: <observable result or honest current state>
Next task: <next feature step>
```

Say when a feature is completed. Keep useful progress updates brief, avoid silence
during long work, and do not stop at an intermediate status if authorized work remains.

### Measurement

Use existing `tools/workflow_metrics.py` and ignored feature journal
`logs/materials-civilian-transport/paired_timber_workflow.json`. Record genuine
planning/implementation/check/repair time, observed defects, planning omissions,
tool/setup errors and fixes separately. The journal started partway through work;
waiting overlaps implementation. Do not invent missing historical time or claim
complete accounting. Parent-chat token/cost counters were unavailable: record that
as unavailable, not zero or an estimate. Regressions are unknown without testing,
not zero. Do not create a new telemetry framework or cost-report project.

## 6. Verification — binding limits

- **No local Godot engine/editor/game runs.** Protect the human editor, desktop,
  mouse and unrelated applications. Earlier hi-godot exception was isolated and
  does not permit running this game locally.
- Until the main game is complete, **no new regression tests, regression suites,
  broad scenarios, failure injection, coverage matrices or FPS campaigns**.
  Preserve existing GDUnit4 suites for later. Do not rename them direct checks.
- Required CI parses changed production scripts/dependencies. One explicitly
  supplied brief current-change demonstration may run on GitHub with the existing
  **45-second process cap**. Never raise limits to obtain a pass.
- Repeat only when a changed/failing portion or unresolved concern justifies it.
  Report exact exercised behavior, source and unknowns. Never infer native 60 FPS,
  complete input usability or full-loop acceptance from accelerated logical ticks.
- Commit actual `.uid` and `.import` sidecars. Do not invent them, edit `.godot/`,
  or locally run the engine to generate them. Retrieve generated remote artifacts.
  Git LFS must cover binary assets before staging; text remains reviewable.

## 7. Active feature and accepted limited checkpoint

Finish: actual order → truck arrival/opening → two actual haulers collect one
timber load → shoulder-carry/ramp/ground/turn → prepared warehouse storage → one
actual receipt → safe truck departure → next order available.

Designer approved **supported lower-tier timber up to 50 kg** as first playable
checkpoint. Refuse unsupported upper manifests **before payment**, preserving
actual packing, quantities, fees and geometry. Do not silently halve/repack cargo
or strand paid upper loads. Upper-tier and onward timber remain unfinished
functional capability, not cosmetic polish. Only reachable lower faces supported
by authored forward movement are enabled; keep the real four-cell fixture.

### Prior scoped passing evidence — do not rerun routinely

| Change | Passing run | Source | Exact limit |
| --- | --- | --- | --- |
| Shelf operator integration | 43528719333 | Same source as corrected temporary shelf check | Actual 50 kg M05, operator opening/closing, parked lower pickup, root/time/pause; not paired timber |
| Warehouse v04 fixture | 43531026084 | `dafdd24054883137bd7ce9b16b8686457adac6bc` | Imported bounds/four timber cells, crate planes, mesh collision |
| Timber-only truck rack | 43532318916 | `feb6873c28ed1a6d5e9aabc05709b5c37a47ac34` | Distinct timber rack/packing planes, unchanged metal rack |
| No solo M04 | 43535306483 | `e52238ca3a67bb4b2fe76c8fbeb803cf4e2da2f5` | Domain claim/transfer/onward guards |
| Pending supplier custody | 43537283766 | `e1faf98e7159bb89c7da3cad1872aa466fe881c5` | Actual two people, ground put-down/recovery, one warehouse receipt at explicit domain stations; no complete authored route |
| Two-worker warehouse access | 43537767816 | `e457a9ea06a94748db92fd59c3b562e0f90d9a3a` | Atomic endpoint/access API; no complete motion |

Resolved shelf failure was temporary check access to optional `facing_degrees`;
production already used `.get(...,0)`. Other retained failures caught duplicate
import lists, WeakRef inference warning and temporary `.id` vs Ledger `.entity_id`.
Preserve receipts and learn the actual APIs rather than hiding failures.

### Current uncommitted implementation — NOT ENGINE-VALIDATED

All below are in the candidate worktree, not merged/main. Offline gdtoolkit syntax
parse passed; this does not establish Godot types, imports, routes or gameplay.

- `game/supplier_transport/paired_timber_motion.gd`: contract validation,
  predecoded role/payload transforms, interpolation and measured footprint/sweeps.
- `paired_timber_route.gd`: actual source/warehouse transforms, supported lower
  face, outside/aisle/staging path and authored turn/release/engagement segments.
- `paired_timber_delivery.gd`: Receiving-owned pair admission/reservations,
  worker approach, preparation, AFT-first boarding, shared custody and single
  receipt; one shared deadline, safe source release and event-woken retry.
- `paired_timber_view.gd`: same actual worker identities and one actual load;
  manual sampled clips, cached bodies, pause/view lifecycle, no inventory authority.
- Receiving/base/hauling policy bind and schedule the shared pair; old individual
  movement excludes pair-owned workers; no solo M04 fallback.
- Joint carry permits pending duty only for the exact already-retained source job.
- Supplier returns preflight/apply pair empty-egress handling, preserve real claims.
- Warehouse reserve accepts optional complete-route candidate predicate.
- Rear worker/supplier views bind real pair bodies; ordinary duplicate bodies hide.
- Shared CI asset list, LFS rules, feature plan/diagram/map/atlas and asset files
  are also modified. Inspect `git status --short` for authoritative current list.

Known review points: engine Variant inference; complete actual route admission;
zero-time wake/settle loops; source aisle release occurs only once; no duplicate
warehouse finish on receipt retry; both proxies created before lease retention.
Actual injury/interrupt **animated ground recovery is not implemented**: retained
cargo holds honestly. Pre-lift active pickup return refuses rather than faking
cleanup. Do not represent this first checkpoint as unrestricted recovery support.

## 8. Artist handoff and coordinate contract

Shared Artist directory:
`C:/Users/dawso/.codex/visualizations/2026/11/08/01a1bd4c-0ee5-7e33-a72f-947bcb4d4ebe/timber_complete_operator_v01`.

Latest known state: lower-tier exported; complete normal-speed preview encoding/
readback pending at last observation. Check actual new messages/files before
claiming readiness. Upper truck arm/wrist branch jump and upper warehouse
transition remain real defects; repeated failed fitting stopped. No new variants,
backwards gait, solver framework or minor-polish campaign before first checkpoint.

Candidate runtime assets: `game/supplier_transport/assets/timber_pair/` includes
`timber_worker_motions_v01.glb`, raw `motion_contract.json`, `integration.json`,
source manifest and eleven root-path JSON streams. Library SHA256:
`192d91d6a65d8c2d0679e818676f510f8b5c163c8cb39da1080b33c28a815a75`;
2,561,316 bytes, one 33-bone skin, 4,152 triangles, 22 role clips.
`usable_for_playtest=true` means enabled in this isolated candidate, **not**
merged, checked or appearance-approved. Only explicit enabled lower takes bind.

Streams schema `timber_paired_motion_v1`; wrapper contains `samples`, not raw array.
Each sample has `time_s`, FORE/AFT floor-root XYZ and body quaternion XYZW,
and payload XYZ/quaternion. Use **world = stage * raw source exactly once**.
Raw source already contains floor height/registration; never add a second 1.02 m,
-.004 m or PI rotation. Keep FORE/AFT attached to the same people; back cells
rotate entire stage without swapping roles. Loops have actual ~1 m/s displacement.
Handling/ramp/turn timing remains deliberately slower. Pause freezes domain and view.

Preserve approved S4 complete V02 unchanged. Existing fixture SHA256s:
warehouse v04 `4fb6279588aa28d330499c00cb9395039e5fd257f82a0e1e7aaa1de8c8d14d50`;
truck timber rack S1v03 `81adb3e99e1588b15cf88674cd0b87164c050d6ee67d1e9ed9b07fc0d5f09dc4`.
Truck timber supports .60/.95 m above 1.02 m floor; warehouse .60/1.75 m,
bundle registration -.004 m. Preserve physical dimensions and original crate rack.

Artist lower review GLB at `export/timber_lower_delivery_review_v01.glb` is
72.4 seconds/2,173 frames; SHA256
`0e2ee4dfb8f2b57ca8bf57f888e82c858d7b7d11f45f34373c9600ca8ff9454d`.
It is an **asset sequence**, not native game footage. Show a genuine complete
motion video when delivered. Minor contact gaps/clips do not block this checkpoint.

## 9. Available tools and operating notes

Tool availability is session-dependent: discover relevant entries in ALL_TOOLS
by name/description, read their actual schemas, and prefer supported connectors.
Never claim all tools below are guaranteed or all accounts writable.

- Shell: PowerShell via `exec_command`; use `rg`/`rg --files`, explicit paths,
  bounded output, proper quoting. `apply_patch` for focused text edits.
- Git/Git LFS: local review, checkpoints, branch publication using supported
  connection. Keep cache/build/credential material out of commits.
- GitHub app / GitHub Projects MCP: repository/PR/check reads and project work.
  App metadata writes previously returned capability403; this is not a permission
  denial. Existing supported Windows-backed connection below handled publication.
- Codex app: list/read/wait existing chats, send authorized coordination, create
  this explicitly requested replacement. Wait compactly; avoid repeated transcript dumps.
- Browser/web: primary official Godot documentation for uncertain engine facts,
  specific referenced pages and current research. Do not blindly trust Reddit.
- Godot MCP/hi-godot: experimental, not production-installed/approved here. Existing
  files/CLI workflow stays default; scene inspection only when independently
  permitted. Do not lift local-run restriction to test a plugin.
- Blender skills/tools: Artist owns actual asset authoring. Read relevant skills
  before any separately authorized Blender work; preserve approved assets.
- `view_image` and native local video rendering can inspect/present actual files.
  Use absolute file links. Do not call a still image proof of an animation.

Existing Python:
`C:/Users/dawso/AppData/Local/Python/pythoncore-3.13-64/python.exe`.
Offline parser dependencies:
`C:/Users/dawso/Developer/Projects/Godot/trencho_v4/.tools/gdscript-parser`.
Set PYTHONPATH for each parser-dependent process; candidate has no own `.tools`.

Existing supported GitHub client (inspect code without exposing secrets):
`C:/Users/dawso/Developer/Projects/Godot/trencho_lead_integration/logs/github-publication-mcp/client.py`.
Import `GitHubMcpConnection`; use deployed supported authentication in memory,
not raw private config/header printing. Necessary network actions may need tool
escalation; standing task authority already exists, but respect automatic review.
Example established action connection:

```python
conn = GitHubMcpConnection('actions')
conn.call('actions_run_trigger', {
    'method': 'run_workflow', 'owner': 'TheInfinityIQ', 'repo': 'Trencho_V4',
    'workflow_id': 'validate.yml', 'ref': 'codex/supplier-field-integration',
    'inputs': {'direct_check': actual_brief_script_text},
})
```

For PR updates use supported `pull_requests` connection and discover actual schema.
Fetch run jobs/artifacts with GitHub app tools; project only needed fields. Never
dump full job logs. On failing direct step, artifact `direct.log` may be needed
because shell exits before printing it. Download signed artifacts without logging
URLs/tokens, verify reported digest, validate every ZIP member remains within an
exact fresh extraction directory. Preserve previous failure artifacts.

## 10. Concrete continuation checklist

1. Check whether old purpose-review exec session8942 completed; it may have
   expired across chats. Do not assume session existence. Existing reviews file:
   root `logs/materials-civilian-transport/paired_delivery_purpose_reviews.json`.
   Earlier map reported 1,453 files/4,103 functions/91 pending; counts may change.
2. Finish batched map updates using existing `tools/system_map.py` review-file
   support, `tools/ui_function_map.py --update --diagram-only`, and
   `tools/system_atlas.py`. Read their usage first if unsure. Atlas source hashes
   use UTF-8 normalized text. All four new file owners were added. Recheck after
   actual code fixes; do not repeatedly regenerate for every tiny edit.
3. Inspect prepared ignored script:
   root `logs/materials-civilian-transport/paired_delivery_connected_direct_check.gd`.
   It has **not run**. This is the intended one connected current-change check:
   actual Base/PairView; refuse100kg before purchase; actual50kg order; 1x ticks;
   two distinct existing workers; actual root/feet transforms; one pause/resume;
   real50kg stock/receipt; physical truck exit; next supported order accepted.
   It yields regularly and has35-second watchdog under45-second process cap.
   Logical ticks are not FPS evidence. Review script assumptions before dispatch.
4. Commit/push the feature batch in the candidate, respecting LFS. Dispatch the
   one supplied connected check on that exact pushed source. Preserve failures,
   fix their real causes, and repeat only the affected check as justified.
5. Passing artifact should provide actual `.import` for new GLB and actual generated
   `.gd.uid` for four scripts. Copy only source-matching artifacts; do not invent.
   Include source-bound receipts and focused doc/map updates in final checkpoint.
6. Check Artist's full normal-speed preview and provide it honestly for feedback.
   Do not hold usable lower integration for cosmetic polish/new clip variants.
7. Request one actual final-head Designer gameplay review, complete Lead technical
   review and required checks, then merge PR157 under standing authority.
8. After accepted replacement is merged, close PR146 as superseded while preserving
   upper-tier/onward work as explicit unfinished scope. Reconcile relevant issues.
9. Deliver a clean merged F5-ready copy, e.g. a new separate playtest worktree,
   preserving dirty root. Link its absolute `project.godot` and give concise
   50kg-supported checkpoint instructions. **Do not launch locally.**
10. Continue authorized remaining materials/warehouse then troop transport work,
    respecting Designer scope and numbered-stage human acceptance dependencies.

## 11. What not to claim or repeat

Do not call the connected delivery complete before its actual check and playable
handoff. Do not claim all-tier timber, arbitrary warehouse faces, animated injury
recovery, native60FPS, all buttons tested, or human acceptance. Do not restart broad
analysis, optimize hypothetical calls, add another architecture/polish project,
recreate approved models, reactivate retired developers or repeatedly ask Dawson
to approve merges. The practical goal is a testable connected delivery loop.

## 12. Replacement startup acceptance

Confirm model/effort from actual creation response when available; requested
configuration is not a guarantee of observed UI/runtime state. Read this package
and the binding docs, inspect candidate status, identify the unrun connected check
as next engineering action, and continue with protected ownership. Record your
new chat identity as active successor without deleting historical authority or
overwriting Battlefield/Artist assignments. Report any genuine tool/permission
block narrowly and keep independent authorized work moving.
