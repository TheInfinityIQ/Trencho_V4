# Foundation decisions

The authored opening composes the existing ledger, military transport, orders, terrain and objective owners under the rear clock; scenario policy creates intent, and squad execution consumes delivered intent. HQ marker affiliation is relative to the observing army, so a formation never reports its own HQ as hostile. Player panels filter own physical formations; enemies remain delivered reports.

Opening profiling exposed repeated full-ledger inspection and nested mass recomputation. Snapshot masses are now aggregated once per synchronous inspection, without a persistent cache; existing holder/type queries restrict reads to their actual candidates. Snapshot/live recursive mass equivalence and retained physical regressions protect the change. Terrain route aggregation separately uses the measured exact-output [interval sweep](route_sweep.md). These measurements do not settle full-map performance acceptance.

Roster, cohesion and motion status reads use `inspect_person_status`, which returns detached person facts with no contents-mass field. Carry, route load, payload and complete inspection still use the full live mass calculation. This removes unused inventory aggregation from measured status queries while preserving exact mass arithmetic at admission boundaries.

Current engineering authority is [team workflow](team_workflow.md). Before shared changes identify state owner, valid transitions, affected callers and interaction coverage. Reuse existing ownership; repair concrete occupancy/activity and damage/movement weaknesses without speculative frameworks. Historical entry-scene reports below are not current delivery status.

G24 adds scene-owned [vehicle destruction and recovery](g24_vehicle_recovery.md), synchronously resolving one ledger destruction outcome across armour, demolition and bridge collapse, with paid repairs and physical tow coupling on the common clock.

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
| Keep G19 field project state on the shared ledger, terrain world and rear clock | A field site cannot grant capability from an order or remote promise. [G19 ownership and G26a delivery boundary](g19_field_structures_roads.md) document the physical handoff, cancellation and G32 restore obligations. |
| Keep D04 on the existing ledger, target services and event clock | [G21 attached demolition](g21_bridge_denial.md) consumes staged M06 only at completed placement, records command and clearance, and changes the assigned bridge or structure through its real damage owner. G10 supplies authored crossing identities; G32 restores device, stock, timers and terrain together. |

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

## Fixed R01/R02 production reuse - 27 October 2026

The [R02 release](g04_r02.md) justifies extracting the accepted R01 lifecycle and review controls for two fixed specifications. The rear explicitly owns optional R01/F04 and R02/F05 activities on its common clock; ledger holders, real staffing/haul jobs and space promises remain authoritative. No dynamic recipe switching, all-recipe scheduler, new inventory or global lifetime is introduced. Separate batch prefixes preserve independent ownership. Retained R01/domain/input checks and focused simultaneous-facility regressions verify the extraction; production presentation and full G04/M0 remain unaccepted.

The subsequent [R26 release](g04_r26.md) adds a third explicit owner and makes required operator-work a fixed recipe value (40/40/100). Existing facilities, clock, people and capacity accounting remain authoritative. Different-duration simultaneous-facility, fractional-time and multi-trip hauling evidence verifies this narrow extension; it introduces no construction system or general recipe switching.

## Exclusive F05 R02/R27 selection - 27 October 2026

The [R27 release](g04_r27.md) justifies a single selectable F05 owner over the existing fixed lifecycle. Only R02/R27 alternate, with R02 the default; the rear still owns three facility activities. Token/recipe/batch revalidation makes consumed-batch cancellation explicit and stale-safe. Per-recipe mode/target/history/identity records survive selection, while physical goods, exclusive people, hauling and promises remain with existing owners. No all-recipe scheduler or second inventory is introduced. Actual embedded confirmation/decline/dismissal input and focused stale/fractional/exclusive-work regressions accompany the bounded review.

## Declared-access shell chains - 27 October 2026

The [R32/R33 assignment](g04_shell_chain.md) extends the same F05 owner with two choices guarded by access declared at construction. No live card/unlock service is introduced. Real R27 output is hauled through existing ledger portion lineage to the input holder before consumption. Compact history summaries keep the larger history inspectable without changing authoritative receipts or identities. Existing explicit facility owners, common clock, exclusive people and output promises remain.

## Connected rear-base integration - 27 October 2026

