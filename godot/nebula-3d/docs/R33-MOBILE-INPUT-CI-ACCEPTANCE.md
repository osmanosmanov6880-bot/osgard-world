# NEBULA R33 — real mobile input acceptance on hosted CI

## What this actually proves

1. Godot 4.7.2 parses and runs the native `world.tscn`, with a real
   `CharacterBody3D` ship, physical movement, combat and mission systems.
2. The exported WebAssembly bundle boots in actual Chromium. The R25 full
   visual-world scenario must fly, steer, approach an objective and disengage
   autopilot. It remains a **hard** CI gate.
3. The separate R31 mobile scenario sends genuine Chrome DevTools
   `Input.dispatchTouchEvent` events to the real canvas. Godot must report
   real touch events, thrust, acceleration/distance, boost, and release;
   portrait and landscape layout checks are **hard** CI gates.
4. Mobile test has an explicit `?r31-mobile-qa=1` flag. It disables rendering
   of nonessential city meshes for software-GL runners only. The full scene is
   still loaded; **all physics, collision bodies, player, missions and HUD
   remain active**. The flag is off for every normal visitor.
5. Browser QA telemetry has no identities, tokens, store inventory or purchases.
   If it fails, it saves JSON artifacts with actual Godot state and DOM state.

## What this does not prove

- AAA visuals, actual Android/iOS GPU performance or acceptable smartphone FPS
- GPU frame time; headless hosted Chromium uses the SwiftShader software renderer
- Fidelity of images obtained from a compositor that repeatedly hangs on readback
- Every target phone's notch, safe area, OS touch behaviour or battery usage

The R11 screenshot/capture job remains an **advisory** with artifacts: a failed
readback must **never** be described as a successful GPU render. Production
release requires a separate real-device test on representative phones before
claiming compatibility.

## Review matrix

| Check | Source | Result requirement |
|---|---|---|
| Native scene + physics | Godot headless smoke | Must pass |
| Full visual-world keyboard flight | Chromium WebAssembly R25 | Must pass |
| Mobile CSS width / height | R31 telemetry | Must reflect device viewport |
| Real DOM touchscreen dispatch | Chrome DevTools | Must reach canvas |
| Real Godot touch event | Mobile script diagnostics | Must reach engine |
| GAS ship distance | Godot CharacterBody3D telemetry | Must move |
| GAS+BOOST, release | Real engine inputs | Must work |
| Portrait → landscape | Browser viewport + Godot UI | Must work |
| Compact landscape 568×320 | Native geometry assertions R32 | Must pass |
| SwiftShader screenshots | R11 advisory | Record evidence, no fabricated pass |
