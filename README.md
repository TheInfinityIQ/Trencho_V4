# Trencho V4

Godot **4.7.2**, standard edition. A logistics management game supplying an autonomous battlefield. The runnable project is currently a foundation; gameplay development follows the design and milestone backlog.

## Design and delivery

Start with the [design brief](docs/design_brief.md), [Game Design Document](docs/game_design_document.md), and [developer onboarding](docs/developer_onboarding.md). The GDD contains the v0.2 baseline and the governing v0.2.1 planning amendment. [Design decisions](docs/design_decisions.md) distinguish sequencing corrections and open readiness gates from proposed balance values.

Use the [delivery roadmap](docs/roadmap.md), [GitHub project](https://github.com/users/TheInfinityIQ/projects/3), [milestones](https://github.com/TheInfinityIQ/Trencho_V4/milestones), and [issue backlog](https://github.com/TheInfinityIQ/Trencho_V4/issues) to track delivery. Each system needs observable acceptance evidence; production, delivery, unloading, and local equipment issue remain distinct steps.

## Open and run

1. Use Godot 4.7.2 (the Steam `stable-4.7` branch is supported).
2. Import the root `project.godot` in Godot's project manager.
3. Press **F6** for the selected scene or **F5** for the project. The initial scene displays the project title.

No plugins, export templates, or external packages are required to run the project.

## Validate

From the repository root in PowerShell 7:

```powershell
./tools/check.ps1 -GodotPath 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
```

Alternatively, put the matching executable on PATH as `godot` and run `./tools/check.ps1`.
The check verifies the engine version, imports the project, and starts its main scene headlessly.
Logs are written to `.artifacts/`. CI runs the same check on Linux to catch path casing issues.
This is a startup smoke check; gameplay tests will accompany gameplay systems.

## Repository map

- `game/main/`: project entry scene; add feature folders under `game/` as they become necessary.
- `tools/`: development checks, excluded from Godot imports.
- `docs/`: design context and engineering decisions, excluded from Godot imports.
- `AGENTS.md`: concise instructions for AI contributors.
- `.github/`: pull request template and validation workflow.

Related scenes, scripts, resources, and assets live together within each feature.
See [foundation decisions and sources](docs/foundation.md) and the [design brief](docs/design_brief.md).

## Project ownership

No open-source license has been selected. Third-party content must retain its license and attribution.
Choose Git LFS rules before introducing large binary assets; no asset pipeline is imposed yet.