The [connected rear base](connected_rear_base.md) makes the existing rear the owner of one ledger and joint event boundaries, injecting that ledger into procurement. Explicit receiving hooks add passenger adoption, exclusive unloading and shared inbound capacity to existing staffing/production. The map transforms authoritative positions, and scene-owned panels retain state without an autoload or additional inventory. Removing the base from the tree for a diagnostic pauses its clock; reattaching reuses the same instance. Simple shapes and local geometry implement this assignment without resolving D01 world presentation or G05 construction. Focused named negative controls replace repeated full-suite mutations under the human verification override while full normal suites remain.


## Non-heavy catalogue - 27 October 2026

The [catalogue](production_catalogue.md) now justifies reusing F05's confirmed-selection lifecycle for explicit F04/F05/F09 owners. Their own copied access, per-recipe records and consumed-batch tokens remain separate, with F13 fixed and all four on the accepted rear clock. Seventeen additional fixed specifications use the same atomic local consumption, full output promise and work rules. An explicit new-session action constructs essential or expanded access with no granted goods. Menus group hauling outputs rather than expanding common headers; ingredient totals bound confirmation text while retaining complete receipts.

## Heavy output boundary -27October2026

The [heavy foundation](heavy_production.md) adds ledger-owned rear-hull admissions and physical carrier/heavy-object identities, with canonical properties supplied by production. Small output lifecycle hooks preserve the accepted fixed work/consumption path while F10 owns slot-based bay/parking promises. Shared selection retains confirmation and recipe histories. Finished objects keep a latched occupied bay; G07/G12 must later integrate actual clearance, with no generic stock move or cancellation substitute. Explicit finite parking coordinates validate footprint/claim legality without claiming route/driver integration.

## Connected F06 training -27October2026

The [training service](training_courses.md) owns elapsed course progress/physical seat reservations and consumes actual instructor coverage on the existing rear event clock. Ledger Training assignments exclude students from industrial rebalancing, while safe carries and instructor staffing reuse existing rules. Qualification completion updates the same person and grants no gear. The recovery purchase reuses the shared personnel route/admissions with a one-person cohort; normal eight-person procurement retains its path and prices. Declared recipe availability supplies course access independently of selected production.

## G05 rear construction - 28 October 2026

The [G05 construction service](g05_construction.md) reserves real bounded sites and delivers M11 through the accepted hauling and ledger lifecycle. Independent F02/F06/F07/F10/F11 copies extend their existing physical service and dispatch owners on the common rear clock. Local eight-metre road checks preserve vehicle access; dismantling waits for goods and active commitments before twenty builder work seconds and physical salvage. The catalogue and focused regression keep these decisions inspectable without a new global inventory or mission mode.

## G15 military organization - 29 October 2026

The [G15 organization service](g15_military_organization.md) composes real HQ receipts, physical issue jobs, roster reports and military hulls into the GDD §11 hierarchy on the shared event clock. The identity ledger remains authoritative for people, goods, crew and passengers. Formation and artillery equipment claims remain observable until actual report; readiness cannot replace a missing minimum package. The Dispatch view exposes hierarchy and shortages without player formation controls.

## G16 combat, wounds and morale - 29 October 2026

The [G16 combat service](g16_combat_wounds_morale.md) uses the G01 physical ledger, G08 sight and cover, and G15 actual rosters on the shared event clock. The ledger owns loaded-round consumption, injury, death and recoverable dropped holders; combat owns eligibility, commitments, stress, care and cohesion. This boundary keeps G23 mounted weapons, G27 full medical logistics and G32 persistence as explicit later integrations.

## G17 hierarchical orders and information - 29 October 2026

The [G17 order service](g17_hierarchical_orders.md) observes through real G15 members and G08 visibility, then carries time-stamped contacts and intent across one-second echelon links on the shared clock. It decides a supported flank from delivered information, G16 eligible fire, real ammunition, geometry and cohesion. The enemy HQ assault gate reads actual company capability and supplies an explicit preparation demand; it does not grant units or goods. An inspection scene exposes message age, roles, fallback and physical reconciliation.

## G18 objectives and income - 29 October 2026

The [G18 objective service](g18_objectives_income.md) derives eligibility from G01 actual holders and ammunition plus G16 morale, integrates capture at event boundaries, and credits controlled uncontested resource income to G02's existing requisition account. Its staged T02 passenger review proves a parked occupied vehicle contributes no capture before the same people exit; no objective ownership implies an HQ result or free depot contents.
