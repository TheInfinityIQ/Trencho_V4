# Living system map

The [implementation atlas](system_atlas.html) adds an overview and 48 individual
system diagrams to the function inventory. Read [all diagrams in Markdown](system_atlas.md)
or query [its JSON](system_atlas.json). Every game script has a primary owner;
retained tests and optional review scenes are labelled separately. Diagram nodes
open the current source line in VS Code. It documents actual implementation,
including the still-shared clock, rather than the intended overhaul.

The existing explicit updater also refreshes the atlas. When game source changes,
review affected descriptions and references in `system_atlas_catalog.json`, then
update only the corresponding normalized SHA256 entries in `reviewed_sources`.
New non-test scripts need an explicit `file_owners` entry. Generation refuses
unreviewed source changes; do not stamp hashes without reviewing the code.
The launcher uses `ui_function_map.py --diagram-only` to preserve deferred
button-test fixtures. This documentation workflow neither updates those fixtures
nor executes their retained suites.

`system_map.json` inventories every existing tracked or nonignored project file.
Every named GDScript function and anonymous callback is included, along with
Python functions and PowerShell functions/inline scriptblocks in development
tools. Retained tests, demos,
scene nodes/connections, signals, class fields and enum declarations are included.
Binary evidence images are classified and fingerprinted; they are not interpreted
as executable source. Generated caches/logs/builds and ignored downloaded addons
are excluded explicitly in `scope`.

Each function has a stable file/name ID, source range, signature, implementation
hash, purpose, return expressions, syntactic assignments, calls, emitted signals
and connection expressions. Lambda IDs are relative to their containing function.
`purpose_origin` distinguishes initial implementation-derived descriptions from
reviewed explanations. The initial inventory does not claim that every inferred
purpose has received a separate human semantic review.

The map includes the default entry scene, system responsibilities, file dependencies
and conservative literal-resource reachability from the main scene. Call targets
are resolved only for provable local/preloaded script methods. Unproven receivers
reference a shared `call_candidates` group or carry an unresolved label.
Unmatched expressions are retained in `external_or_dynamic_calls` without
repeating the same verbose resolution label on every engine call. These are
navigation aids, not proof that a call occurred. Runtime stack logs supply
actual observed chains. Neither this map nor a function count establishes tests.

## Read a small part

The JSON uses one compact function record per line. Use queries instead of loading
the whole map into a conversation:

```powershell
python tools/system_map.py --query game/main/game_session.gd
python tools/system_map.py --query identity_ledger.gd::inspect_entity
python tools/system_map.py --callers game/identity/identity_ledger.gd::inspect_entity
```

`--query` returns an exact file or matches function IDs. `--callers` separates
definite static callers from possible calls through unresolved receivers. The
complete map remains ordinary JSON for other tools.

## Update after every change

Double-click `Update System Map.cmd` to update both the living map and clickable
[UI diagram](function_diagrams.md). Its wrapper fingerprints the generated
diagram after generation. For direct Python use, run:

```powershell
python tools/system_map.py --update
python tools/ui_function_map.py --update --diagram-only
python tools/system_map.py --update
python tools/system_map.py --purpose game/main/game_session.gd::notify_command "Notify views that a command changed shared session state."
python tools/system_map.py --check
python tools/ui_function_map.py --check --diagram-only
```

The updater preserves purpose text. Changed/new function bodies are marked
`purpose_review_required`; updating structure alone cannot clear that flag.
Review a function's current implementation, then supply its current purpose with
`--purpose`. A bulk review uses `--review-file path/to/reviews.json`, whose value
is a JSON object mapping exact function IDs to purpose strings. Removed functions
are removed from the map. Source hashes normalize line endings for Windows/CI.

`--check` rebuilds facts in memory without rewriting the map. It rejects missing
files, stale code/locations/connections and pending purpose reviews. The root
`AGENTS.md` makes this part of future code changes. Map freshness is an explicit
developer check; current CI is limited to changed-production parsing and an
optional brief current-change demonstration. The updater is an explicit development command, not a background watcher
or Godot startup task. It does not run gameplay or enable an editor addon.

## Dependencies and verification

Python 3.10+ and PowerShell are required. The Windows launcher locates the installed
Python and acquires the pinned parser locally only if absent. For other systems:

```text
python -m pip install -r tools/system_map_requirements.txt
python -m unittest discover -s tools/tests -p test_system_map.py
python tools/system_map.py --check
```

GDScript definitions come from the pinned
[GDScript Toolkit parser](https://github.com/Scony/godot-gdscript-toolkit/blob/master/gdtoolkit/parser/parser.py),
with source-position metadata. Python uses its standard AST and PowerShell its
native parser. No source is executed to build the map. Godot's
[signal documentation](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/signals.html)
explains why callbacks can be connected dynamically; unresolved links remain
explicit rather than being presented as a complete runtime call graph.

The [overhaul plan](system_overhaul_plan.json) uses this map to link source
findings, protected behavior, ordered migration phases and proposed acceptance
cases. Its [audit inventory](overhaul_inventory.json) fingerprints all GDScript
files and lists scheduler interfaces, inspection candidates and signal links.
The inventory preserves the pre-implementation snapshot and explicitly lists
current drift. The plan preserves historical anchors alongside current anchor
status and bounded implementation evidence. Check those before using a phase,
and keep proposed tests separate from executed evidence. The living map remains
the current source inventory.

Seven focused tool tests cover named/anonymous discovery, nested callback scope,
local/preloaded/dynamic links, the native PowerShell parser, cross-platform source
hashes and stale-map rejection after function additions, edits and removals.
They also cover multiline callbacks whose parser endpoint is absent: the mapper
recovers the endpoint from child syntax instead of including the rest of the
file in the callback's range and fingerprint.
These tests verify the map tooling; they do not execute or certify gameplay.
