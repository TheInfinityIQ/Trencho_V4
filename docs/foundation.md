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
| Defer Git LFS rules until assets are introduced | Avoid imposing a storage workflow before asset requirements exist. Configure LFS before the first large asset commit to avoid later history migration. |

## Sources consulted

- [Godot 4.7 project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html): scene-adjacent content, naming conventions, and `.gdignore`.
- [Godot 4.7 version control](https://docs.godotengine.org/en/4.7/tutorials/best_practices/version_control_systems.html): generated cache exclusions, LF line endings, and LFS setup timing.
- [Godot GDScript style guide](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_styleguide.html): code conventions.
- [Godot command line reference](https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html): headless import and bounded startup commands.
- [Official Godot release index](https://editor.godotengine.org/releases/): availability of 4.7.2 stable.
- [AGENTS.md specification and guidance](https://agents.md/): shared agent instructions with setup commands, conventions, and verification guidance.

Folder structure, renderer defaults, check implementation, and deferral of infrastructure are project judgments based on these sources, not claims that the sources prescribe this exact repository.
