# Working on Trencho V4

## Context

- Godot 4.7.2 standard edition; root `project.godot`; entry scene `game/main/main.tscn`.
- Read `docs/design_brief.md` for accepted design facts, `docs/team_workflow.md` for current ownership, and `docs/playable_delivery.md` for the active outcome. Engineering decisions remain in `docs/foundation.md`.
- The Game Designer directs gameplay scope; the Lead Developer owns engineering assignments, integration and PR merges. Do not infer gameplay requirements from the project name.
- Use GDScript by default. Propose C#, GDExtension, or plugins when a concrete requirement justifies them.

## Implementation

- Group each feature's scenes, scripts, resources, and assets under `game/<feature>/`.
- Use snake_case file/folder names, PascalCase nodes/classes, tab-indented GDScript, and explicit types where useful.
- Prefer small composed scenes, clear ownership, and explicit dependencies. Add autoloads only for genuinely global lifetime.
- Keep changes focused. Avoid speculative frameworks, unused folders, and unrelated refactors.
- For substantive work, state a short plan and acceptance criteria before implementation.
- Use the [engineering field guide](docs/engineering_field_guide.md) for whole-path planning, ownership/transition contracts, Godot assumptions and proportionate verification; the lead owns integration after child tasks finish.
- Resolve reversible implementation details independently. Raise design contradictions, missing acceptance criteria, or costly choices with the Game Designer; continue independent work when possible.
- Measure suspected performance problems with the profiler before optimizing. Avoid per-frame polling when events suffice.

## Verification

Run from the root in PowerShell 7:

```powershell
./tools/check.ps1 -GodotPath '<path to Godot 4.7.2 executable>'
```

Or run `./tools/check.ps1` when `godot` is on PATH. CI uses the same command.
For behavior changes, add focused regression coverage when it can meaningfully catch failures, and verify changed interactions in Godot.
Report checks run, results, and any unverified behavior. Headless startup does not establish visual or gameplay correctness.
Protect desktop responsiveness: coordinate one local Godot process across the team, use bounded lower-priority focused checks, and run broad checks on CI. Do not run local suites alongside play or restart long simulations before resource use is acceptable.

## Repository care

- Commit `.uid` and `.import` sidecars; do not edit generated `.godot/` contents.
- Keep caches, engine downloads, builds, secrets, and private credentials out of commits.
- Use Git LFS before adding large binary assets; keep text scenes/resources reviewable in Git.
- Keep this file concise. Record lasting decisions with rationale and sources in `docs/`.
- Do not discard unrelated work or rewrite shared history. Describe the behavior, purpose, and validation in pull requests.
