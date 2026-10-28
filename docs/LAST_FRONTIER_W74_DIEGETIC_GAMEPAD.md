# LAST FRONTIER — W74 / LIVE FIELD FEEDBACK, NATIVE CONTROLLER & FRAME TELEMETRY

**Game engine:** Godot 4.4.1 | **Date:** 28 Oct 2026 | **Status:** Draft until exact-head CI succeeds.

**Exact baseline:** W73 `b006e9acaadae69b02976b4905e3a7c8262f072a`; [3/3 CI PASS](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40646206165), which already supplies real CharacterBody3D, Camera3D, real camera RayCast3D and seven physics collider machine elements, twelve original machine decisions, bounded offline session save/replay, six incident cycles, and true WebGL browser gameplay.

## Large block A — real cinematographic machine response in 3D

New `w63-a7-cascade/scripts/A7DiegeticFeedback.gd` creates eight original Godot **MeshInstance3D** props (not pictures): a thermal valve torus, three separately emissive real relay-bus contacts, three independent reactor containment rings, and a precision-machined panel insert, plus **Label3D** in the original world. The actual power state of each segment is read from **W72's real physically gated equipment**; HUD messages do not invent equipment changes.

The servo response lasts 680 ms using a restrained continuous sine envelope on actual 3D mesh scale/emissive response and native world position. Only successfully accepted mechanic interactions trigger it. The original first-person head turns toward actual equipment (W73 tested and corrected) with no teleports or invented cinematic video. Existing procedural audio gets one accepted local action cue per real mechanical actuation. On ECO the light stays controlled. Reduced motion disables mesh bounce/flash while keeping real 3D circuits and current state readable. On mobile the world Label3D disappears while gameplay remains unchanged.

**Source isolation:** original physics mission calculations, W63 action rules, W72 valve, relay and sync transitions, W73 real physics ray hit, and original session replay journal stay **byte-for-byte unchanged**. W74 rendering never calls original core `choose()`. The original W71 simple mission still hides W74 props.

## Large block B — genuine gamepad InputEvents, analog motion and actual gameplay

New `A7GamepadDirector.gd` routes Godot **InputEventJoypadMotion** and **InputEventJoypadButton** through the exact same accepted game source callbacks as the original keyboard/mobile UI. Real analog left stick (with 0.17 deadzone) drives **continuous original CharacterBody3D.move_and_slide physics**; right stick moves the actual eye camera with time-based angular speed. No teleport, no screen-space walking imitation.

| Controller control | Genuine action |
|---|---|
| Left analog | Physically walk, preserved analog speed and collision |
| Right analog | Rotate actual native first-person Camera3D |
| START | Start optional original W72 advanced 3D mission |
| Y | Enter/exit true 3D operator |
| B | Exit operator without restarting mission |
| A | Use real `RayCast3D` targeted machine; when not in advanced mode, physical E-style inspection |
| X | Inspect console only at original 3D distance and when mechanically solved |
| D-pad LEFT/RIGHT | Select among original PUMP, VENT, SEAL, SCAN, POWER |
| Right shoulder (RB/R1) | Commit selected ORIGINAL six-cycle game action, never a fake transition |
| Left shoulder (LB/L1) | Explicit local replay-based F5 save |
| BACK/SELECT | Explicit local replay-verified F9 restore |

The controller hint appears **only after a Godot controller event**, and only when actually controlling the original character. It is bilingual and compact. The native unit test constructs authentic Godot Joypad event instances and validates physical displacement/turning, 3D A-ray interactions, the exact original first incident and two accepted controller-driven core decisions, save/restore, ECO and reduced motion.

**Important distinction:** software-created Godot controller events in CI prove action mapping and source physics. No physical Xbox/PlayStation gamepad has been used or certified in this development environment. Real hardware playtests remain mandatory.

## Large block C — honest performance evidence, not fake 8K / 60 FPS marketing

New `A7FrameTelemetry.gd` samples **actual Godot `_process(delta)` frame intervals**, keeps a bounded 240-frame moving window, and calculates window mean frame time, true sorted p95, estimated window FPS, observed slower-than-50ms count and worst frame. It rejects impossible, NaN and Inf values. An in-game opt-in **F3** opens a small bilingual readout and F3 hides it. Default view stays uncluttered.

This is real runtime **software timing telemetry**, not a hardware graphics-profiler measurement. In particular, Linux headless SwiftShader results cannot establish 60 FPS on real NVIDIA/AMD/Intel GPUs, iOS/Android, 4K or 8K screens. The software reports these missing certifications as `false`.

## Exact-source native and web acceptance

W74 changes only ten audited paths. An immutable Git blob gate protects the prior original A7 `A7CascadeCore.gd`, W70 physical world source except **one explicit, tested analog input modification**, W72 genuine mech calculations, W73 local file verification and raycast scripts, all original tests, Main.tscn and project/export configuration.

CI must pass:

1. **Eleven** original real Godot native suites from W63 through W74, including W73 source-bound offline save/restore and W74 new genuine analog 3D navigation and native 3D feedback.
2. Valid Godot 4.4.1 real WebAssembly export with exact SHA and native `index.pck`, and original asset integrity verification.
3. Source-bound W73 Chromium full ray/physical world gameplay regression and new W74 genuine visual playthrough: actual player walking, F3 real p95 sampling, thermo valve + new native glow from K, actual G ray and native servo, RU/EN, 390px mobile. **14 real screenshot PNGs** with exact digest audit between two drivers.
4. Mandatory 3/3 CI jobs and a draft PR kept unmerged until latest exact SHA PASS.

## What remains for a genuinely market-ready AAA experience

W74 is a substantial true-engine gameplay-feel and input upgrade, but does **not** provide external expert-reviewed 3D models, actor/character animation, a measured 10–15 minute level, real GPU benchmarks, actual physical console verification, real user tested UI, full licensed original score/VO or legal clearance for the working name LAST FRONTIER.

**W75 next gate:** collect *actual* non-fabricated first-time player sessions, performance baselines from user hardware, and art direction/brand clearance evidence in an auditable structured readiness pack. A QA scoring form and source-bound build manifest can be implemented, but human participants or commercial approval cannot be invented.

**GO/NO-GO policy:** No production publish, Steam listing, public domain, merge to master or commercial claims without explicit user signoff and source-linked hardware/player evidence.
