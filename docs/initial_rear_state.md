# GDD20.1 rear opening

`BaseSimulation.new(expanded, world_session, true)` opts into the GDD20.1 rear package. The first two constructor arguments retain their existing meanings; the third defaults to false so diagnostics keep their twelve-person, empty-stock base.

The initializer runs at time zero, paused with2500 requisition. It creates42P00,12P01 and6P08; seats three distinct P08 in two T01 and one T02; sets the declared staffing and production targets; supplies the eleven depot material quantities; and registers the second F11 at(80,145), yielding eight total parking places. Initial workers are physically at their assigned entrances. No students, weapon output, manufacturing order or heavy recipe selection is granted. Selecting a heavy recipe subsequently enables its existing order flow.

The opted-in Rear omits the G03 `yard-t01` fixture. The three starting vehicles use the normal ledger tank and VehicleActivity ownership, parking, crew, refuelling and Dispatch paths. `fuel_initial` records their120 starting tank units separately from worker-loaded fuel and200 loose depot M08. Tank conservation includes initial fuel; loose-stock conservation continues to count only fuel actually loaded from stock. No runtime replenishment or transfer is implied by scenario initialization.

The focused `game/scenario/tests/rear_start_regression.gd` checks exact people, qualifications, duties, goods, tanks, parking and initial recipe states, shared audits and a real dispatch admission. It is registered in `tools/check.ps1`. This is rear initialization evidence; battlefield initialization, generated-world access and observed playable delivery remain integration obligations under#83.
