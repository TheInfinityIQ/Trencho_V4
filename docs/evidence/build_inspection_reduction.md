# Build inspection reduction and GdUnit4 verification

## Changed reads

Build now uses `construction_view()` instead of the broad management snapshot.
It updates its own site list, construction progress/staffing, material source
and resource display. Hidden production, training, vehicle, workforce and HQ
panels are no longer populated by the Build refresh.

Rear-map drawing and picking now use detached `map_markers()` containing only
the marker fields needed by those operations. They do not export full entity
inventories, crew, masses or claim/event histories. Positions still use the
ledger's authoritative world-position resolution; markers are not cached.

Staffing counts read direct duty facts. Rear population and recovery-instructor
availability use narrow ledger predicates instead of building inspection
dictionaries for every person in both armies. These changes do not reduce game
speed, skip simulation frames or suppress the call counter.

## Measurements on this computer

The same direct, synchronous Build refresh measurement was run before and after
the change on the default opening. These are individual measurements, not a
statistical benchmark:

| Measurement | Before | After |
|---|---:|---:|
| Full `inspect_entity` entries per refresh | 1,251 | 1 |
| Full ledger snapshots per refresh | 1 | 0 |
| Full simulation snapshots per refresh | 1 | 0 |
| Refresh time | 41.253 ms | 1.111 ms |

An independent two-second 1x Build observation recorded approximately 4,332
and 4,291 inspections per second, with a 38.347 ms peak frame. It completed its
limited one-menu observation below the default budgets. Logs:
`logs/menu-performance-2026-11-02T17-51-51-38316/`.

The remaining inspections include simulation work over multiple entities;
there is no requirement that this method's count equal the 60 Hz callback rate.
This measurement does not establish that all remaining reads are necessary.

## Formal tests

Pinned GdUnit4 6.2.2 was actually run in an isolated project. Both read-path
guards passed with no errors, skips, flaky cases or orphans. The Build guard
recorded one full entity inspection at 1x. The staffing guard checked twelve
workers across sixteen duties with zero full inspections from its count helpers.

The full three-case run then **failed as intended on a remaining concern**:
a 136.878 ms frame, above the 100 ms limit, during the Build rotation
observation at 1x. It stopped after approximately 1.061 seconds in that action,
recorded 6,264 inspection entries across that interval, and preserved the pending
actions. The delay occurred during the observation window; this is not a
measurement of the rotation handler's own duration.

The two guards passed; the live performance case failed. Therefore the full
suite is not green and later menus/actions are not certified. Report:
`logs/gdunit4-performance-2026-11-02T17-57-12-21236/gdunit-report/results.xml`.

A subsequent run also exercised explicit assertions that a stopped sweep has
speed zero and session physics disabled. Again, the first two cases passed and
the live case reported one performance failure with no runtime errors, skips,
flaky cases or orphans. This time the first over-budget frame was **162.232 ms**
during the Open Build observation, at 1x. The varying trigger location reinforces
that a frame-interval failure identifies an observation window, not the CPU
cost of that menu handler alone. Latest report:
`logs/gdunit4-performance-2026-11-02T18-02-16-15532/gdunit-report/results.xml`.

The native log-capture path now uses an explicit process-specific log file so
it cannot overwrite the test log with an unrelated running editor's default
log. No framework/editor plugin was enabled in the main project.
