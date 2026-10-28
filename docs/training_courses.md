# Connected F06 training and instructor recovery

[Designer scope](https://github.com/TheInfinityIQ/Trencho_V4/issues/14#issuecomment-6457341233), based on PR72/main `7b312555`. Exact GDD5.3/7/8 and D03 people/recovery rules govern. Related #14; no automatic closure. All29 manufacturing recipes and the existing rear remain connected.

F06 has two real instructor duties and twelve actual/reserved student places. The Train panel requests course counts, assigns eligible idle people before safe rear-work transfers, and shows queued/reporting/active/paused/completed/withdrawn courses with identities and elapsed seconds. Students report to twelve declared positions in the F06 entrance court; instructors report to its accepted entrance. Reporting and carried goods never earn training time. Students have the ledger's exclusive Training assignment and are excluded from industrial staffing. Instructors are actual basic-trained rear workers, including specialists, serving only that duty. Existing staffing priorities remain authoritative when instructor and industrial targets compete.

| Course | Elapsed seconds after reporting | Declared recipe access |
| --- | --- | --- |
| P01 Basic infantry | 120 | Always |
| P02 Engineer | 180 after basic | R08 |
| P03 Medic | 180 after basic | R11 |
| P04 Heavy weapons | 180 after basic | Any R05/R06/R29 |
| P05 Artillery | 180 after basic | R13 |
| P06 Drone operator | 180 after basic | R16 |
| P07 Marksman | 180 after basic | R19 |
| P08 Vehicle crew | 240 after basic | R25 |

Course access reads the session's declared available recipes, independent of selected/enabled production. P01/P02/P08 remain essential; expanded access enables the other courses. No live cards/unlock service is added. Requested places can wait for an eligible basic-trained person; an already qualified specialist cannot be silently replaced or receive a second specialist role.

One present instructor covers six actual students, two cover twelve. Enrollment order is stable; the newest excess students pause first. Instructor departure, shortage and access loss preserve elapsed work. Restoration resumes it. Basic completion and one specialist qualification update the SAME ledger person, with no body, equipment, ammunition, vehicle or fuel grant. Withdraw a queued/reporting/unfinished course to lose only its unfinished time and release its place. Completed basic/previous qualification remains; pending old carries retain their goods and duty until safe deposit. Inspect a course or person to see retained qualifications and actual position.

## Paid recovery purchase

Normal sessions still start with twelve ordinary untrained people, 2500 requisition and no goods. When no living basic-trained player person remains physically in the rear and no recovery P01 is pending, Orders offers **Buy recovery instructor (120)**:100 requisition plus20 transport, one rear population place and one of the SAME two personnel vehicle admissions reserved before payment. Other incoming people count toward120; there is at most one pending recovery person. The existing five-second cancellation/refund applies.

The service arrives after90seconds, then physically berths, exits one passenger and walks to Personnel without unloading labour. Only that individual's receipt changes its owner/available duty and joins the existing actor pool; the supplier driver/hull stay external. The arriving person is ordinary P01 with completed basic and no specialist. Pending status ends at actual receipt, and vehicle admission lasts through physical departure. An existing trained person hides the offer; merely lacking an assigned instructor does not authorize another purchase. No emergency transport, free P08, hull or fuel is added.

## Ownership and verification

The rear calls the optional course service at the SAME event boundaries as procurement, reporting/hauling and production. Training earns elapsed seconds per covered student, independently of production operator-work. The ledger validates completion eligibility and retains qualifications; course progress, seats and coverage belong to F06. Weak references preserve scene-owned lifetimes. No autoload, duplicate person pool or isolated course scene is introduced. Panel/inspection changes preserve the live session; only the already explicit new-session action resets it.

Nine focused Domain cases cover all eight canonical durations/access, physical reporting and no gear/body grants, A11 twelve students under one then two instructors with newest-first pauses, interruption/time partitioning, withdrawal/basic retention/single specialist, safe carry-to-student and instructor reporting, population/one-pending/personnel admission/cancel rules, and zero-unloader recovery through actual P08 training. The normal-entry SceneRunner flow buys recovery P01, trains a real second instructor, purchases eight ordinary people, demonstrates six active/six paused then twelve active through real controls, and qualifies the same graduate as P08. No qualifications/progress/people are injected. Four representative normal/small screenshots are retained in `.artifacts/training-courses/`.

Use affected named cases during iteration, full normal checks/current-head CI for the stable result, and retain the eight existing focused negative controls. No per-course review scene/PR/control or broad evidence packet is added. Linux input/render evidence does not establish Windows-native acceptance.

[G07 actual stations/clearance](https://github.com/TheInfinityIQ/Trencho_V4/issues/15) must use these trained people and local purchased fuel on the SAME manufactured hulls. Training callbacks never board/refuel/move a vehicle or clear F10. [G12 field-gun collection](https://github.com/TheInfinityIQ/Trencho_V4/issues/20) remains separate. Construction/final starting scenario, military commitment/world/combat/AI, saves, actual cards, native and fullM0 remain outstanding.
