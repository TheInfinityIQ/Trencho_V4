# Automated checks and GdUnit4 pilot

Related task: [issue #60](https://github.com/TheInfinityIQ/Trencho_V4/issues/60). The original pilot adds two focused G01/G02 tests; the G03 extension adds two input cases below. Existing suites are retained, not mass-migrated.

## Repeatable commands

PowerShell 7, from the project root:

```powershell
./tools/check.ps1 -GodotPath '<Godot 4.7.2 standard executable>'
```

This checks the pinned engine, acquires/verifies GdUnit4, imports, runs all existing suites, starts the main scene headlessly and runs the GdUnit4 domain test. The existing 2,962 assertions remain: G01 624, G02 842, G02 callback/layout 190, G03 domain 798, G03 callback/layout 414 and D01 data probe 94. The new suite reports test cases separately; assertion counts are not measures of gameplay acceptance.

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

The failure probe temporarily changes one expected value, invokes the same runner in a child PowerShell process, requires a named JUnit assertion failure and a nonzero command exit, restores the original bytes in `finally`, then reruns the passing test. CI runs this proof for `-Suite Input` and for `-Suite Input -G03Driver` (a deliberately incorrect initial driver-fuel expectation). `tools/gdunit4_tests.json` declares all required paths and test names; the runner rejects missing, extra, duplicated or skipped cases rather than assuming a single passing test is sufficient. Do not run the probe concurrently with another test run or source edit. A hard process kill can interrupt restoration; inspect the diff before committing.

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

SceneRunner input is engine integration evidence. It does not test Windows `SendInput`, OS pointer targeting, actual screen readability, rendering correctness, full-game usability or performance. G03 foundation was accepted under GDD23.5; G08 has the separately assigned foundation path under GDD23.7 below. Remaining Windows obligations, G04 production continuation, G32 persistence and D01 production presentation remain separate. Developers own testing; routine QA is not delegated to the human designer.

## G03 scene-input extension

The input manifest requires three cases: the retained G02 purchase pilot plus G03 driver and staged A05. The G03 tests drive actual reset/tab/time/assignment/release and row-selection controls through SceneRunner mouse input and await frame processing. Reads of simulation snapshots and current inspection labels supply assertions; no action is implemented by signal emission, handler calls or direct gameplay-state changes.

The driver case rejects movement before the three-second P08 station entry, observes an actual 12m first-second move/fuel burn and shared driver/hull location, verifies repeated release preserves one pending assignment while moving, checks physical parking separately from the three-second exit, then re-enters the current parked hull while retaining distance/fuel/parking. Occupied destination parking refuses a second trip. The staged A05 case retains two actual operators with Missing Inputs before hauling; exact 2 M01 and 1 M02 then arrive physically, selected-job/person details refresh, promises clear and work/consumption/output stay zero. No production recipe executes.

Windows checks remain headless domain/callback/layout evidence; display-backed behavior is verified in Linux CI at the PR's actual submitted revision. These regressions do not resume a stopped native session or replace missing desktop/render/readability evidence. PR #54 was subsequently accepted under GDD23.5; Windows obligations remain open.

## G03 rendered foundation evidence

The G03 input cases also export `.artifacts/g03-rendered/*.png` and matching JSON after actual rendered frames. CI sets EVALUATION_HEAD to the submitted PR head. For a local display-backed run set that variable to the exact checked-out commit first. The12 checkpoints and metadata are listed in [G03 evidence](g03_staffing.md#revised-foundation-evidence-path--26-october-2026). The same Input manifest retains accepted D01 rendering and the G02 pilot; no required named case is dropped. Failure-control runs restore original test bytes and rerun the complete healthy suite before the final artifacts are uploaded.

Inspect the actual images together with their matching state/selection/revision records. These are Linux CI viewport renders, not Windows native screenshots; GDD23.5 records the Designer's revised foundation verification path and outstanding Windows obligations.

## G08 scene-input extension

The accepted G08 integration retained all eleven Domain cases and all five earlier Input cases, adding the two existing G08 Input cases: `test_blocked_wheel_then_real_road_travel_preserves_fuel_and_inspection` and `test_eye_and_ground_muzzle_then_independent_direct_and_blast_cover` (seven Input cases total). The default headless command also runs the G08 domain and callback/layout regressions; display input and rendering still require Linux CI's virtual display.

The G08 cases export eight PNG/JSON pairs to `.artifacts/g08-rendered/`, after rendered frames. JSON records EVALUATION_HEAD, engine, image dimensions, raw-pixel SHA-256, selected fixture, actual numeric state, inspection text, Overview and scroll position. Movement metadata includes actual clock/pose/fuel; sight metadata explicitly labels static declared probes. See [G08's current evidence record](g08_terrain.md#current-integration-and-evidence-path---27-october-2026) for checkpoints and [GDD23.7](game_design_document.md#237-g08-foundation-verification-path---27-october-2026) for the separate Designer-authorized foundation path.

CI retains every accepted failure control and adds `./tools/prove_gdunit4_failure.ps1 -GodotPath '<godot>' -Suite Input -G08Movement` under Xvfb. This temporarily changes the full-road clock expectation from6 to7, requires the named G08 assertion to fail, restores source bytes and reruns the full healthy Input suite. Artifact images must be downloaded, checksum-verified and visually reviewed alongside their matching current-head metadata. Windows OS input/readability and full gameplay remain unverified; no native retry is authorized by this extension.

## R01 stock-target checks

The R01 target extension adds ten named domain cases and one normal-launch actual-input case, bringing the required manifest to21 Domain /8 Input while preserving all4270 legacy assertions, accepted fractional endpoints and all four failure/restoration controls. Run the same commands above; the Windows default remains headless, and CI supplies Linux display input and renders. The [R01 record](g04_r01.md#r01-stock-target-extension---27-october-2026) links the assignment, reroute and individual-weapon decisions and describes A/C ownership. Its four new checkpoints join the six retained continuous R01 image/state pairs under `.artifacts/g04-r01/`. Verify exact revision, engine, dimensions, pixel hashes and real stock/work/forecast state together, and personally review the images before handoff. Full G04/M0 and Windows native testing remain outstanding.

## Fixed R02 checks

The [R02 record](g04_r02.md) adds13 Domain cases and one actual normal-launch Input case, requiring34 Domain /9 Input in total without removing any accepted case. Five image/state pairs under `.artifacts/g04-r02/` accompany missing-local, actual-start, retained-work, physical100-round/target-satisfied and small-window wheel-scrolled states. A fifth required failure proof, `-Suite Domain -R02Yield`, changes100→101 and restores the healthy Domain suite. The four existing controls and all retained render groups remain required. The same pinned dependency/engine and commands apply; Windows headless checks do not establish display input or native acceptance.

## Fixed R26 checks

The [R26 record](g04_r26.md) adds12 Domain cases and one normal-launch Input flow, retaining every accepted case for46 Domain /10 Input. Six image/state pairs under `.artifacts/g04-r26/` cover missing-local, partial multi-trip delivery, full-material start, retained partial100-work progress, physical100 M11/target satisfied and small-window wheel inspection. `-Suite Domain -R26Work` changes completed work100→101, fails once and restores the healthy Domain suite; all five earlier controls remain. Exact-head source/log/state/image checks, downloaded checksum verification and personal inspection of new/changed renders precede the Designer handoff. Full G04/A08/M0 and Windows native evidence remain outstanding.

## R27 and F05 selection checks

The [R27 record](g04_r27.md) adds eighteen Domain cases and one real normal-launch Input flow, retaining all prior cases for 64 Domain /11 Input and all 4278 accepted legacy/layout assertions (selector bounds may grow). Nine image/state pairs in `.artifacts/g04-r27/` cover real hauling, R02 partial work, normal/small pending confirmation and declined/confirmed recipe changes, blocked R27 partial work, physical M06 and actual small-window scrolling. Confirmation uses actual embedded dialog buttons and Escape, not direct handlers or injected state. `-Suite Domain -R27Yield` changes expected physical M06 from 1 to 2, fails exactly once and restores the full healthy Domain suite; all six prior controls remain. Exact-head CI/artifact/hash/state/personal visual review is required before handoff. Windows OS/native verification and complete G04/M0 remain separate.

R27 CI timing measured about 21 seconds for Domain and 37 seconds for Input before final scrolling, in addition to import/legacy checks. Four Domain and three Input failure controls each rerun both broken and restored suites. The job budget is therefore ten minutes rather than eight, retaining all checks and engine/framework/action/runner pins. This is a test-run budget, not a gameplay performance claim.

## Explosive-fed shell-chain checks

The [shell-chain record](g04_shell_chain.md) adds fifteen Domain and two actual-input cases, retaining 64/11 for 79 Domain/13 Input. Both new chain flows start with only raw depot stock and physically manufacture/haul all twenty M06; initialized M06 fixtures are explicitly component-only. The `-ShellChain` Domain control changes the actual raw-to-R32 output expectation 10 to 11, fails once, restores source and reruns the healthy suite. All seven earlier controls remain. New render/state pairs cover both physical outputs, absent access, M06 lineage/handling, partial work and small scrolling. Exact-head CI/downloaded checksum/decoded pixels/numeric state/personal visual review remain required; Windows native verification and G31/full A09 are separate.

Shell-chain measurement: local full Domain is about 52 seconds, including roughly 35 seconds for the fifteen new cases, compared with the prior CI Domain baseline of 21 seconds. Five Domain and three Input controls each execute broken/restored suites, alongside two added real-input chains. CI therefore has a bounded thirty-minute budget rather than ten; no checks or pins are removed. This budgets evidence execution and does not claim a gameplay performance regression or optimization.

Exact-head CI measurement refined the budget: the initial full check took 109 seconds, actual Input about 101 seconds, and each complete Domain wrong/restored pair about 125 seconds. Five such pairs and three full Input pairs require roughly 24-25 minutes including setup/artifact upload. Thirty minutes leaves bounded runner variance while preserving every full-suite proof and pin.


## Connected rear-base checks and streamlined controls - 27 October 2026

The current human/Designer verification policy in the [connected scope](https://github.com/TheInfinityIQ/Trencho_V4/issues/12#issuecomment-6454565796) supersedes the historical repeated-full-suite and exhaustive image-packet requirements above. Full normal checks and actual Input remain, now 87 Domain /14 Input with all earlier named cases retained. Eight domain cases exercise connected physical ownership, common time, purchasing/arrivals, safe duty transfer and capacity recovery. One normal-entry input flow exercises player commands and exports four useful screenshots/state records to `.artifacts/connected-rear/`. Review those for the changed UI; no broad independent pixel/JUnit proof packet is a prerequisite.

Each of the eight retained negative controls now runs only its exact named failing/restored case, verifies the wrong expectation and original-source SHA256 restoration. `run_gdunit4.ps1 -Suite Domain -CaseName '<exact manifest case>' -ReportName focused` selects one case; unknown/ambiguous names fail. Omit CaseName for the unchanged complete suite contract. Framework/engine pins and all existing regression checks remain. Linux display input/render evidence does not establish Windows native or full M0 acceptance.


## Connected catalogue checks - 27 October 2026

The [catalogue scope and checks](production_catalogue.md) add nine focused Domain and two actual-input cases, requiring 96 Domain /16 Input with every earlier case retained. Exact recipe specifications are checked against independently parsed GDD 6.1/6.3 rows; component/ineligible/ownership cases are parameterized over recipes. Two purchased-goods input flows cover the compact menus, explicit new-session boundary, all nine resources, actual explosive-fed manufacture and Workshop/Support confirmation loss. Four representative PNG/JSON pairs are exported to `.artifacts/production-catalogue/`. Use the existing `CaseName` selector for affected iteration cases and full normal checks at the stable final revision. Eight existing focused negative controls remain, without new per-recipe controls or broad historical image-packet requirements.

## Heavy manufacturing checks -27October2026

The [heavy scope](heavy_production.md) adds8focused Domain cases and1actual-input flow, retaining96/16 for104Domain/17Input. The original23non-heavy cases explicitly retain their non-heavy scope; new cases cover all6heavy recipe rows and real physical outputs. The critical7live/1reserved invalid-destination case retains earned work and converts to8/0 exactly once. Three representative normal/small render/state pairs are exported to `.artifacts/heavy-production/`. Use named affected cases during iteration, full normal checks on the stable head, and the same8existing focused negative controls. No new per-recipe proof or all-image packet is required.
