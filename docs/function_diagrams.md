# Function and signal diagrams

Double-click **Open UI Function Map.cmd** in the project root. It opens the
offline [UI function flowchart](ui_function_map.html) in your browser. Click any
function box to open VS Code at that exact source line. The browser may ask to
allow VS Code the first time. Open the page locally in its `docs/` location so
the links can determine the current project folder, including after a move.

The map includes navigation, detailed Build preview/placement/construction,
clock controls, command reconciliation, deferred notifications, new sessions
and battlefield selection. Expand **Controls by panel** for declared buttons,
toggles, selections and numeric-input connections in the shell, rear, workforce
and army-supply panels. Loop-generated controls share one source definition.
Standalone and optional diagnostic controls are labelled;
their presence in source does not mean they are available in the current game.

Each control shows its declaration, connected handler and direct script calls.
Branches can be conditional. Runtime-selected production implementations are
explicitly unresolved rather than guessed from matching method names. The
reviewed workflows show the important steps and omit some intermediate helpers;
they are not complete runtime call stacks or proof of successful gameplay.

**Update System Map.cmd** refreshes both the living map and diagram. The diagram
generator checks source fingerprints and resolves line numbers from function
IDs; it rejects stale or ambiguous reviewed call-site anchors. The launcher
checks the diagram before opening it and refreshes stale source locations.
The same generator maintains the core source-button inventory and fingerprints
used by the GdUnit UI coverage gate; stale inventories and unmatched declared
buttons fail instead of silently certifying incomplete coverage.
`tools/update_system_map.ps1 -Check` validates both without writing. On other
platforms use:

```text
python tools/system_map.py --update
python tools/ui_function_map.py --update
python tools/system_map.py --update
python tools/system_map.py --check
python tools/ui_function_map.py --check
```

The viewer needs no server, network library or Godot addon. Its links follow
[VS Code's documented file/line URL format](https://code.visualstudio.com/docs/configure/command-line#_opening-vs-code-with-urls).
Five focused tool tests verify callback separation, actual cross-file targets,
stale-source rejection, source-button obligations, reviewed anchors, portable
output and HTML escaping.

## Previous addon

GDScript AST Flow is disabled and quarantined following the reported editor
startup hang. Do not re-enable it in this project.

Its source is preserved locally in `.tools/disabled-addons/gdscript_ast`, beneath
an ignored resource directory. The original downloaded source is also retained
in `.tools/gdscript-ast-flow-source`. Neither is an active editor addon.

The enabled-plugin list is empty, and automatic project scanning is disabled.
Godot 4.7.2 completed a bounded editor initialization/import check successfully,
including the plugin stage and "Editor layout ready", with exit code 0 and no
stderr under normal file access. Gameplay was not run.

For future plugin problems, double-click `Open Trencho (Recovery).cmd` in the
project root. See [startup recovery and verification](evidence/editor_startup_recovery.md).

Original addon provenance: version 2.4.0, MIT license, upstream commit
`2d07549dcda84fe8c2933d1bdbc2254bc924caa6` from
https://github.com/kenyonxu/gdscript-ast-flow.
