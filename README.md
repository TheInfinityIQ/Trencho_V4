# Trencho V4

Godot **4.7.2**, standard edition. A logistics management game supplying an autonomous battlefield. The runnable project is currently a foundation; gameplay development follows the design and milestone backlog.

## Design and delivery

Start with the [design brief](docs/design_brief.md), [Game Design Document](docs/game_design_document.md), and [developer onboarding](docs/developer_onboarding.md). The GDD contains the v0.2 baseline and the governing v0.2.1 planning amendment. [Design decisions](docs/design_decisions.md) distinguish sequencing corrections and open readiness gates from proposed balance values.

Use the [delivery roadmap](docs/roadmap.md), [GitHub project](https://github.com/users/TheInfinityIQ/projects/3), [milestones](https://github.com/TheInfinityIQ/Trencho_V4/milestones), and [issue backlog](https://github.com/TheInfinityIQ/Trencho_V4/issues) to track delivery. Each system needs observable acceptance evidence; production, delivery, unloading, and local equipment issue remain distinct steps.

## Open and run

1. Use Godot 4.7.2 (the Steam `stable-4.7` branch is supported).
2. Import the root `project.godot` in Godot's project manager.
3. Press **F5** for the G03 staffing/hauling draft fixture. Use its explicit time buttons and A05-input/A06-carry/driver scenarios. [G03 behavior and verification](docs/g03_staffing.md) records the implemented scope and missing native A06 evidence; the full A05 production continuation remains G04.
4. The top review buttons open the retained G02 Procurement and G01 Identity fixtures, each with its own declared state/clock. Switching review resets that fixture. They also run individually with **F6** from their scene files.

No plugins, export templates, or external packages are required to run the project.

## Validate

From the repository root in PowerShell 7:

```powershell
./tools/check.ps1 -GodotPath 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
```

Alternatively, put the matching executable on PATH as `godot` and run `./tools/check.ps1`.
The check verifies the engine version, imports the project, runs G01/G02/G03 regression suites and G02/G03 interface signal/layout checks, and starts the main scene headlessly.
Logs are written to `.artifacts/`. CI runs the same check on Linux to catch path casing issues.
The suites check identity, exclusive duties, physical transfers, ammunition conservation, purchases/receiving, staffing/eligibility, priority/aging, local hauling, safe carry/driver handoffs and reservations/capacity. Engine-driven signals and geometry do not establish native input, readability or full-game correctness. See [G01](docs/g01_identity.md), [G02](docs/g02_receiving.md) and [G03](docs/g03_staffing.md) for evidence and limits.
The [GdUnit4 pilot and testing guide](docs/testing.md) documents the pinned MIT dependency, domain checks, required display-backed SceneRunner CI step and failure controls. The default headless command explicitly excludes scene-input evidence; use `-SceneInput` with a display for the full set.

## Repository map

- `game/main/`: project entry scene; add feature folders under `game/` as they become necessary.
- `game/identity/`: G01 accounting model, scripted inputs, review UI, and focused regression tests.
- `game/procurement/`: purchase catalogue, timed supplier/Receiving simulation, review UI and focused regression tests.
- `game/staffing/`: physical staffing/hauling, bounded T01 yard handoff, review UI and focused regression tests.
- `tools/`: development checks, excluded from Godot imports.
- `docs/`: design context and engineering decisions, excluded from Godot imports.
- `AGENTS.md`: concise instructions for AI contributors.
- `.github/`: pull request template and validation workflow.

Related scenes, scripts, resources, and assets live together within each feature.
See [foundation decisions and sources](docs/foundation.md) and the [design brief](docs/design_brief.md).

## Project ownership

No open-source license has been selected. Third-party content must retain its license and attribution.
Choose Git LFS rules before introducing large binary assets; no asset pipeline is imposed yet.

