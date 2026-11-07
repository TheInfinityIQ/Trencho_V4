# Editor startup recovery

The GDScript AST Flow addon was enabled with project scanning on startup before
it had been verified in the editor. After the reported hang around 80%, it was
disabled and moved from `addons/gdscript_ast` to the ignored
`.tools/disabled-addons/gdscript_ast` directory. Its bootstrap performs a deferred,
synchronous project analysis when scanning is enabled. This setup no longer
runs during project startup.

`project.godot` now has an empty enabled-plugin list and
`gdscript_ast/scan/enabled=false`. The quarantined addon is also beneath
`.tools/.gdignore`, so it is excluded from the editor's resource/class scan.
No manual changes were made to generated `.godot` files.

## Direct verification

Godot `4.7.2.stable.steam.ed1daf0bf` was started with
`--headless --editor --path <project> --import`, with a 30-second deadline on
only that check process. With normal file access it finished in under five
seconds, exited with code 0, produced no stderr, and logged:

```text
[  66% ] first_scan_filesystem | Initializing plugins...
[  83% ] first_scan_filesystem | Starting file scan...
[ DONE ] first_scan_filesystem
...
[  83% ] loading_editor_layout | Editor layout ready.
[ DONE ] loading_editor_layout
```

The initial restricted check also completed startup but could not write Godot's
own settings folder. The normal-access check resolved those environment errors.
Logs are retained locally under `.tools/editor-startup-check/`.

This verifies editor initialization/import, not interactive responsiveness or
gameplay. No game scene or regression suite was run.

## Future recovery

Double-click `Open Trencho (Recovery).cmd` at the project root. It opens the
installed Steam Godot editor on this project with `--recovery-mode`, which
disables editor plugins, tool scripts and GDExtensions for that opening. It does
not delete files or launch the game.

See the [official command-line documentation](https://docs.godotengine.org/en/latest/tutorials/editor/command_line_tutorial.html).
Do not restore automatic addon scanning in the main project without checking
the addon in a separate disposable project first.
