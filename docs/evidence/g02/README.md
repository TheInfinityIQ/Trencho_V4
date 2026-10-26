# G02 native session evidence — 26 October 2026

Code reviewed and exercised: `17081be0f0822d7de459854caf1dd91725228cc5`, branch `codex/g02-procurement-receiving`, PR #51. Engine: Steam Godot `4.7.2.stable.steam.ed1daf0bf`, Windows/OpenGL Compatibility, NVIDIA RTX 4070 Ti. No runtime edits were made during verification.

The human confirmed that the desktop was available. The 960×540 game window accepted native clicks and keyboard input. [The verification record](../../g02_receiving.md#native-observations-at-960540) gives the observed A04/A58, passenger cadence, atomic quote/refund and duty handoff results. These are native session observations, distinct from the passing engine-driven regression/interface checks.

## Retained captures

- [Arrival with cargo aboard](a04_arrival_aboard.png): t=60, 100 kg aboard, zero carried/deposited/free, zero people/workers, one freight admission. This capture precedes the t=70 stopped-berth checkpoint.
- [Portrait desktop fit](portrait_desktop_fit.png): complete Terminal after maximizing on the available portrait desktop, with aspect-preserving letterboxing. This is a fresh zero-worker fixture, not recovery evidence. It does not prove a fully visible 1280×720 physical window or normal-size interactions.

Captures are unedited native screenshots. Screenshot export validation found that a helper retained an earlier observation rather than each intended checkpoint. Duplicate exports were discarded; the one valid earlier frame was named for the state it actually shows. Consequently there are no independently retained screenshots of the later recovery/refund checkpoints. Their results are recorded from the screenshots inspected during the live interaction session; do not present the two retained images as proof of every row.

## Remaining native check

A requested 1280×720 window extended beyond the available portrait desktop. Maximizing displayed a complete letterboxed Terminal. Subsequent input targeting failed; after refreshing the target, a click was rejected because its mapped point belonged to another application. No click was sent to that application, and native input stopped. A fully visible normal-size run across populated tabs is still needed. The draft PR and issue remain open for this check and Game Designer acceptance.

Partial storage, sub-second timing boundaries, capacity saturation and concurrent personnel handling retain engine regression coverage only. This session makes no native verification claim for those additional cases.
