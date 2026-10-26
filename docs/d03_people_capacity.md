# D03 people and capacity decision v0.1

Authority: [Game Designer decision on D03 #44](https://github.com/TheInfinityIQ/Trencho_V4/issues/44#issuecomment-6414794033); [documentation assignment](https://github.com/TheInfinityIQ/Trencho_V4/issues/44#issuecomment-6414794264). Sections 1–7 reproduce the adopted contract, including its historical review record. Sections 8–10 provide the lifecycle matrix, independently checked reference fixtures and validation limits. This document governs the earlier ambiguous membership/admission wording identified in GDD 23.2; its numerical defaults still require later playtesting. No runtime system or acceptance is introduced.


Game Designer decision adopted on issue44, 26 October 2026. This published contract governs the canonical documentation assignment; D03 remains open until that documentation is reviewed and merged. Resolves O1-O8 in the [engineering proposal](https://github.com/TheInfinityIQ/Trencho_V4/issues/44#issuecomment-6411657425). This is a behavioral contract and reference matrix, not software architecture, implemented gameplay or approved balance from playtests. The existing GDD catalogue and physical movement rules continue; the specific clarifications below govern contrary ambiguous wording when published.

## 1. Independent capacities, one physical identity

Each living person has one stable identity, actual location/holder, controller and exclusive duty. Reporting, boarding and transfer are phases, not extra concurrent jobs. Ownership, army membership, duty, physical location and capacity claims are distinct facts. A destination claim neither moves nor creates a person. Unique people are never obtained by adding the separate capacity columns together.

| Capacity | Included | Excluded / release |
| --- | --- | --- |
| Rear population120 | Physical rear people; away returning Strategic Delivery crew's held home places; purchased incoming recruits/instructor and other accepted rear return admissions. One rear claim per person or intended recruit. | A person's occupied/home/incoming columns are mutually exclusive. Non-returners release on actual rear-boundary departure. Returning crew hold home until real return or confirmed death. |
| Military384 | Every living non-exempt military member, including HQ unassigned reserves, all crew/service/formation people, forward transfers, injured/incapacitated and recovering people, plus committed new entrants not yet handed over. | Original fixed HQ five and transient external service drivers. A living casualty does not open a new admission. Membership and incoming commitment are mutually exclusive for one identity. |
| HQ unassigned reserve96 | People actually on HQ Reserve duty and short-lived inbound claims granted for their actual receiving/discharge movement. | Not all people geographically near HQ. HQ defence squads, assigned crew, service staff, patients and returning rear/service drivers do not use it merely by proximity. |
| HQ recovery12 | Occupied treatment/recovery places, including medically complete people awaiting lawful discharge, plus accepted inbound patient claims. | Medics are staff, not beds. Aid-post places are separate local capacities. No unbounded discharge waiting area exists. |
| Passenger seats / crew stations | Actual occupant or named incoming claim for that particular seat/station. | Distinct pools; one person never occupies both. Incapacitation or death does not make a physically blocked position usable. Real exit/extraction/ejection resolves physical occupancy; release of living admission on death is a separate event. Bodies/gear still need the catalogue payload allowance. |
| Formation roster / replacement intents | At most eight assigned combat roster members plus reserved incoming replacement places per ordinary squad; specialist minimums remain type-specific. | Evacuated detached casualties remain army members and history, not extra active roster members. Pending replacements are not active squad members before rendezvous. |
| Rear strategic fleet8 | Owned rear hulls, including travelling Strategic Delivery and outgoing Fleet Transfer hulls until actual HQ handoff; reserved new hull production admissions. | Physical parking is an additional requirement. A travelling hull can free its parking bay without freeing its owned-fleet slot. |
| Military fleet24 | Live military hulls plus incoming Fleet Transfer/finished-package hull commitments. | Rear Strategic Delivery and external leased service hulls. Crew/person capacity is checked separately. |

Numerical caps apply to occupied plus held/incoming claims within that domain. Multiple domains may legitimately constrain one identity: a rear person staging for deployment holds one rear place and one future military admission, without becoming two people. HQ reserve/recovery places are local subsets of the same military people, not additional recruitment allowances above384. Rear/service patients can use local care without being recruited into the army.

Initial physical player ledger is60 rear+52 battlefield=112, excluding supplier/leased drivers. Rear60 already includes three strategic drivers and two instructors;49 assigned+11 available=60. Battlefield52=40 infantry+5 military vehicle crew+2 flexible recovery medics+5 original fixed HQ people. Initial counted military membership is47; original-five exemption5; incoming military0. HQ unassigned reserve and recovery patient occupancy both start0 because all52 have declared active duties. Starting rear fleet3, military fleet4; no incoming hulls. The two recovery medics count among47 and occupy no recovery beds as staff.

## 2. Commitments and normal receiving (O1-O3)

An editable uncommitted manifest preview holds no military capacity. Accepting a dispatch manifest selects eligible real people and reserves military admission for every new committed passenger and, for Fleet Transfer, every real transferring crew member. It reserves an incoming military hull for Fleet Transfer. Do this before treating the manifest as accepted; no payment/physical promise succeeds by overbooking. A person cannot be committed to two manifests. Edits atomically exchange only affected claims after checking the new totals; failed edits preserve the previous accepted manifest. Revalidate actual seats, crew, payload, route, fuel and claims before departure. This does not require all of those preparations already complete when a staging manifest is accepted.

Enemy finished-package purchases reserve all new military people and transferring hulls before debit, including during preparation. All accepted entrants keep their claims through transit, blocked arrival, injury and safety stops until actual handoff, lawful pre-handoff withdrawal/readmission or death. Existing military transfers never acquire a second incoming-member claim. A driver-only legal transfer reserves only its actual driver, not imaginary missing combat crew. Missing combat crew still prevents combat deployment under existing rules.

Do not reserve ordinary HQ96 places at rear manifest acceptance. HQ grants a particular receiving place immediately before that person's safe exit/walk or extraction to it. The place remains claimed through that movement and converts to occupied on actual receipt. A blocked HQ can therefore leave passengers aboard even when their military admission was secured earlier. No unreserved mid-walk gap is allowed. Per vehicle, one healthy passenger completes disembarkation per second; each walks independently; seat occupancy ends at the actual exit, but army handoff occurs only at actual HQ receiving arrival. Incapacitated people need real extraction/transport instead of self-walking.

New healthy passengers normally enter HQ Reserve on receipt: incoming military minus1, member plus1, reserved HQ place becomes occupied. Passenger physical disembarkation starts the receipt movement; it alone does not make a walking recruit available for formation issue. A patient can be handed directly into accepted HQ recovery: the same incoming-to-member conversion occurs there and uses no HQ Reserve place. Return crew and external drivers retain their original affiliation/control unless an explicit already-authorized transfer applies.

Fleet hull/crew handoff is an actual receipt at a stopped, legally accessible HQ receiving position accepted by HQ command. On that event the same hull's incoming military slot becomes a live military slot, its rear fleet slot releases, and each actual transferring crew member's incoming admission becomes membership. Seated crew remain in their real stations; they do not have to pretend to become HQ reserves. Passenger receipts are individually independent and may still be blocked afterward. No remote gate-entry/timer handoff; capture/missing command/unsafe access can block it. Transferring an incapacitated crew member does not restore their capability or empty the station. Required vacant positions remain vacancies. Strategic Delivery hulls/returning crew never undergo this handoff.

## 3. Rear continuity, cancellation and safety return (O5)

Rear people remain occupied rear places while reporting, boarding and waiting to depart, including those aboard a vehicle still inside the rear. At actual rear-boundary departure, a returning Strategic Delivery crew member converts occupied to held home; a non-returning passenger or Fleet Transfer crew member releases their rear place. Incoming military claims persist. A returning crew home claim converts back to occupied on that same person's real rear arrival; it needs no new recruitment space.

Predeparture cancellation withdraws its incoming military/hull commitments once and frees unoccupied seat/station reservations. People already aboard and goods already collected still require real unboarding/unloading/return work; occupied rear places and occupied seats do not vanish with cancellation. Commitment release does not give an occupied seat to another passenger. Repeated cancellation cannot repeat release/refund. Mode edits never silently commandeer a returning hull/driver.

Departure cannot be cancelled/refunded this trip. A safety return following the existing safe-route rule is physical movement. A non-returner has no guaranteed rear home place after departure. Before crossing back into the rear, obtain a free rear incoming admission for that person; if none is free, they wait at an actual safe receiving/holding position or aboard their carrier outside the rear, with an explicit Rear Full reason. Keep the incoming military claim while waiting. On actual readmission before military handoff, convert rear incoming to occupied and explicitly withdraw the unfulfilled military commitment once; the same person may resume an eligible rear duty after its safe handoff. Reserving readmission without actual entry does not withdraw military commitment. If a planned return is revised while still outside, release that unused rear return claim and retain the military commitment. No new queue teleports, forced deaths, automatic home guarantees or population overflow.

For a Fleet Transfer hull returning before HQ handoff, keep its existing rear fleet slot throughout. Its incoming military hull claim releases once only on actual lawful rear hull receipt with explicit withdrawal of that unfulfilled transfer; a named transfer intentionally remaining active retains its claim instead. The return needs a real legal parking/receiving position, not a second rear fleet slot. A hull cannot cross into the rear carrying a person without that person's held home or accepted rear incoming place; its existing fleet place does not override population admission. Driver/passenger rear admission and military-commitment withdrawal are separate individual receipts; withdrawing the hull's transfer does not release people still outside or create replacement drivers. No transport fee/fuel refund or rewind follows the safety return. A hull already handed to military command is not eligible for this pre-handoff withdrawal.

After actual military handoff, people cannot revert to rear labour during that engagement. Ordinary military retreat/reorganization returns to battlefield HQ/forward services, not the industrial rear. The pre-handoff safety-return procedure is not a recruitment reversal for existing military members. A stranded/ejected new entrant retains its incoming admission and rear-managed commitment until real HQ receipt or permitted rear readmission; a destroyed hull alone does not finish the person's transfer. No automatic military takeover of a stranded rear Strategic Delivery crew/hull occurs.

An injured/incapacitated returning rear crew member keeps their rear home hold and affiliation. They may receive medical care at a real HQ/aid-post place without acquiring military membership or HQ Reserve duty. After completed care they need an actual transport/qualified driver and lawful movement home, with home hold retained through it. Death releases only that person's home hold. The physical hull can be destroyed while its surviving rear driver still holds a home place.

## 4. Wounds, care, roster release and fixed people (O4/O6/O7)

Active injury preserves duty until actual medical reassignment. Incapacitation changes duty to Wounded, first aid to Recovery, under the existing care rules. Both retain their living military membership, incoming commitment or rear home claim as applicable. No injury-based recruitment or fleet slot refund. Loss records occur only on confirmed death, once.

Confirmed death releases that identity's living military membership OR incoming commitment, relevant rear occupied/home/incoming place, combat roster place and unfulfilled destination admissions once. It does not release another survivor's claim, invent a military-member decrement for an external driver, or refund an irreversible trip. Record the death in the appropriate military/rear/service/source-order ledger; an external incoming person is not retrospectively an arrived military recruit. Where a corpse or retained gear still physically blocks an intact seat, crew station or care bed, that position stays unavailable until real removal/clearance. Report this physical blockage separately from living people and reservations; zero living patients does not promise an obstructed bed is usable. Actual body removal uses the existing casualty extraction/carry limits (80kg plus retained gear and real handlers/transport), without treatment or a medical pack. Death alone does not reduce a still-carried body's gross mass. No new ground-corpse collision rule is introduced by this vehicle/care-space clarification. Destruction W4 frees positions through actual ejection/relocation or loss of the hull, not by pretending a still-present dead occupant was extracted.

A planned vehicle evacuation must reserve its actual destination recovery place before departure, in addition to real seats, payload, carriers/crew and route. The reservation persists until receipt, explicit lawful reroute with a replacement receiver secured, or that patient's death. A route cut preserves people and their still-required claims. Admission to a bed converts incoming to occupied. No bed is claimed as occupied while the patient is aboard. Medical need arising after travel/while already at HQ is an emergency receiving problem: seek a free real place; otherwise the patient remains at their physical location, with bleeding/care rules still applying. This does not authorize a planned evacuation without receiving capacity. Each S08 aid post has its own eight patient places and actual staff/care supplies; those are not part of HQ's12.

After30 cumulative seconds and the specified pack, a completed patient remains Recovery and occupies their bed until a legal receiving duty/position is secured and the person physically exits that bed. If no destination is available, show Medically Complete - Awaiting Destination; no second pack or extra care time is charged. Routine discharge uses HQ Reserve96 with a claim before movement. Direct discharge into a particular legal staffed formation/crew/service duty is allowed with that actual roster/station position reserved and a real report/rendezvous; no mandatory detour through full HQ Reserve. This military direct-discharge permission applies to existing members, or entrants after their required actual HQ handoff. Forward aid-post care, rescue custody or proximity to an open squad never converts a pre-HQ entrant's incoming commitment remotely. A stranded pre-HQ entrant treated at an aid post retains that commitment and proceeds by real transport/escort to lawful HQ receipt or the permitted pre-handoff rear readmission; the care handoff itself does not enlist them. A returning rear crew member uses their held-home/actual transport path, not HQ Reserve. Do not order a completed patient out of an occupied bed into undefined overflow to admit another patient. Physical travel to a distant duty cannot be skipped; the new receiver claim persists through it.

The original fixed HQ five are five identified people, not five renewable job exemptions. Their exemption follows those original identities for the engagement, including care and any otherwise lawful assignment; it grants no qualifications or new duty permissions. A dead original leaves a recorded loss; a replacement recruited from reserves is an ordinary counted military member even in the same HQ job. The two flexible recovery medics and all later service replacements are counted normally. Thus no rotating people through a fixed job manufactures an exemption. Commander succession still uses actual existing people and the GDD hierarchy rules.

A living incapacitated squad member retains their roster place until confirmed death or an acknowledged medical detachment. Medical detachment requires a real named care/evacuation receiver to take physical care/transport custody, or actual admission at a recovery service; merely requesting a medic is insufficient. At that handoff, release their combat roster place once and keep their identity, former-squad reference, equipment/location and military membership. Their casualty association remains inspectable. No medical service capacity or treatment is invented by changing the roster field. A completed detached patient has no guaranteed former-squad place; they must reserve a currently available position and rejoin physically, or enter reserve/another compatible duty. This prevents a recovering member and their replacement from both claiming one slot.

Replacement intent can reserve a vacant recipient roster place before departure, counting toward its eight-place target. Reserve departure/receipt is a separate physical process; only actual rendezvous activates the replacement. Existing military replacement moves never increase384. Cancellation/disbanding/changed recipient releases only the relevant unused roster intent while preserving the traveller's real duty/location and arranging a lawful new destination. Incapacity alone while waiting uncollected does not free an extra army place or duplicate a specialist.

## 5. Hull and external-service domains (O8)

Rear8 includes live owned rear hulls and accepted new rear-hull production admissions; reserve a fleet place when accepting a new vehicle production order. Its actual parking/collection destination must also be legal before the finished hull is admitted. A cancelled unfinished order releases only its unfulfilled hull claim under existing production cancellation/material rules; the presence of a real completed hull cannot be cancelled out of existence. This is a capacity admission rule, not a production architecture. Fleet Transfer keeps its rear hull slot through departure until real HQ handoff or destruction; it also holds the incoming military24 claim from accepted manifest onward. Strategic Delivery retains the rear slot for its whole trip. Destruction releases the actual hull's live or incoming claims once, not the surviving people's places. Personnel departure and hull ownership handoff have deliberately different release events.

Keep these external-service restrictions separate:

| Domain | Count / lifetime |
| --- | --- |
| Player supplier freight receiving | Approved pending G02 rule:11 accepted unfinished freight vehicles (one berth+ten waiting), including transit, reserved before purchase and held through physical clearance; separate stock claims. |
| Player supplier personnel receiving | Approved pending G02 rule:2 unfinished vehicles total, separate from freight, plus rear incoming people places until each F08 receipt; vehicle admission ends at physical clearance. |
| Player instructor recovery arrival | One pending instructor, with one rear incoming place. Before accepting/debiting the purchase, reserve one of the existing two personnel receiving vehicle admissions as well as that rear place and instructor-pending allowance. It is not a third independent pull-off or a free supplier driver. Pending-instructor status ends at actual instructor receipt, not purchase timer expiry; the vehicle admission persists until physical clearance. Valid early cancellation releases only that order's unfulfilled claims once. This later recovery feature does not change current G02's standard eight-person-only scope. |
| Player Emergency Transport Contract | One active or pending service until its real departure from service with hull/driver accounted, or terminal loss with no living service driver awaiting return. Rear8/military24 and rear/military people caps exclude its external hull/driver. Ordinary manifest passengers and cargo remain fully constrained. |
| Enemy preparation/transit packages | At most3 purchased packages not yet at their actual HQ arrival position, plus at most one new purchase per60s. Every new person/transferring hull already holds its military admission before purchase. Arrival releases this preparation/transit claim, not receiving places or a still-active leased service claim. |
| Enemy battlefield leased delivery services | At most3 reserved/active external leased carriers/drivers across preparation, transit, blocked offload and physical return clearance. Reserve before purchase of A-F or J-M. Hold through unloading and safe return; release after physical service exit, or terminal loss with no living driver awaiting return. G/H/I transferred military hulls use24, not this leased pool. |

The GDD11.1 three-service limit refers to enemy battlefield leased deliveries in this roster; it is not a universal limit on player rear suppliers. An enemy transferred hull can arrive while three leases remain blocked only if its own preparation/transit and military capacity permit. Arrival never dumps passengers/cargo or frees their admissions. Emergency1 is distinct from enemy3; neither can be retained as an owned vehicle or donate a driver.

A lease hull destroyed with a living driver leaves that same driver in external service at their actual ejection location; the service remains pending return until they physically leave by a legal path/transport or die. It cannot be instantly repurchased to create arbitrarily many exempt drivers. The driver can seek safe exit and receive actual rescue/care; they do not join combat formations, industrial work or a replacement crew pool. A surviving empty external hull with a dead/unavailable driver likewise needs real removal/return or destruction before its service is terminated. No completion timer or destruction of cargo alone releases an unfinished living service. All losses are visible in the separate service ledger.

## 6. Acceptance references and boundary fixtures

The developer's W1-W4 become adopted expected accounting after substituting these selected decisions. They remain reference definitions until implemented and observed in their owning feature issues. Required durable fixture record:

1. Starting ledger:60+52=112 physical; counted military47, exempt originals5; HQ reserve0/recovery patients0; rear hulls3/field hulls4. Existing medics/instructors/drivers are included, never added again.
2. Rear W1:108 occupied+4 held+8 incoming=120; receipt4 gives112+4+4; all gives116+4+0; crew return120+0+0. Second eight rejected. Cancellation once, one returning death, and pre-handoff safety-return admission at full versus freed rear capacity preserve identities and totals.
3. Military W2:376 members+8 incoming=384; per-person conversion377+7, all384+0. Existing forward movement of8 remains384. T04 with3 crew+8 passengers fits373+11, fails374+11. Returning Strategic Delivery driver is not ninth entrant. Include mode edit at full cap, failure preserving old claims, predeparture cancellation versus irreversible safety return, and an incoming entrant dying without both M and I release.
4. HQ W3:Q94/C11 and8 aboard (6 healthy+2 newly needing care at stopped HQ). Two healthy plus one patient receive to Q96/C12,5 aboard. Completed original patient cannot leave bed while Q96. Two actual reserve departures giveQ94; physical patient discharge to reserve givesQ95/C11; second vehicle patient givesC12,4 aboard; one healthy entrant givesQ96,3 aboard. Existing membership/incoming claims are conserved. Separately show planned evacuation refuses departure without a real recovery claim, and completed direct roster/crew discharge at full reserve only when a real destination exists.
5. Land loss W4:M200 includes driver100,A100,B50,Cincapacitated plus196 others. Once-only60 injury/80 suppression gives driver/A40,Bincapacitated,Cdead: M199. Actual destruction ejection/relocation or hull loss resolves physical positions; hull minus1. Deep water/no survival kills all4:M196. A returning rear or leased driver uses its correct home/service ledger instead of subtracting an imaginary military member. Hull loss alone releases no living-person claim. In a separate intact-hull fixture, a dead gunner immediately leaves living membership/roster but their blocked station cannot accept another operator or lose corpse/gear mass until real extraction; the replacement must then physically enter and take the3-second station assignment. A care-bed death likewise blocks physical reuse until clearance.
6. Roster:8 assigned members, one incapacitated uncollected -> roster still8; real medical handoff ->7 assigned plus one incoming replacement intent; replacement meets ->8; recovered former member cannot also rejoin at9. Their army membership persists across every nonfatal step. Death/cancel/receipt replay must not free twice.
7. Hull/service limits:rear8 including departing Fleet Transfer still blocks a ninth order until HQ handoff; military23+incoming1 rejects another hull; no lease uses a free military slot. Pre-HQ safety return retains that incoming hull claim until real rear hull receipt plus explicit transfer withdrawal, then23+0; repeating receipt cannot release another hull claim. Rear ownership slot stays held, while each person still needs their own lawful admission/withdrawal. Demonstrate3 leased services blocked at HQ, preparation arrival release distinct from service clearance, successful G/H/I constraints, emergency1 failure with living driver, and supplier11/2 independence. Explicitly show the incoming instructor shares personnel admission rather than inventing capacity.

Expose occupied/held/incoming and available amounts with their real denominators; roster members versus pending replacements; living member versus incoming admission; physical seat/station/bed; actual holder/controller/duty; and actionable blocked reasons. State ownership/claim release must survive cancellation, interruption and save/restore, retaining health/care progress, physical cargo/people, original-five identity and outcome records. Restoring immediately around boundary crossing, receipt, medical detachment/discharge or death must not respawn, refund, release or harm twice. New engagement reset is distinct from within-engagement restoration.

Definition gate D03 closes only after the reviewed canonical document, full lifecycle matrix and reproducible fixtures are merged. G12/G15/G16/G23/G26/G27/G29/G32 and complete A01/A04/A20/A25/A41/A45 continue to own actual gameplay evidence where applicable. No D01 presentation/platform/performance choice, G02 native acceptance, runtime system, neutral party or architecture is introduced by this decision.

## 7. Draft review record

An independent read-only contradiction audit found publication fixes: separate death's immediate living-capacity release from actual clearance of a blocked seat/station/bed; require the instructor's shared personnel-vehicle admission before purchase rather than at dispatch; and specify pre-HQ safety-return withdrawal of an incoming hull admission independently of person receipts. All are incorporated above, with explicit fixtures. It also identified an inferred boundary: forward aid-post care cannot enlist a pre-HQ entrant remotely; the required actual HQ/rear handoff is now explicit. Root independently recalculated12 arithmetic groups spanning the starting ledger, W1-W4, formation216 and vehicle24 limits; all passed. This is reference-definition evidence, not runtime or native acceptance. The independent audit confirmed all four fixes and found no remaining concrete contradiction blocking publication. This publication adopts the definition; canonical documentation, fixtures and downstream implementation evidence remain required.

## 8. Lifecycle matrix — selected accounting

The symbols here are measurement shorthand, not prescribed data structures. All deltas are per named identity unless a cohort size is stated. Unmentioned capacities remain unchanged; different domains must not be summed to obtain unique people.

| Symbol | Meaning / bound |
| --- | --- |
| R_o,R_h,R_i | Rear physical, away returning home, incoming: mutually exclusive per person; sum≤120 |
| M,I | Living non-exempt military members / committed new entrants: mutually exclusive per identity; sum≤384 |
| Q_o,Q_i | Actual HQ Reserve / short receiving claims: sum≤96 |
| C_o,C_i,C_b | HQ living recovery occupancy / incoming claims / physically blocked beds: sum≤12; death may change occupied→blocked without opening capacity |
| A_o,A_i,A_b | Same local care quantities at each S08 aid post separately; sum≤8 |
| S_o,S_r,S_b / T_o,T_r,T_b | Living passenger occupants, reserved places, blocked seats / corresponding crew-station quantities; each sum within the particular hull's catalogue limit |
| R_v,R_p / V,V_i | Owned rear hulls / new production admissions within8; military live / incoming hulls within24 |
| F_o,F_i | Assigned combat roster members, including incapacitated people until detachment / incoming replacement intents within8 per ordinary squad; former detached casualties are history, not a ninth slot |
| P_f,P_p,J,E,N,L | Supplier freight≤11; supplier personnel≤2; pending instructor≤1; emergency≤1; enemy preparation/transit≤3; enemy leases≤3 |

A corpse remains real mass at its actual holder. R/M living-person release does not free a still-blocked seat/station/bed. Actual body clearance has no treatment/pack cost. Outdoor corpse collision is not added.

### 8.1 Acquisition, rear duties and outward movement

| Transition / physical duty and controller | Checked capacities and exact event/deltas | Blocker and once-only outcome |
| --- | --- | --- |
| Preview or supplier order; source cohort remains external until actual F08 receipt | Preview holds no military admission. Standard purchase reserves R_i8 and P_p1 before debit. Source identities/actual vehicle remain distinct from intended recruit claims; supplier driver contributes no rear/military member or owned hull. | Rear120/personnel2 can refuse before commitment; rejected purchase changes no claims/money. |
| Valid early supplier cancellation | Release that order's unfulfilled R_i8/P_p1 and refund once within first5s. Instructor cancellation similarly releases its own R_i1/P_p1/J1. | At/after dispatch no cancellation refund; repeated cancellation releases nothing. Other orders' people/service claims remain. |
| Supplier transit/berthing/exit; Passenger under supplier control | P_p and R_i persist. Healthy passenger exits1/s after stopping; S_o−1 on actual exit, but R_i persists through own walk. At actual F08 arrival R_i−1,R_o+1 and duty Available/rear. | No worker bootstrap needed for healthy people; no arrival-timer recruit. Walking claimant is not yet available. P_p releases only at physical vehicle clearance. |
| Instructor arrival; actual P01, not supplier driver | Before purchase claim R_i1,P_p1,J1; on actual F08 receipt R_i−1,R_o+1,J−1. Vehicle P_p retained through clearance. | No basic-trained rear person and pending J0 required. Personnel2 is shared; no third pull-off. Receipt replay cannot add a second instructor. |
| Rear Available→Rear Labour/Training/Instructor; rear controller | R_o remains1. Safe carry handoff precedes duty replacement; training/student/instructor prerequisites remain real and separate. | No parallel work/training; pause preserves work, withdrawal loses incomplete course time only. Qualifications survive legal return to labour. |
| Accept Strategic Delivery manifest; named people rear, pending safe report | I+1 per new permanent passenger before acceptance, S_r per planned passenger. Returning actual crew have no I. R_o stays occupied while reporting/boarding/waiting. | Eligible unique people, I room and non-duplicate commitment required; missing later preparations block Ready/departure without inventing staff. |
| Accept Fleet Transfer manifest; rear-controlled hull/actual crew and passengers | I includes every actual transferring crew member and passenger; V_i+1 within24. R_v remains owned; R_o remains occupied. Driver-only legal transfer reserves its actual driver only. | Full M+I or V+V_i rejects atomically. Vacant combat stations remain vacant and can block combat deployment later. |
| Atomic accepted-manifest edit, still predeparture | Exchange only affected I,V_i and seat/station claims after validating proposed totals; no transient release of the old accepted promise on a failed edit. | A mode edit cannot commandeer a returning driver. Failed edit preserves old mode, IDs, quantities and claims exactly. |
| Actual reporting/boarding; one Passenger or crew-duty phase, rear controller | Reporting stops labour after safe handoff. At each completed passenger board S_r−1,S_o+1; real crew reports to T, never S simultaneously. R_o/I unchanged until boundary events. | Check seats, stations, payload, route/fuel and qualifications before departure; partial loading never authorizes partial dispatch. |
| Predeparture accepted-manifest cancellation; people may remain aboard rear hull | Withdraw that manifest's I/V_i once and free only unoccupied S_r/T_r. R_o and physical S_o/T_o persist until actual unboarding/return work. | Cancellation frees a promise, not a physical seat. Collected cargo requires real unloading; no second refund/release on replay. |
| Strategic Delivery actual rear exit | Passenger R_o−1, I retained. Returning crew R_o−1,R_h+1; no military membership. R_v retained; S/T occupancy unchanged. | No rear release at reservation/boarding. Each physical boundary event is counted once. |
| Fleet Transfer actual rear exit, not HQ handoff | Non-returning passenger/crew R_o−1 each; I,V_i and R_v retained. Same rear-controlled hull and actual occupants travel. | Person rear release and hull fleet release are different events. No early V_i→V conversion. |

### 8.2 Receiving, return, medical and loss

| Transition / physical duty and controller | Checked capacities and exact event/deltas | Blocker and once-only outcome |
| --- | --- | --- |
| Transit, route cut or10s safety stop; same identities/holder/duties | Retain living M or I, home holds and real occupants/hull claims. No distant Q/C occupation. Safe return is actual movement under the existing route rule. | Unknown/unsafe route, missing driver, fuel or receiver; timeout releases no person, hull, seat or irreversible commitment. |
| HQ berth/receiver blocked; passengers aboard rear/service hull | Grant Q_i only immediately before that individual's safe exit/walk, or C_i before accepted care movement. Original M/I persists while waiting. S_o remains until actual exit. | Reserve full, recovery full, berth occupied, no legal exit/handlers are separate reasons. Military admission does not guarantee local96/12 space. |
| Healthy passenger leaves then reaches accepted HQ place | At actual exit S_o−1; Q_i held throughout walk. Actual receipt Q_i−1,Q_o+1,I−1,M+1; HQ Reserve/military control begins there. | No unclaimed mid-walk gap; exit alone does not permit issue/formation use. Replay of one receipt changes nothing. |
| Incoming patient handed directly into HQ recovery | C_i→C_o at actual care receipt and I→M once; no Q place. Real extraction/transport replaces healthy self-walking when necessary. | Newly arriving person is not counted in both M and I; full Q does not itself prevent a valid C receipt. |
| Actual Fleet Transfer hull/crew HQ receipt, stopped with command/access | V_i−1,V+1,R_v−1; actual crew I−1,M+1 each, still physically in T if seated. Passengers' independent I/receipts may remain blocked. | No gate/timer handoff. Incapacitated crew remains incapable and station occupied; no compulsory fake HQ Reserve detour. |
| Returning Strategic Delivery crew home arrival | Retain rear control/R_v/R_h through trip; at actual rear entry R_h−1,R_o+1. | No new population place needed for the held home. Medical delay/stranding holds it; only actual return or confirmed death resolves it. |
| Pre-HQ non-returner safety return, outside rear | Obtain R_i before crossing; keep I while reserved/waiting. At actual lawful readmission R_i−1,R_o+1 and explicitly withdraw that person's I once. | Rear Full means real safe holding/aboard outside, not overflow. Revised return releases unused R_i but retains I; no trip refund. |
| Pre-HQ Fleet Transfer hull safety return | R_v held throughout. On lawful actual rear hull receipt plus explicit withdrawal V_i−1; parking/receiving and all aboard people's rear admissions required. People I withdrawals are independent individual receipts. | Hull receipt cannot release a passenger still outside or supply a free driver. Intentionally active transfer keeps V_i. Repeated withdrawal releases no second hull. |
| Existing military member assigned from HQ reserve to squad/service/crew | M unchanged; Q_o ends at real departure/report to the new duty. Reserve real F_i or T_r as applicable. No second army I. | Qualification/type minimum and real reporting remain required. Proximity to HQ is not HQ Reserve occupancy. |
| Existing military forward replacement, then rendezvous | F_i reserves target vacancy within8; source person has one Transfer phase, real seat/escort and same M. At actual recipient meeting F_i−1,F_o+1. | Cut route retains actual traveller and intent; no remote squad fill. Reassignment/cancel changes unused intent only and needs a lawful destination. |
| Active injury→incapacitation→first aid | Old duty until medical reassignment; Wounded then Recovery. M/I/R_h remains while living. Actual seats/stations stay occupied until exit/extraction. | No new recruit admission on injury. Care requires actual medic/kit/pack and work; progress/timers survive only as specified. |
| Planned evacuation / HQ or S08 receipt | Before departure claim actual C_i or A_i, plus seat/payload/route/handlers. At actual receipt incoming care claim→occupied. M/I/R_h unchanged except the required actual HQ entrant handoff. | Recovery12 and each aid-post8 are separate. Securing a replacement receiver precedes lawful reroute; route loss alone releases no still-needed claim. |
| Medical need arises while already stopped at HQ | Seek a real Q/C destination according to actual need, with physical care/extraction; existing location and bleeding/care rules persist meanwhile. | Does not authorize an earlier planned evacuation without a receiver. No capacity-triggered death, free care or overflow. |
| Completed HQ/aid-post patient discharge | Hold occupied bed until lawful receiver secured and actual bed exit. Routine Q_i, or actual compatible F_i/T_r/service receiver, persists through real movement. M unchanged; new entrant first needs actual HQ handoff. | Full reserve may allow real direct-duty discharge, but not undefined staging. No second pack/time. Pre-HQ aid-post custody cannot enlist or assign an entrant into a forward squad remotely. |
| Actual acknowledged medical detachment from squad | At real named care/evac custody or recovery admission F_o−1, while M retained and former-squad history remains. Before custody incapacitated member still occupies F_o. | Medic request alone frees no roster slot. Detached recovered person must reserve a current vacancy and rejoin; no automatic ninth member. |
| Confirmed death, intact vehicle/care place | Release that ID's M OR I, applicable R claim, roster and unfulfilled destination claims once. Still-present corpse changes S_o→S_b, T_o→T_b or C_o→C_b as applicable; retained body/gear mass remains. | Exempt fixed/service death creates no fabricated M decrement. Another occupant's claim survives; dead space is blocked, not a usable vacancy. |
| Actual body extraction/clearance from intact station/bed | Remove own blocked-position count only after actual body relocation using real handlers/transport and80kg plus retained gear. No treatment or pack. New operator physically enters and takes3s stopped station assignment. | Replayed clearance cannot free a second place or remove mass twice. This adds no general ground-corpse collision. |
| Hull destruction / actual ejection or survival failure | Apply60 injury/80 suppression once; relocate survivors to legal≤8m positions, or deaths as specified. Resolve actual seats/stations through ejection/relocation or loss of hull, not mere death. Remove the hull's live/incoming claims once. | No extra spall or destroying-shot blast. Living survivors retain M/I/R_h/service affiliation; a destroyed hull has no reusable passenger pool. |
| Fixed original HQ person changes lawful duty/care; replacement appointed | Exemption follows original ID all engagement. Replacement drawn from military reserves stays counted; flexible P03 medics are counted staff, not beds. | Role rotation grants no new exemption, people or qualification. Commander succession uses an actual eligible survivor. |

### 8.3 Fleet and external-service claims

| Domain / event | Check / release event and identity | Blocked / once-only outcome |
| --- | --- | --- |
| Rear production admission | Accept order only if R_v+R_p<8; R_p+1. Immediately before the completed vehicle's actual physical creation/admission at a legal output/collection position, recheck its existing order claim and destination. That same event converts R_p−1,R_v+1 for the one hull, preserving R_v+R_p. | No lawful output: wait with the claim held and no new hull. Repeated completion/collection changes neither count nor creates another hull; later parking movement also changes neither. Unfinished cancellation releases only the unfulfilled claim under existing material rules; an actual admitted hull cannot be cancelled away. Its destruction releases live R_v once, not stale R_p. Travelling hull frees parking without freeing R_v. |
| Enemy finished-package purchase / actual HQ arrival | Check N<3 and60s purchase cadence; all new I/V_i before debit. Lease A–F/J–M also checks L<3 and reserves L. At actual HQ arrival N−1, not I or L. | Arrival neither unloads people/goods nor ends active lease. G/H/I use military24, not lease3. |
| Enemy lease return / terminal service loss | L retained through blocked offload and safe physical return. Release after real service exit, or terminal loss with no living driver awaiting return. | Destroyed hull/live driver keeps L; dead driver/live empty hull needs real removal/return/destruction. Never manufacture exempt drivers by instant re-purchase. |
| Player emergency / supplier domains | E1 distinct from enemy N3/L3 and supplier P_f11/P_p2. Emergency external driver/hull has no owned rear/military or member admission; actual manifest people/cargo do. | E persists through survivor rescue/return. Suppliers/instructor use their own adopted admission and clearance lifetimes, not a universal3 pool. |

## 9. Exact reference fixtures and expected outcomes

These declared timelines use ordinary catalogue limits and the contract above; they do not execute a game, route, combat, custody or claim implementation. Every receipt/exit/extraction named below is an actual completed physical event in the expected scenario. Replaying an already-completed event has zero further delta. Unmentioned people, goods and capacities stay at their stated holders.

### 9.1 Initial ledger and W1 rear continuity

Initial player:42 P00+12 P01+6 P08=60 rear, including3 strategic drivers and2 instructors. Staffing49+available11=60. Battlefield40 infantry+5 crew+2 flexible recovery medics+5 original fixed HQ=52; unique physical player people112. Counted military M47,I0; original exempt5; Q0/C0 patients; R_v3,R_p0,V4,V_i0. Field crew are4 P08+1 P04; no driver is added again for an occupied hull.

W1 is a separate hypothetical boundary, with four real returning crew away:
| Event | R_o | R_h | R_i | Load / result |
| --- | --- | --- | --- | --- |
| Before purchase |108|4|0|112; eight free |
| Accept supplier eight |108|4|8|120; next eight would128: reject without debit/claims |
| X1…X4 actually received |112|4|4|120; X5…X8 still incoming |
| X5…X8 actually received |116|4|0|120 |
| Four actual crew return |120|0|0|120; no extra recruitment space needed |

Early-cancel branch from108/4/8: cancel that valid undispatched order→108/4/0=112; repeat unchanged; replacement order→120 once. Separate returning-death branch from116/4/0: one confirmed away crew death→116/3/0=119, repeat unchanged; hull loss with that crew still alive leaves116/4/0. Home holds end per individual, not as a whole vehicle or four-person batch.

### 9.2 W2 military admission, edits and receipts

Use existing member IDs B1…B376 and new committed X1…X8. Accepted Strategic Delivery reserves I8, so376+8=384; returning actual driver is separate and has no I. A second eight cannot fit. Actual first X1 HQ receipt gives M377,I7; all eight gives384/0. X1 is in M, not also I; replay X1's receipt leaves377/7. Moving eight existing military members forward at full384 gives384/0, not392.

Before-departure cancel branch376/8→376/0 once while rear people/seats still require physical unboarding. Incoming-death branch from376/8: X1 dies before army handoff→376/7=383; no M decrement. An intact occupied seat becomes blocked until the body is cleared, as9.6 specifies. Replaying X1 loss leaves383.

| Full-cap mode/edit case | Accepted state / proposed edit | Expected outcome |
| --- | --- | --- |
| E1: M376, Strategic Delivery8 new passengers | I8, no incoming hull; edit to Fleet Transfer with same8 plus actual driver | Would I9,total385: reject; original mode/I8/V_i0 and all IDs/claims unchanged |
| E2: M375, Strategic Delivery8 | I8,total383; edit same hull/people to Fleet Transfer | I9,total384 and V_i1 if V23; accept atomically; reverse predeparture edit returns I8/V_i0 once |
| E3: T04 Fleet Transfer3 actual crew+8 passengers | M373,I11,V23,V_i1 | Fits384/24; at M374 requires385: reject before acceptance |
| E4: driver-only legal incomplete hull | One actual transferring driver, no passengers | I1 only, not full imagined combat crew; still Not Combat Ready under catalogue rules |

The T02 Strategic Delivery reference load is8×80+8×4+480×0.02=681.6kg in8/16 passenger seats; the separate driver remains in its crew station and held rear home after departure. No crew body is hidden inside those eight reinforcements.

### 9.3 W3 local96/12 receiving and completed discharge

Start Q_o94,Q_i0,C_o11,C_i0,C_b0. A stopped T02 has8 actual passengers:6 healthy entrants plus2 newly needing recovery while already stopped at HQ; the preceding trip was not an unreserved planned evacuation. Actual medics/first aid are recorded, and patient extraction/movement has real handlers. All army admissions were already counted or reserved. A separate driver occupies its station. Body payload is640kg before actual gear, within T02's2000kg only after its actual complete load is checked.

Grant each short-lived place immediately before that individual's safe exit/extraction: first Q_i1, then the second person's own Q_i1 before their serial exit, and C_i1 before the patient's real extraction. Only actual exit frees each seat. If none has yet reached their receiver, the aggregate is Q_i2/C_i1 and five people still aboard, with three actually moving toward claimed places; nobody is in both an occupied destination and its incoming claim. Receipt resolves each corresponding place and army entrant.
| Completed event | Q_o | C_o | Passengers still aboard | Result |
| --- | --- | --- | --- | --- |
| Two healthy plus one patient received |96|12|5|Four healthy and one patient remain aboard; no further place |
| One original resident patient medically completes |96|12|5|Still in bed: Medically Complete - Awaiting Destination |
| Two actual reserve people report/depart forward |94|12|5|M unchanged; these are existing military transfers |
| Completed original patient reaches Q receiver |95|11|5|Bed actual exit frees1; no extra pack |
| Waiting vehicle patient reaches that recovery bed |95|12|4|Its C claim converts; not Q |
| One more healthy entrant reaches Q |96|12|3|Three healthy remain aboard |

Care work completion alone did not free the bed. During a lawful discharge movement the next destination claim persists; the table records completed events, not a forbidden unclaimed walking interval.

Additional medical boundaries:
- Planned evacuation: C_o12,C_i0,C_b0 gives zero room; reserve before departure fails. With C_o11, one patient can reserve C_i1, not two. A real receiving claim, actual seat/payload, driver/handlers and route are all required.
- Full-reserve direct discharge: Q_o96,C_o12; medically complete existing member D has an actual compatible squad with F_o7,F_i0. Reserve its vacancy F_i1; before actual bed exit C remains12. Actual exit gives C11 with target intent retained during travel; real report gives F_o8,F_i0. Q remains96,M unchanged. Without that vacancy or lawful receiver, D remains in the bed.
- Each S08 has8 care places separately. A_o7,A_i1 is full even if HQ C has room; a new claim is refused until a real local slot frees. Its medics are actual staff, not extra patient capacity.
- Pre-HQ entrant X with I1, in one actual S08 bed A_o1, completes care: M is not increased, and an open nearby squad cannot enlist X. Secure a real lawful onward transport/escort receiver; bed frees only at actual exit. A transport seat can receive X for that journey; ordinary HQ Q is not booked for the whole distant trip. At HQ, claim Q immediately before actual exit/walk and convert I→M only at real receipt. With no legal onward receiver X remains in care; alternatively use the permitted rear readmission procedure. This does not turn an incoming claim into forward membership.
- Returning rear crew in care keeps R_h1 and M0 for that person. Actual medically complete transport/home movement eventually converts R_h→R_o; neither care nor hull destruction recruits them into M/Q.

### 9.4 Real medical detachment and replacement

Use squad S with8 assigned IDs including incapacitated A, and an existing military replacement B in reserve; both already belong to M. Initially F_o8,F_i0. Merely requesting a medic leaves8/0. Actual acknowledged named medical/evac custody detaches A:7/0, A remains M with history/care location. Reserve the vacancy for B:7/1; real B rendezvous→8/0. Replayed detachment/receipt has no further delta.

A completes care, but a return claim to now-full S would make8+1=9: refuse. Keep A's actual Recovery/receiver state until a real alternate destination is secured. If another current member lawfully leaves S,7/0 permits A's7/1 claim; real rejoin→8/0. Army membership never increases during these existing-person moves. Maximum27 squads×8=216 is distinct from army384 and includes pending squad replacement places within each eight-place limit.

### 9.5 W4 destruction and surviving identities

M200 comprises196 other members and driver(health100),A100,B50,C already incapacitated0 aboard a military T02. There are3 passenger occupants and1 actual crew station, with no duplicated driver.

Land destruction with valid≤8m ejection: driver/A become40, B incapacitated0, C dead. The three living originals plus196 yield M199. Apply60 injury/80 suppression once; no extra10 spall or destroying-shot blast. Ejection/relocation or loss of the hull resolves the original positions; military hull count falls1. New rescue seats/care places are required for those same survivors. A second loss/ejection event cannot kill or release C twice.

Deep-water/no-survival-location variant: all4 die, M196, hull−1, no survivors to receive. A returning rear driver instead keeps its home hold while alive; an exempt leased driver has no M to decrement and keeps service pending return as9.8 requires. An incoming entrant still I after hull loss remains I until real HQ/rear handoff or death, including care at a forward aid post.

### 9.6 Death versus intact physical station/bed

Intact T03 reference: living non-exempt gunner G has80kg body plus E01 4kg and60 E02×0.02kg=5.2kg retained gear, total85.2kg. Its driver is separate. Let M384,T_o2,T_b0 before G's confirmed death.
| Event | M | Living stations / blocked | Gross mass effect | Availability |
| --- | --- | --- | --- | --- |
| G dies still in intact station |383|1 / 1|0; same85.2kg still inside|No usable gunner vacancy |
| Actual body/gear extraction to recorded outside holder |383|1 / 0|Vehicle−85.2kg, actual outside holding+85.2kg|One station can now be claimed |
| Qualified existing member reports/enters and completes3s stopped station assignment |383|2 / 0|Its actual body/gear enters|No new army member or imaginary operator |
| Replay G death/clearance |383|Unchanged|0|No second vacancy/mass removal |

Use real handlers and existing casualty extraction/carry limits, without treatment or a medical pack. If G died in a passenger seat, S_o→S_b instead; that blocked seat likewise cannot accept another person. New admissions can use the released living M slot, but cannot use the obstructed physical position.

Care-bed reference: C_o12,C_i0,C_b0; non-exempt patient dies still in bed→C_o11,C_b1, so physical load remains12 and no incoming claim fits. M releases that person once. Actual body clearance→11/0 and one free bed; reserve C_i1→load12. Replaying clearance cannot create a second bed. Death of an original exempt patient would not reduce M; absence of living patients alone never promises unobstructed space.

### 9.7 Rear return admissions and separate hull withdrawal

Safety return is a physical irreversible-trip continuation, not predeparture cancellation. Reference: M375,I9 (eight T02 passengers plus actual Fleet Transfer driver), V23,V_i1,R_v8 including that outgoing owned hull. Its parking bay is vacant/available on return; this is not another owned slot. Rear R_o112,R_i8=120 from an unrelated new supplier order.

At full rear the nine returning non-returners have no R_h; nobody can cross merely because their hull already has R_v. All I9/V_i1 persist while actually holding outside. Valid early cancellation of the unrelated supplier8 gives R_o112,R_i0: only8 places free. Reserve8 return admissions including the driver; one named passenger X9 remains outside in an actual safe holding/transport position after real unboarding. The hull cannot carry X9 across without X9's admission.

On the eight actual person readmissions R_o120,R_i0; withdraw those eight I individually, leaving M375,I1 for X9 outside. On lawful actual hull receipt with explicit transfer withdrawal V_i1→0; V remains23,R_v remains8. Its hull receipt cannot withdraw X9's I, and repeated receipt cannot remove a different incoming hull. Return admission reservations alone did not withdraw any I. If the return plan is revised outside, release only unused rear claims and retain the corresponding military commitments. No transport fee/fuel refund or rewind.

Already handed-over military members/hulls cannot use this procedure to return to industrial labour. Healthy returning Strategic Delivery crew instead use their held homes and never the new military entrant/hull withdrawal path.

### 9.8 Hull production, instructors and service lifetime

Rear production reference, clarified in the [focused Game Designer review](https://github.com/TheInfinityIQ/Trencho_V4/pull/53#issuecomment-6415874589): seven existing live owned hulls and one accepted order claim give R_v7,R_p1=8. Use stable new hull ID H8 and its existing order; immediately before actual physical creation/admission recheck that claim and the actual legal output/collection destination. Work completion alone does not create a hull at an invalid destination.

| Production event | R_v | R_p | H8 live / physical record | Expected outcome |
| --- | --- | --- | --- | --- |
| Order accepted, before completed-hull admission |7|1|No new hull|Total8; another order refused |
| Output/collection destination blocked |7|1|No new hull|Completion/admission waits; original claim held |
| Valid claim and destination; one actual physical creation/admission |8|0|One H8 live|R_p−1,R_v+1 at the same event; total stays8 |
| Repeat completion/admission |8|0|Same one H8|No second hull or conversion |
| Actual collection/parking movement; repeat collection |8|0|Same H8 at its actual new position|Neither fleet count nor production claim changes |
| Attempt ninth order |8|0|Same one H8|Reject before another claim; no change |
| H8 actually destroyed |7|0|Same H8 record now Destroyed/wreck|Release its live R_v once, not R_p |
| Replay H8 destruction |7|0|Same loss/physical record|No second release |

Separate unfinished-cancellation branch from7/1: release only the unfulfilled order claim→7/0 once under existing production/material rules, with no H8 created. After legal physical admission, cancellation cannot remove the real H8. At R_v8 an outgoing Fleet Transfer still blocks a ninth order until actual HQ handoff or destruction; physical parking and owned-fleet slots are separate. Military V23,V_i1=24 refuses another hull; actual HQ handoff gives24/0 once, or the lawful pre-HQ rear receipt/withdrawal in9.7 gives23/0. Hull destruction releases its own claims, not surviving people's claims.

Instructor reference: P_f11,P_p2,R_o104,R_i16=120 from two standard pending8-person orders; no basic-trained rear person remains and J0. Instructor purchase is refused before debit: no P_p room (and no rear room), J stays0. Valid early cancellation of one standard order→P_p1,R_i8, rear112. Instructor purchase claims P_p+1,R_i+1,J1: P_p2,rear113; no third vehicle. Actual instructor F08 receipt→R_o105,R_i8,J0 with P_p2 still held through vehicle clearance; the new P01 also removes the eligibility shortage. Clearance→P_p1. Replayed receipt/clearance cannot add a second instructor or free another order. P_f11 stays independent throughout.

Enemy service reference, with sufficient money, actual routes and purchase cadence≥60s:
| Event | Preparation/transit N | Leases L | M / I | Military V / V_i |
| --- | --- | --- | --- | --- |
| Three8-person leased packages preparing/in transit |3|3|340 / 24|23 / 0 |
| One actually arrives but remains blocked aboard |2|3|340 / 24|23 / 0 |
| Buy package I tank with its actual4 crew |3|3|340 / 28|23 / 1 |
| First lease's8 people actually received |3|3|348 / 20|23 / 1 |
| That lease physically completes return/service exit |3|2|348 / 20|23 / 1 |

At N2/L3 a new leased package fails L even though preparation room exists; the tank above does not use L, and its people/hull fit368/24. After lease clearance L2, N3 still blocks another purchase until an actual package arrival and cadence permit it. G/H/I all require their own real incoming people/hulls; they gain no exemption from L being full. Arrival release of N is not offloading, membership conversion or service clearance.

A lease destroyed with its driver alive retains L until real driver exit or confirmed death; that survivor can receive actual care without joining M or a crew/recruit pool. A dead driver with live empty hull retains its service until actual removal/return or destruction. Emergency E1 behaves independently: hull loss/live driver keeps E1 and blocks a second contract; terminal hull loss with no living driver awaiting return ends it. Neither releases supplier P_f/P_p or creates owned fleet/military slots.

### 9.9 Once-only and restoration controls

For each declared boundary keep the before/after identity, holder, duty, claim owner, occupied/held/incoming amounts, physical blockage and outcome. Compare these exact expected snapshots after a repeated cancel, individual receipt, medical detachment/discharge, body clearance, original-five death, hull withdrawal and terminal service exit. Replaying an event must preserve the first resulting snapshot, not release a new unit.

Restore immediately on each side of rear crossing, HQ receipt, medical custody, bed exit, physical extraction and death with the same IDs, pending intent, health/care work, cargo/mass, original exemption, handling/route state and claim status. Restoration must not recalculate those as fresh purchases/admissions, reapply60 injury, discard a corpse's mass, or convert forward care into HQ enlistment. These are required expected definitions; G32 and the owning gameplay features must prove implementation/restoration later.

## 10. Verification record and ownership limits

Recorded 26 October 2026 on the documentation branch based on main `23f142ab797d9f672ed2fc4369eda760aaaa24d6`.

| Actual check | Result / scope |
| --- | --- |
| Independent reference arithmetic and declared identity snapshots | 76 assertions in 14 groups, zero failures. Recomputed initial 112/47/5, W1–W4, mode/receipt/death boundaries, local receiving/care, roster 216, body mass/physical blockage, separate hull withdrawal, production claim-to-live-hull conversion including blocked/repeated admission, fleet limits, instructor sharing, service lifetimes and original exemptions. |
| Authority comparison | Adopted sections 1–7 preserved against the retrieved Game Designer decision; supplemental matrix/fixtures do not replace its choices. No remaining concrete contradictory reference outcome found. |
| Documentation links | 19 local links and 2 local heading anchors resolve. |
| Scope/baseline | Pre-amendment GDD compared unchanged with main; no competing 23.3; no runtime diff. G02 worktree clean and unchanged at `17081be0f0822d7de459854caf1dd91725228cc5`. |
| Repository check | Steam Godot 4.7.2 import, retained G01 (14 cases/624 checks) and headless startup pass, with no reported engine/script errors. |
| Whitespace | Final staged `git diff --cached --check` passes. |

Reference audit/evidence are preserved locally under ignored `.artifacts/d03_definition_audit.mjs`, `.artifacts/d03_definition_audit.json`, `.artifacts/d03_docs_audit.mjs` and `.artifacts/d03_docs_audit.json`. The durable expected inputs, equations and snapshots are in section 9; no production lifecycle, generator or claim implementation is added. Arithmetic/set checks do not test actual event idempotence, movement, custody, casualties, rendered readability or save/load code.

D03 remains open until the Game Designer accepts and merges the canonical documentation/matrix/fixtures. Owning G12/G15/G16/G23/G26/G27/G29/G32 issues must implement and demonstrate complete A01/A04/A20/A25/A41/A45 and relevant integration evidence, including real boundary transitions and restoration. D02's definition is already accepted; G10 retains final-world A17/A18. D01 presentation/performance and G02 native verification are not settled here. G02 PR51 stays draft/unmerged, and its separate pending23.3 clarification is not copied into this main-based branch.
