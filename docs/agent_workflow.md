# One objective, bounded execution

Current operating workflow, 9 November 2026: the Lead is the sole programmer.
Use [feature planning and measurement](development_workflow.md) and the
[candidate comparison protocols](workflow_experiments.json) before new production
edits. The controller and parallel-team descriptions below are retained historical
capabilities, not instructions to launch workers or old regression checks. Current
team ownership and `current_change_verification.md` take precedence.

Give the lead agent an objective in this chat, for example: “Fix blueprint
placement stutter at 1x; keep the existing performance limits.” The lead first
inspects source, instructions, existing failures and the relevant overhaul plan.
It prepares a small objective JSON with fixed acceptance commands, an explicit
edit scope and limits. Meaningful acceptance must demonstrate the requested
behavior; a green unrelated suite or a system map is insufficient.

`Run Agent Task.cmd` runs that contract with one Codex worker at a time. The
Python controller alone owns verification, continuation and retry. Workers use
native persisted CLI sessions, explicit session-ID resume, JSON events and a
structured final report. Child Goals and multi-agent continuation are disabled;
existing safety configuration remains in effect. No scheduler, hook, service,
API key or second continuation loop is added. The lead may arrange an independent
review outside the controller, with explicit ownership and no concurrent edits.

Dawson's 5 November parallel-team instruction permits independent developers
in separate worktrees, as described in `developer_team.md`. The one-worker and
one-controller limits apply per objective/worktree. Direct bounded feature work
may be performed by its assigned developer; do not wrap that developer in a
second automatic continuation owner. Retain fixed acceptance, evidence and
deadlines, and use the controller when automatic retries are needed. Other
developers and the lead may inspect the work, but must coordinate edits.

## Launch and inspect

From the project folder in PowerShell:

```powershell
& '.\Run Agent Task.cmd' start 'C:\absolute\path\objective.json'
& '.\Run Agent Task.cmd' status 'EXACT_RUN_ID'
& '.\Run Agent Task.cmd' stop 'EXACT_RUN_ID'
& '.\Run Agent Task.cmd' resume 'EXACT_RUN_ID'
```

`start` prints `RUN_ID` immediately. Run it in a terminal that can stay open;
use a second terminal for status or stop. Ctrl+C also stops its owned process
tree. No background daemon is installed. Stop requests normally take effect
within a 50 ms polling interval plus child cleanup. Never use native `--last` to
resume: that could select a different task. Do not publish, reset, clean, commit
or send external messages as a side effect of this loop.
Use your normal terminal for native launches. In this coding session, its
restricted shell could not write Codex's session store; the live demonstration
used approved access to that normal store, without changing worker safeguards.

Each run lives under `logs/agent-workflow/<id>/`: `state.json`, `journal.jsonl`,
attempt requests/reports, native events, and numbered command stdout/stderr.
`status` is a saved-state view. Read the state for revision, initial file hashes,
changed files, baseline failures versus regressions, exact argv/exit codes,
attempts, elapsed time, native session ID/observed usage and next action/blocker.
Reports are worker claims; only independently executed fixed checks establish
completion. Logs may contain source and command output; review before sharing.

## Contract

An objective is JSON. Paths in `mutable_paths` are relative to `workspace`; file
names and directory prefixes are supported, not globs. `workspace` is absolute
or resolved from the launch directory. `prerequisites` and `protected_files` may
be absolute or relative to that workspace. Commands are argv arrays, never shell
strings; the exact argument `{python}` uses the controller's Python interpreter.
Use `worker.executable` when Codex is absent from PATH.

```json
{
  "objective": "Concrete behavior to implement",
  "acceptance": ["Observable outcome", "Existing invariant remains true"],
  "workspace": "C:/absolute/path/to/an/isolated/checkout",
  "mutable_paths": ["game/affected_system", "docs/system_map.json",
    "docs/ui_function_map.html", "game/diagnostics/tests/gdunit/fixtures/ui_button_contracts.json"],
  "protected_files": ["path/to/the/task-specific-verifier.py"],
  "prerequisites": ["path/to/a/required/tool"],
  "checks": [{"id": "requested-behavior", "argv": ["{python}", "path/to/the/task-specific-verifier.py"]},
    {"id": "map", "argv": ["{python}", "tools/system_map.py", "--check"]},
    {"id": "diagram", "argv": ["{python}", "tools/ui_function_map.py", "--check"]}],
  "worker": {"kind": "codex", "executable": "C:/absolute/path/to/codex.exe"},
  "limits": {"attempts": 3, "runtime_seconds": 600, "worker_seconds": 120,
    "check_seconds": 30, "no_progress": 2}
}
```

Replace the illustrative values before launching. Protect the acceptance
verifiers and their relevant dependencies/configuration. The controller also
fingerprints the objective file and its own implementation. Baseline checks run
before any worker. Failures already present are labelled `pre_existing`; a
previously passing check that fails is a `regression`. All acceptance checks
still must pass. If a verifier is wrong, stop, explain evidence and review a new
contract explicitly; do not edit it to make the current run pass.

