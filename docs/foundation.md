# Foundation decisions

Recorded 2026-10-25. These decisions describe the current foundation and may change with the design brief.

| Decision | Rationale and limits |
| --- | --- |
| Pin Godot 4.7.2 in `.godot-version` | Keep local checks and CI reproducible within the requested 4.7 series. Steam users should verify the installed version after updates. |
| Keep `project.godot` at the root; group runtime files by feature under `game/` | Related content remains discoverable and can move together. Start with only the entry scene; create shared areas once a real shared responsibility emerges. |
| Use a minimal Control scene and Compatibility rendering | Provides a runnable starting point without choosing 2D or 3D gameplay. Reassess rendering against art requirements and target hardware before production work. |
| Start with standard Godot and GDScript | Avoid unneeded language toolchains and plugins. This is an engineering default, not a restriction on justified future integrations. |
| Keep concise agent instructions and separate design/decision documents | Agents get concrete commands and conventions; the designer's accepted facts remain distinct from engineering assumptions. More instructions are not assumed to improve results. |
| Normalize text line endings; retain Godot resource sidecars | Keep diffs readable on Windows and Linux, preserve resource identities, and exclude generated caches. `.gdignore` keeps non-runtime directories outside the engine's resource scan. |
| Validate import and startup locally and on Linux CI | Catch broken resources and case-sensitive paths early. This does not replace gameplay tests, export checks, profiling, or visual verification. |
| Pin the CI runner to Ubuntu 24.04 and checkout action to its v7.0.1 commit | Avoid automatic runner distribution migrations and deprecated action runtimes. Review these pins during maintenance. |
| Defer Git LFS rules until assets are introduced | Avoid imposing a storage workflow before asset requirements exist. Configure LFS before the first large asset commit to avoid later history migration. |

## Sources consulted

- [Godot 4.7 project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html): scene-adjacent content, naming conventions, and `.gdignore`.
- [Godot 4.7 version control](https://docs.godotengine.org/en/4.7/tutorials/best_practices/version_control_systems.html): generated cache exclusions, LF line endings, and LFS setup timing.
- [Godot GDScript style guide](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html): code conventions.
- [Godot command line reference](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html): headless import and bounded startup commands.
- [Official Godot release index](https://editor.godotengine.org/releases/): availability of 4.7.2 stable.
- [AGENTS.md specification and guidance](https://agents.md/): shared agent instructions with setup commands, conventions, and verification guidance.
- [Official checkout action](https://github.com/actions/checkout/tree/3d3c42e5aac5ba805825da76410c181273ba90b1): the pinned v7.0.1 source, verified against its upstream Git tag.

Folder structure, renderer defaults, check implementation, and deferral of infrastructure are project judgments based on these sources, not claims that the sources prescribe this exact repository.

## G01 implementation follow-up

The initial title placeholder is superseded by the bounded [identity/accounting fixture](g01_identity.md). It uses a scene-owned typed ledger, detached inspections and event-driven review UI, plus a dependency-free headless regression runner. Canvas scaling keeps its review controls usable in smaller windows. These choices apply to G01 evidence; D01 still owns the production presentation/platform/performance decision. See the G01 document for interruption, accounting and future persistence obligations.

## G02 implementation follow-up

The entry scene now opens the bounded [procurement/receiving fixture](g02_receiving.md). A scene-owned service advances a chronological event clock through dispatch, arrival, walking, handling and physical vehicle clearance. It uses G01 identities and source claims; destination storage and delivery admissions have separate lifetimes. Explicit time buttons make boundary cases reproducible without per-frame polling. The predefined metre positions and access paths demonstrate local continuity; they do not implement world pathfinding, traffic, production presentation or D03 capacity policy. Interface signal/layout checks supplement domain regressions, with native interaction evidence tracked separately.

## G03 implementation follow-up

The current entry selects the bounded [staffing/hauling draft](g03_staffing.md) and retains G01/G02 review scenes with separate declared state/clocks. G03 adds event-boundary reporting/handling jobs over the G01 ledger, destination-space promises, physical reroute/pile recovery and a single owned T01 parking/station activity. A small visibility graph avoids declared rear footprints; this is reversible fixture geometry, not a world navigation/performance decision. The ledger's occupied driver station defers assignment until safe exit, and retained gear reduces ordinary carry allowance. No global autoload or third-party job framework is introduced. The governing GDD23.5 verification decision permits G03 foundation assessment on reviewed logic, actual Linux engine input and current-revision rendered visual evidence. Windows OS input/readability remain unverified D01/M0 obligations; signal/bounds tests alone do not establish them.

## G08 integration follow-up - 27 October 2026

The feature-local [G08 terrain/movement/sight diagnostics](g08_terrain.md) retain their reviewed analytical algorithms and catalogue. The main review row uses a flow container so the added selector wraps at small window sizes; G03 remains the default and G04 R01/G02/G01 remain reachable. This integration changes no shared simulation ownership or runtime gameplay. GDD23.7 separately authorizes the G08 foundation evidence path; genuine Linux CI renders with state metadata supplement domain and actual engine-input checks. Windows OS input/readability remain unverified D01/M0 obligations.
