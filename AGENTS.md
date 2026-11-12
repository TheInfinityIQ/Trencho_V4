# Working on Trencho V4

## Context

- Godot 4.7.2 standard edition; root `project.godot`; entry scene `game/main/main.tscn`.
- Read `docs/design_brief.md` for accepted design facts, `docs/team_workflow.md` for current ownership, and `docs/playable_delivery.md` for the active outcome. Engineering decisions remain in `docs/foundation.md`.
- The Game Designer directs gameplay scope; the Lead Developer owns engineering assignments, integration and PR merges. Do not infer gameplay requirements from the project name.
- Dawson explicitly delegates all PR approval and merge decisions to the Lead. Obtain the actual Game Designer review where required and satisfy required checks; the Lead decides and executes approval/publication/merge. Do not ask Dawson to approve PR submission, publication or merging, or use him as a substitute reviewer. See `docs/team_workflow.md` for the standing authority and blocked-action routing.
- Use GDScript by default. Propose C#, GDExtension, or plugins when a concrete requirement justifies them.

- Under Dawson's 12 November two-developer authorization, Lead owns logistics/shared state/entry/UI/integration; Battlefield Developer owns agreed battlefield 3D presentation in an isolated branch. See current team workflow; retired developers stay inactive.
- Other sub-agent delegation is limited to on-demand `asset_scout` for accepted art briefs after coherent faceted concepts: fixed `gpt-6-luna`, High for reference searches or Low for exact catalogue lookups. Use `.codex/agents/asset_scout.toml`; when custom-role loading is unavailable, pass its instructions with explicit Luna/effort and `fork_turns="none"`. References are viewing-only; no mesh/texture reuse, licensing research, paid downloads or purchases. No additional standing chat/controller; retired developers stay inactive.

## Implementation

- Group each feature's scenes, scripts, resources, and assets under `game/<feature>/`.
- Use snake_case file/folder names, PascalCase nodes/classes, tab-indented GDScript, and explicit types where useful.
- Prefer small composed scenes, clear ownership, and explicit dependencies. Add autoloads only for genuinely global lifetime.
- Keep changes focused. Avoid speculative frameworks, unused folders, and unrelated refactors.
- For substantive work, state a short plan and acceptance criteria before implementation.
- Resolve reversible implementation details independently. Raise design contradictions, missing acceptance criteria, or costly choices with the Game Designer; continue independent work when possible.
- Measure suspected performance problems with the profiler before optimizing. Avoid per-frame polling when events suffice.

## Verification

Dawson's 31 October instruction takes precedence: until the main game is complete, do not write regression tests or run regression suites, broad scenarios, failure injection or coverage matrices. Only brief direct checks that the code just changed works are allowed. Preserve existing tests for later; do not rename a regression suite as a direct check.
CI parses changed production scripts and can run one brief, explicitly supplied current-change demonstration; it does not run the old suites. See [current verification policy](docs/current_change_verification.md). Compilation is not gameplay acceptance; report the exact direct check and unverified behavior.
Protect desktop resources: no local engine runs under the current restriction. Necessary direct new-code checks run briefly on GitHub; preserve the human editor and unrelated applications.

## Repository care

- Commit `.uid` and `.import` sidecars; do not edit generated `.godot/` contents.
- Keep caches, engine downloads, builds, secrets, and private credentials out of commits.
- Use Git LFS before adding large binary assets; keep text scenes/resources reviewable in Git.
- Keep this file concise. Record lasting decisions with rationale and sources in `docs/`.
- Do not discard unrelated work or rewrite shared history. Describe the behavior, purpose, and validation in pull requests.