Read existing dirty work as context; never claim it as this task's change. Use a
separate checkout when possible. The workspace scope check detects changes to
non-generated files after they happen; it is an integrity guard, **not a security
sandbox** or an automatic undo. `logs`, `.git`, `.godot`, `.tools`, Python caches,
virtual environments and node_modules are excluded from that snapshot. Symlink
targets are recorded without traversal; new or changed links require review.
Runtime artifacts belong there; retained first-party source does not. Native
worker permission boundaries remain necessary. Do not give the loop objectives
requiring uncontrolled external side effects; file reconciliation cannot prove
that an email or deployment happened exactly once.
The state directory is writable under the normal workspace: this is a workflow
for cooperative development agents, not tamper-resistant accounting against a
hostile worker or someone manually rewriting saved state.

## Limits and stopping

Defaults are three worker invocations, 600 seconds of total active runtime,
120 seconds per worker, 30 seconds per check, two attempts without changed file
content or increased check passes, and one controller per workspace. Limits are
positive finite values, attempts/no-progress are integers. Checks run serially.
There is no automatic budget increase. A worker timeout stops the run even when
the total budget has time left. Completed, failed and limit-reached runs do not
restart; a reviewed new objective is required.

On Windows, each command starts suspended and joins a private Job Object before
running. Kill-on-close contains descendants on stop, deadline and controller
crash, without touching editors or unrelated processes. A 50 ms deadline poll
and up to three seconds of cleanup are allowed; metadata/hashing and final state
writes can add overhead. No new substantive command starts beyond the total
deadline. If ownership cannot be established, launch fails closed. The POSIX
process-group fallback is weaker on controller crash and is not Windows-equivalent
crash containment. It is not presented as verified crash safety.

Attempt/runtime accounting survives resume. Before launching a command its time
allowance is reserved durably. After an abrupt controller death, resume charges
that unfinished reservation in full because exact elapsed time is unknown. It
then checks integrity and actual acceptance before another edit. It may finish
without repeating a worker whose edit already happened. A stopped run clears
its prior stop request on explicit resume; limits do not reset. An OS file lock
prevents two controllers entering the same workspace, and releases on crash.

Missing tools/inputs/permissions, invalid native reports, changes to protected
inputs, outside-scope changes or required product judgment produce `blocked`.
Unchanged failures produce `failed`; an attempt/deadline produces `limit_reached`.
Native usage is recorded when reported, possibly unknown after interruption.
**Token and money caps are not enforced.** A local kill cannot guarantee remote
in-flight billing stops immediately. This CLI exposes no hard overall token or
money control used here; a prompt is not a budget mechanism.

## Demonstration and verification

Prepare a repeatable simulation (Python 3.10+):

```powershell
& "$env:LOCALAPPDATA/Python/pythoncore-3.13-64/python.exe" tools/agent_task_demo.py prepare logs/my-workflow-demo
& '.\Run Agent Task.cmd' start logs/my-workflow-demo/objective.json
& "$env:LOCALAPPDATA/Python/pythoncore-3.13-64/python.exe" -m unittest discover -s tools/tests -p test_agent_task.py -v
```

Use a new demo directory each time. This writes only a generated isolated
`answer.py` fixture and run artifacts. Its verifier parses syntax without
executing worker-written code. The first simulated repair returns 41, the
next reads the recorded `expected 42, got 41` evidence and changes it to 42.
The processes, logs, budgets, locks and verification are real; repair reasoning
is deterministic simulation. Tests also cover missing prerequisite, exhausted
attempts, no progress, owned descendant timeout, contract tampering, overlapping
controllers, cooperative stop/resume and Windows crash/resume without replay.
Current live results and any native access blocker are in
`docs/evidence/agent_workflow.json`; simulation is not model-quality evidence.

No gameplay was changed or Godot suite run for this workflow-only task. Earlier
60 FPS acceptance failures remain separate; tool tests do not turn those green.
The existing CI already discovers `tools/tests/test_*.py`. Maintain the system
map, reviewed function purposes and UI diagram, then check them before delivery.

## Improvement without changing the current experiment

`failure_patterns` retains repeated signatures, observation counts and example
logs. Candidate instruction/orchestration improvements remain proposals. Do not
self-edit prompts, controller or checks inside an active run. In a separate
versioned change, compare old and candidate behavior on this fixture plus
representative project tasks with identical criteria/limits; run regression
checks, review tradeoffs, then adopt with the old version available for rollback.
This avoids silently adopting a different workflow just to make one run pass.

The live fixture exposed one useful candidate: explicitly assign verification
to the controller when the worker cannot execute a local interpreter. A second
isolated objective stated that division and completed automatically. The shared
worker prompt was left unchanged; wider adoption needs representative project
evaluations, rather than treating this tiny comparison as sufficient evidence.

## Runtime evidence and official references

Inspected locally: Python 3.13.15, Codex CLI 0.166.0-alpha.6, saved ChatGPT login,
`exec`/`exec resume` help and feature list. Native Goals and hooks are available;
the selected CLI execution path has no overall retry/wall-time flag. The custom
code supplies only the missing cross-turn verification, durable accounting and
execution limits. Existing GitHub assignment remains authoritative for team
ownership; these local records track execution, not a second assignment board.

Official documentation confirms the supported session, JSON-event and structured
result interfaces: [non-interactive mode](https://learn.chatgpt.com/docs/non-interactive-mode)
and [CLI reference](https://learn.chatgpt.com/docs/cli/reference).
[Native Goals](https://developers.openai.com/cookbook/examples/codex/using_goals_in_codex)
provide thread-scoped continuation; they are deliberately not another retry owner
inside these workers. Check installed help again when upgrading the CLI.
