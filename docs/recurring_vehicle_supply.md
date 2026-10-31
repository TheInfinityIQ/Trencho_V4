# Recurring vehicle supply

## Accepted next outcome

The Designer's 31 October decision applies the vehicle-wide GDD 16.6 supply rule, with the APC as the first connected recurring route. Urgent ammunition is strictly below 25 percent of each actual mission target, never 25 percent of maximum capacity. Armed vehicles need their matching ammunition; unarmed transports have fuel needs and no invented ammunition demand. Applicable route/fallback/reserve, actual crew, capacity, ownership and safe access remain required.

For this opening, the existing T04 mission target is 180 actual E26 rounds, maximum 240 including loaded rounds once. After genuine depletion below 45, the same APC requests an acknowledged feasible return along its declared support fallback to blue-delivery. Existing Engineer couriers issue physically available ammunition there. Withholding or partial delivery leaves the actual deficit open; reaching 45 does not release it. Actual receipt to 180, cleared physical handling and a current acknowledged valid support order permit redeployment. A later shortage can repeat. No new enemy, forced shot, chase, teleport, supply grant, range or safety exception is introduced.

The player must see the vehicle, actual aboard amount, deficit, rendezvous, courier commitment and useful action. Unloaded local stock, goods still on a delivery vehicle and rounds already aboard remain separate. A replaced parent assignment cannot be revived merely by replaying a cached opening descriptor.

## Implementation plan and acceptance

- Keep authoritative goods, fuel and timed handling with the existing ledger, ForwardSupply and RackIssue owners. OpeningResupply schedules recurring requests separately from historical initial-allocation credits.
- Keep real movement with TroopTransport. VehicleDeployment requests each named return/support phase through current parent delivery and acknowledgement, preserving actual hull/job identity and existing route/fuel checks.
- Use the military owner's narrow shared needs query for matching ammunition/mission targets and declared fuel needs. It creates no stock, route or physical replenishment service.
- Track the opening's own issued/relayed intent identities, so a replacement is respected and a failed relay can retry without recreating a superseded order. No new mission framework or cancellation API.
- Verify only the new connected action briefly on GitHub. No regression fixtures, old opening replay, coverage matrices, profiling or local engine run.

Acceptance for this increment is the same-hull urgent return, physical refill to target, honest withheld/partial-supply waiting and fresh valid support redeployment. Initial lifetime deposits and in-flight commitments cannot fabricate actual replenishment or a completed cycle. Interruption preserves the same carried portion and existing physical commitments.

Reaching the current rack target is not a permanent scheduler handoff. The same named refill remains open for topoffs until actual support departure is admitted, then the deployment owner releases that scheduler request. Already-named acknowledged departure readiness is consumed at the shared settled boundary before routine mounted fire, including fractional receipt/acknowledgement boundaries. This creates no new strategic turn, target or firing exception; failed movement retains existing route/fuel/safety requirements. Readiness attempts are deduplicated rather than replanning blocked routes every frame.

The same boundary can record a once-per-cycle actual target-receipt milestone before ordinary fire spends another round. Normal policy may then reassess/propose support after that real receipt; current actual target and courier clearance are still required again at departure. The live Base explicitly gates vehicle departure admission while paused, including immediate management-command settles. Recording a receipt milestone does not bypass Pause or turn historical deposits into current ammunition.

## Main-game coverage and remaining work

| Vehicle | Applicable supply | This increment |
| --- | --- | --- |
| T01 resource transport | Actual M08 tank fuel and applicable route/fallback/reserve; no ammunition | Existing physical route/fuel admissions retained. General forward fuel service remains unfinished. |
| T02 troop transport | Actual M08 tank fuel and applicable route/fallback/reserve; no ammunition | Existing physical route/fuel admissions retained. General forward fuel service remains unfinished. |
| T03 technical | Its mission E02 target plus actual fuel | Shared needs query; recurring forward physical connection remains unfinished. |
| T04 APC | Its mission E26 target plus actual fuel | First connected ammunition return/refill/redeployment cycle at the authored stop. Forward fuel replenishment remains unfinished. |
| T05 tank | Its mission E25/E02 targets plus actual fuel | Shared needs query; recurring forward physical connection remains unfinished. |

The GDD 16.7 consumption/lead-time forecast planner is still required. The first short-foot [Rifle collection/refill/current-order return connection](rifle_collection.md) is now implemented; its longer-distance transport comparison remains unfinished. Campaign, persistent engagement state, remaining maps and other outstanding GDD connections remain required; this increment does not complete the main game or certify desktop responsiveness.

## Current direct evidence

Production revision `457f2a9477c3185fd71802396f3d2019f97bd1a1` passed [one brief GitHub demonstration](https://github.com/TheInfinityIQ/Trencho_V4/actions/runs/41198843926): 1,020 returned frames, about 102 simulation seconds and 13.563 seconds of demonstration wall time. No regression suite, old opening replay, local engine or profiler ran. The Principle Engineer source-reviewed the shared boundary and receipt/departure changes.

The script declared its starting people, vehicles, inventory and completed Fleet Transfer receipt; it did not demonstrate their upstream manufacture or transfer. Production movement took the actual three-crew APC to a short authored support position with 180 E26. Accounted ledger consumption of 136 left 44 and opened a named urgent cycle. The same APC physically returned under real parent order delivery/acknowledgement. Actual Engineers issued the 100 local rounds, leaving 144 aboard and 36 missing; withholding further stock retained the unfinished cycle and held the APC.

A real T01 then loaded, transported and unloaded the existing 37 HQ rounds and returned. Engineers filled the APC to 180. One accounted consumption after actual receipt left 179; the same open cycle topped off that deficit. A fresh acknowledged valid Support phase admitted real movement, released that refill and returned the same APC to support with 180. Later accounted consumption of another 136 opened a distinct cycle with 44 aboard and 136 still needed; the old receipt could not complete it. All 317 declared E26 were accounted for as 273 consumed and 44 remaining. The later cycle's need was demonstrated, not a second completed refill.

This demonstrates the newly connected action on short safe authored routes with controlled ledger consumption, not autonomous combat, a first shot, full-size opening pacing, visual interaction, native Windows responsiveness or requested-speed throughput. The demonstration used an explicit elapsed-time clock. Existing synchronous reposition route assessment remains a blocking-cost limitation; the result is not a general latency guarantee. UI wording was source-reviewed; rendered layout and interaction remain unverified.
