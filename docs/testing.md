# Automated checks and GdUnit4 pilot

Related task: [issue #60](https://github.com/TheInfinityIQ/Trencho_V4/issues/60). This integration adds two focused tests to accepted G01/G02 code; it does not migrate or remove the existing suites.

## Repeatable commands

PowerShell 7, from the project root:

```powershell
./tools/check.ps1 -GodotPath '<Godot 4.7.2 standard executable>'
```

This checks the pinned engine, acquires/verifies GdUnit4, imports, runs all existing suites, starts the main scene headlessly and runs the GdUnit4 domain test. The existing 1,750 assertions remain: G01 624, G02 842, G02 callback/layout 190 and D01 data probe 94. The new suite reports test cases separately; assertion counts are not measures of gameplay acceptance.

The default command explicitly reports **Scene-input pilot NOT RUN**. Headless Godot cannot establish this input behavior. For the complete command on Linux, use a working X display or Xvfb with `xauth` and OpenGL software-rendering support (the pinned Ubuntu CI image supplies these):

```powershell
xvfb-run -a pwsh -NoProfile -File ./tools/check.ps1 -SceneInput -GodotPath '<Godot 4.7.2 standard executable>'
```

CI retains all default checks and requires the additional display-backed input step. The input command selects Godot's Dummy audio driver because it does not test audio hardware. Missing display prerequisites, missing reports, skipped tests, engine errors and assertion failures fail the command. Windows display-backed execution is not verified in this pilot; no local desktop launch is needed for its domain check. No changes to the project renderer, engine version or plugin-enabled settings are required.

For a focused rerun after setup/import:

```powershell
./tools/run_gdunit4.ps1 -GodotPath '<godot>' -Suite Domain
# Input requires a display; on Linux prefix this command with xvfb-run -a pwsh -File.
./tools/run_gdunit4.ps1 -GodotPath '<godot>' -Suite Input
./tools/prove_gdunit4_failure.ps1 -GodotPath '<godot>' -Suite Domain
```

The failure probe temporarily changes one expected value, invokes the same runner in a child PowerShell process, requires a named JUnit assertion failure and a nonzero command exit, restores the original bytes in `finally`, then reruns the passing test. CI runs this proof for `-Suite Input`. Do not run the probe concurrently with another test run or source edit. A hard process kill can interrupt restoration; inspect the diff before committing.

`.artifacts/gdunit4/<suite>/report_1/` contains JUnit XML and HTML; its parent contains the engine log. Failure-control output also includes `command.log` and `proof.json`. CI uploads `.artifacts/` on success and failure, for seven days. A failing upload cannot turn a failed test into a pass.

## Dependency source and license

[GdUnit4 v6.2.2](https://github.com/godot-gdunit-labs/gdUnit4/releases/tag/v6.2.2) is pinned in [tools/gdunit4.lock.json](../tools/gdunit4.lock.json) to commit `0127a55f4543dfc24746f6e5c7ba6f94105d51f2` and SHA-256 `58a391b0c85cbbcf7aeb09b718c8173793d45ab511950cd65eec0183aabf0e50`. The checksum records the downloaded immutable source archive; it is not an independently signed upstream checksum. [MIT license and attribution](licenses/gdunit4_license.txt) are retained, and the acquired addon also contains its upstream license.

`tools/setup_gdunit4.ps1` downloads that exact archive into ignored `.tools/`, verifies its checksum before extraction, installs only `addons/gdUnit4/` into an ignored test dependency, and validates every installed upstream file against the archive on each check. Unexpected source/content changes fail setup. Godot-generated `.uid`/`.import` sidecars are allowed within this generated dependency; project-owned test sidecars are committed normally. The framework is not enabled as an editor plugin or needed to play the project. After acquisition, checks can run offline from the verified archive cache.

To upgrade, select an official stable release, review its immutable source, license and compatibility changes, recompute the archive checksum, update the lock and license, and rebuild only the ignored framework/cache after preserving intentional local dependency edits. Do not overwrite a different installed version silently. Run all retained suites, both pilots and failure controls before submitting the pin change. Never select an engine upgrade simply to satisfy the test framework.

## Coverage and limits

- Domain pilot: two distinct freight purchases cost 220 and 420. Cancelling the first refunds exactly 220 once, preserves the second admission and all its 200 M01, and leaves that cargo aboard after arrival with zero workers. Every test owns a fresh `RefCounted` simulation, so no shared scene or fixture state survives it.
- SceneRunner pilot: the actual existing G02 Purchase button is located in the loaded scene. [Documented SceneRunner mouse events](https://godot-gdunit-labs.github.io/gdUnit4/latest/advanced_testing/scene_runner/mouse/) enter Godot's input pipeline and await processing frames. A disabled button leaves the entire snapshot unchanged; re-enabling and clicking commits the 100 M01 order, charges 220, reserves one vehicle admission and updates the visible summary. No direct `pressed.emit`, handler call or gameplay-state injection implements the positive action. Disabling the control is test setup for the negative input case.
- Compatibility is demonstrated per environment, not asserted from an upstream version table: Windows Godot `4.7.2.stable.steam.ed1daf0bf` imports the framework and passes the headless domain/retained tests. Actual mouse/touch positive controls failed in forced headless mode, consistent with the upstream runner's warning. Linux CI supplies the required display-backed SceneRunner evidence; its status must be checked against the submitted head.

Migrate small deterministic domain cases incrementally when named assertions, fixtures or reports improve diagnosis. The next useful input regression is actual delivery-row selection followed by cancellation: it would catch wrong selection, hit testing and focus that the existing emitted-signal checks bypass. Do not rewrite already meaningful suites merely to increase framework usage.

SceneRunner input is engine integration evidence. It does not test Windows `SendInput`, OS pointer targeting, actual screen readability, rendering correctness, full-game usability or performance. G03/G08 are unmerged and excluded from this pilot; their remaining native gates, G04 production continuation, G32 persistence and D01 production presentation remain separate. Developers own testing; routine QA is not delegated to the human designer.
