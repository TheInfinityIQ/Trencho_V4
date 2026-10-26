# G03 retained native evidence — 26 October 2026

These unedited native Windows captures exercise runtime `290c25af016472a4e69e9349534786c59b4417d7`, Steam Godot `4.7.2.stable.steam.ed1daf0bf`, OpenGL Compatibility, RTX 4070 Ti. The requested client was 1000×720; captures measure 1002×752 including decorations. The configured logical canvas is 1280×720, scaled with vertical letterboxing. No desktop display settings changed. This is the declared small rear fixture, not the full starting engagement.

| Capture | State actually shown |
| --- | --- |
| [Operators without local inputs](a05_operators_missing_local_inputs.png) | t=300, F04 target/assigned/present 2, Missing Inputs and General Hauling shortage, zero work/consumption/output |
| [Local readiness only](a05_local_input_readiness_only.png) | t=600 after assigning one actual hauler; two present operators, local inputs ready, G04 production not implemented and work/consumption/output still zero |
| [Actual deposited ingredients](a05_deposited_reference_inputs.png) | t=600, F03 empty; F04 input has exactly 2 M01 and 1 M02 available, no remaining outbound/inbound reservation; physical limits shown |

Saved files were visually inspected on resumption and have distinct SHA-256 hashes. Later revision `423373b` adds the actual approach scenario and refreshing selected details; subsequent draft refinements change idle selection, Emergency contention timing and storage access/relocation behavior. These earlier images do not establish native verification of those changes or the final PR head. [The behavior record](../../g03_staffing.md) lists engine evidence and the missing native cases separately.

A prior native refresh ended with an explicit human physical-Escape stop; work stopped and was reported. The human subsequently instructed continuation. The next fresh game window was readable, but Windows refused the intended input twice, including after one proper reselect/activation/fresh capture: `SendInput sent 0 of 1 events; GetLastError=122`. Input attempts then stopped. No other application's controls were clicked. A06 native worker/driver/pile observations and final selected-detail/readability checks remain unverified; no screenshots are supplied as passing evidence for them. Keep the PR draft and issue #11 open.

Full A05 recipe/consumption/output is G04's later integration obligation. Literal 1280×720 physical and D01 production display/platform/performance are unverified.
