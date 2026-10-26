# G02 procurement and receiving

Scope: [issue #10](https://github.com/TheInfinityIQ/Trencho_V4/issues/10), M0; GDD sections 3–5, 8, 10.2 and the dated section 23.3 admission clarification. Implementation follows [the pre-implementation plan and review correction](g02_receiving_plan.md). This is a bounded rear-economy review fixture built on accepted G01, with native interaction verification still pending.

## Behavior and authority

The Terminal quotes the nine purchasable materials at their documented one-kg unit prices. M06/M11 are refused. A basket is deterministically packed into trucks of at most 5,000 kg, displaying goods plus a 20 transport fee for each vehicle before purchase. The entire quote, current money and all vehicle places are validated before any debit. The review UI selects one material at a time; the service also accepts mixed baskets. Initial 2,500 requisition is fixture setup; elapsed baseline income is 6 per second.

Resources reach the supplier gate at purchase +60 seconds; the standard eight-P00 order costs 120+20 and reaches its gate at +90. Before five seconds, cancellation refunds the full selected vehicle price and releases only its reservations, once. At exactly five seconds dispatch has occurred and cancellation fails without changing state. Split resource purchases have separate vehicle records and can be cancelled separately during their refund windows.

One freight berth plus ten shared off-map waiting places admits eleven unfinished freight vehicles total, including en-route commitments. Personnel has two independent unfinished vehicle admissions. Neither pool gains places at arrival. Berthing, disembarking and departing continue to occupy admission; release occurs only on valid cancellation or physical clearance at the end of the supplier's exit path. Completed supplier carriers and qualified P08 drivers remain external identities, never player fleet or recruits.

Incoming people reserve eight places before debit. GDD 10.2 applies to external manpower as confirmed during draft review: each stopped supplier vehicle completes one passenger exit per second, excluding seated crew. The first exit takes a full second after stopping, the eighth eight seconds. Each same P00 identity stays aboard until their exit handling completes, then walks at 1.5 m/s into F08 Personnel. Only actual F08 arrival makes that person available and converts their own incoming reservation. Two supplier vehicles handle independently, and each remains admitted through its last passenger's F08 arrival and physical clearance. Actual rear people plus incoming places cannot exceed 120 in this rear-only model. D03's forward/strategic capacity membership is not inferred.

For one order purchased at t=0 in the predefined first pull-off, stopping completes at 91.066667s. The first/eighth exits complete at 92.066667/99.066667s; each walk takes 7.771236s, so first/eighth F08 arrivals occur at 99.837903/106.837903s. Clearance completes at 108.704569s. At t=91.1 all eight remain aboard; at t=99 only seven have exited and none are available. At t=100 exactly one is available and seven incoming places remain reserved. The second pull-off has its own approach and clearance distances; it does not wait for the first vehicle's handling queue.

F02 has four unloading positions and 5,000 kg of storage. Assigning a position selects an actual available player person. Each job reserves one source claim and its output space before approach/pickup, then walks unburdened at 1.5 m/s, picks up for two seconds, carries one material type at most 25 kg at 1.2 m/s and drops for two seconds. Goods become local stock only after completed deposit. Full storage leaves the remainder aboard. Supplier drivers and incoming passengers are ineligible workers.

Receiving and Personnel use their GDD centres at (45,25) and (20,90) metres. The predefined local lanes, berth/pull-offs and exit endpoints are fixture geometry; they retain travel time and separated access without choosing production world presentation or implementing general navigation/traffic. Supplier yard movement uses T01/T02 road speeds of 12/15 m/s. The external transit leg is represented by timed supplier positions outside the local yard.

## State ownership and interruption

`ReceivingSimulation` owns requisition/income/refunds, simulation time, orders, admissions, incoming-place counts, workers, destination reservations and timed activities. G01's ledger owns physical people, carrier/stock identities, holders, positions, owners/controllers, exclusive duties and source claims. UI snapshots are detached copies; the interface does not maintain a second authoritative stock or staff count. The chronological event clock handles boundaries within a large time advance; elapsed time cannot skip pickup/drop or release a place early.

Releasing Receiving duty before pickup cancels that job and returns its own source/output reservations, leaving goods aboard. Releasing during Carry/Drop leaves the old duty active with a pending Available assignment until safe deposit completes. Repeating the release request cannot duplicate a handoff. Valid pre-dispatch order cancellation creates no dispatched goods/passengers to remove. Purchase/rejection and refund changes are synchronous; audits reconcile physical stock, money and reservation limits.

No save/load format is introduced. G32 must persist both owners together: simulation/ledger clocks, money totals, order lifecycle/admission/slot flags, immutable purchase cargo and costs, deposited counts, incoming reservations, per-vehicle exit progress/next exit time, stable carrier/driver/passenger/stock IDs, ledger holdings/claims, worker job/source/output reservations, phase/path/start/end times, independent passenger walks and ID sequences. Restore must validate these references and rebuild occupied slots from the persisted lifecycle without re-debiting, redispatching, recreating people/cargo or releasing reservations twice. Required future round trips include pre-dispatch cancellation, queued freight, partial unloading, active carries with pending reassignment, passengers partway through staggered exit handling with others already walking, and supplier clearance.

## Verification recorded 26 October 2026

Steam Godot `4.7.2.stable.steam.ed1daf0bf`, Windows, using `./tools/check.ps1` with the installed executable:

| Check | Actual result |
| --- | --- |
| Project import and headless main-scene startup | Pass, no engine/script errors |
| Retained G01 regression | 14 cases, 624 checks, zero failures |
| G02 domain regression | 16 cases, 842 checks, zero failures |
| Engine-driven interface signals and geometry | 190 checks, zero failures; 960×540 physical window / 1280×720 logical viewport |
| Native input/readability and A04/A58 walkthrough | **Pending: Windows desktop access blocker** |

The domain tests cover catalogue prices, mixed/split quotes, atomic invalid/unaffordable/over-capacity purchases, cancellation at 4.999 versus dispatch at 5 seconds, eleven-versus-twelve freight commitments, independent two-vehicle personnel admission, population reservation, A04/A58 model recovery, partial storage, safe duty interruption, physical clearance, time partitioning and fixed-seed mixed operations. The added cadence cases check before/at every passenger exit and F08 arrival, full walking time, aboard/walking/unavailable identities, per-person reservation conversion, parallel vehicles and independent clearance. They reproduce the draft review's timing defect on the earlier simultaneous-exit implementation. Arrival guards refuse passengers still aboard, repeated admission and supplier-driver recruitment. G01 accounting remains exercised unchanged alongside the new cases.

The interface test invokes actual control signals and inspects resulting state and visible-control bounds across populated tabs, cancellation, recovery and split quotes. It also checks distinct aboard/walking labels, exit versus F08 arrival counts and staggered reservation conversion through the visible clock buttons. It caught and corrected a wrapped quantity-label layout overflow. It does not send OS input, inspect rendered readability or prove native gameplay. Local logs and the generated interface summary are under ignored `.artifacts/`; CI runs the same command.

The interactive Godot process started with Compatibility/OpenGL without engine errors, but native window activation failed, followed by `GetCursorPos failed: Access is denied. (0x80070005)` and a black window capture. Input attempts stopped; the human was asked about desktop availability. Do not infer a successful native walkthrough from launching the process or the engine checks. The Game Designer authorized a draft PR for parallel review; issue #10 and A04/A58 native acceptance remain open until the missing verification is supplied or an explicit later design/human decision changes that requirement.

## Pending native walkthrough

Run F5 after desktop access is available. Time advances only through the buttons; it does not elapse while reading the fixture.

1. **A04 and passenger cadence:** Reset, purchase the default 100 kg M01, advance +60 then +10 seconds. Check the Deliveries tab: one berthed external truck, 100 aboard, zero deposited/free, and a missing-unloader cause. Order eight P00. Advance +60, three +10 steps and three +1 steps (purchase +93s): exactly one passenger should be walking, seven aboard, zero available and eight places reserved. Advance +10 (purchase +103s): four available at F08, four still walking/reserved. Advance +10 (purchase +113s): all eight available and the supplier cleared. Inspect separate supplier drivers, exit/F08 counts, identities, positions and labels throughout. Assign four available people in People & labour. Advance +60: 100 kg should be carried with zero free. Advance +10: 100 deposited/free and physical freight clearance complete.
2. **A58:** Press “A58: fill freight queue”. It executes eleven real one-kg purchases and advances 63 seconds. Confirm one blocked berth, ten waiting, eleven aboard, zero workers and zero local stock. A twelfth freight purchase must fail without debit. Order eight P00 through the independent personnel pull-off, advance +60 twice, assign four actual people, then +300 and +60. Confirm all eleven kg deposited, all freight admissions cleared, exactly eight player people and external supplier services.
3. **Quote/refund:** Reset; enter 5,001 kg and inspect both priced trucks in the quote scroll area before an unaffordable purchase refusal. Reset quantity to 100, purchase, cancel the selected delivery before advancing time and repeat cancel: only one refund. Buy again, advance five +1-second steps and confirm cancellation is refused after dispatch. Check tab selection, scroll areas, feedback and readability at normal size and 960×540.
4. **Interruption:** After A04's +60-second carry observation, release Receiving duty. Inspect pending Available assignments while stock is carried, then +10 seconds for safe deposit and completed reassignment. Repeat release during an approach in a fresh run to confirm source/output space returns while cargo stays aboard.

Partial storage, exact sub-second boundaries, population saturation and two simultaneous personnel services have engine regression evidence; a fixture-level native extension is still needed to observe those cases directly. No native screenshots are supplied as passing evidence.

## Integration limits

General staffing/hauling is G03; production G04; additional facilities G05; courses/instructor recovery G06; strategic emergency contracts and dispatch G12; card selection/bundles G31; persistence G32. World movement/traffic and production presentation remain their own scopes. This fixture does not claim those systems, full D03 capacity integration, a complete playable engagement, or native A04/A58 acceptance.
