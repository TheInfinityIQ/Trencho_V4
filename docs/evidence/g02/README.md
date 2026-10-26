# G02 native session evidence — 26 October 2026

Runtime reviewed: `17081be0f0822d7de459854caf1dd91725228cc5`, branch `codex/g02-procurement-receiving`, PR #51. The follow-up practical run exercised merge revision `70dfa7bfe739a73a91d8f8d4ac751b202626dca3`, incorporating accepted main `3a151b6a18ce05abe8d5b417897da0386dfca9f0`. Runtime/tests/tools/project configuration still match `17081be`; the subsequent evidence revision changes documentation/images only. Engine: Steam Godot `4.7.2.stable.steam.ed1daf0bf`, Windows/OpenGL Compatibility, NVIDIA RTX 4070 Ti.

The human confirmed that the desktop was available. The 960×540 game window accepted native clicks and keyboard input. [The verification record](../../g02_receiving.md#native-observations-at-960540) gives the observed A04/A58, passenger cadence, atomic quote/refund and duty handoff results. These are native session observations, distinct from the passing engine-driven regression/interface checks.

## Retained captures

- [Arrival with cargo aboard](a04_arrival_aboard.png): t=60, 100 kg aboard, zero carried/deposited/free, zero people/workers, one freight admission. This capture precedes the t=70 stopped-berth checkpoint.
- [Portrait desktop fit](portrait_desktop_fit.png): complete Terminal after maximizing on the available portrait desktop, with aspect-preserving letterboxing. This is a fresh zero-worker fixture, not recovery evidence. It does not prove a fully visible 1280×720 physical window or normal-size interactions.

Captures are unedited native screenshots. Screenshot export validation found that a helper retained an earlier observation rather than each intended checkpoint. Duplicate exports were discarded; the one valid earlier frame was named for the state it actually shows. Consequently there are no independently retained screenshots of the later recovery/refund checkpoints. Their results are recorded from the screenshots inspected during the live interaction session; do not present the two retained images as proof of every row.

## Practical display captures

The [Game Designer's bounded-fixture clarification](https://github.com/TheInfinityIQ/Trencho_V4/pull/51#issuecomment-6417063477) accepts a wholly visible practical 1000×720 client window alongside the 960×540 walkthrough and logical 1280×720 geometry coverage. A fresh single instance passed this check. Each capture below is 1002×752 including decorations, with all window edges visible. The 1280×720 configured logical canvas scales into roughly 1000×563 with vertical letterboxing; this is not a literal 1280×720 physical-window result.

| Unedited capture | State independently visible |
| --- | --- |
| [Split quote](practical_split_quote.png) | t=0, entered 5,001 kg M01, two vehicles priced 10,020 and 22, total 10,042, money 2,500 and no goods/admissions |
| [Refund](practical_refund.png) | t=0, cancelled 100 kg order, money restored to 2,500, spend 220/refund 220, admission released |
| [Blocked delivery](practical_blocked_delivery.png) | A58 t=63, eleven freight admissions, selected berthed delivery and waiting records, scrolled detail shows “Missing actual Receiving unloaders” |
| [Eight actual player people](practical_eight_player_people.png) | t=183, all eight distinct IDs visible after table scrolling; army ownership, Available duty at Personnel, selected row, zero incoming/personnel admission |
| [A58 recovered](practical_a58_recovered.png) | t=543, eight player people, four Receiving assignments, eleven kg M03 bought/deposited/free, zero aboard/carry and zero freight admission |

The live run also exercised quote/detail scrolling, unaffordable refusal, people row selection/assignment and all four time buttons. The full narrative is in the verification document. Captures were saved from the latest observation through shared current-state storage, not the earlier stale helper; saved files were visually inspected and have distinct SHA-256 hashes. No runtime/UI defect was found. One unknown screenshot-token error recovered after one activation/fresh capture, and native input continued successfully.

## Remaining limits

A requested literal 1280×720 physical window previously extended beyond the portrait desktop. That attempt did not pass native display verification. The newly approved practical case above passed instead; no display orientation/resolution was changed. Literal 1280×720 physical display and D01 production presentation/platform/readability remain unverified. Earlier per-step capture limitations remain disclosed, and issue #10 remains open for Game Designer acceptance/merge.

Partial storage, sub-second timing boundaries, capacity saturation and concurrent personnel handling retain engine regression coverage only. This session makes no native verification claim for those additional cases.
