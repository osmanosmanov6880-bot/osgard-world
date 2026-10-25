# R135 W11 — physical hardware acceptance (not yet performed)

This document separates verified software-rendered WebGL gameplay from **unperformed** physical-device measurements. The W11 browser release may be described as software-tested, but **not** hardware-certified or AAA.

## Reproducible Android Chrome test

1. On a personal or otherwise authorized Android device: enable USB debugging, connect with a data USB cable, and confirm `adb devices` shows an authorized device. Do not expose DevTools/CDP outside localhost.
2. Open the **exact published** `https://osgard.world/games/r135-service/` in Chrome and inspect `release.json` to record source commit and release version.
3. Forward CDP locally only: `adb forward tcp:9222 localabstract:chrome_devtools_remote`.
4. From this repository, use `node scripts/r135-device-evidence.mjs --cdp http://127.0.0.1:9222 --url https://osgard.world/games/r135-service/ --seconds 60 --out r135-android-eco.json --physical-device-attested`.
5. Save the JSON and PNG. Repeat for ECO and HERO after switching modes **inside the game**, and for portrait/landscape where available. Record device model, OS/browser versions, battery state and an external thermal observation. This harness does not measure thermal sensors or device power itself.
6. Test the real eight touch controls, the four-step mission, one complete five-step diagnostic fault, hatch interlock rejection and camera controls. Note manual failures and screen readability.
7. Revoke the forwarding and disable USB debugging: `adb forward --remove tcp:9222`. Never publish your debugging endpoint.

## Safari/iOS

Use a physically connected iPhone with Safari's Web Inspector and an independent local recording method. Record the **same release manifest**, a readable portrait screenshot, actual interactions and a documented frame-time/fps measurement method. Android CDP data cannot certify iOS Safari.

## Acceptance and evidence integrity

- No skipped controls, unsafe interlock bypass, clipped fault labels, or canvas outside the viewport in any tested orientation.
- Establish device-specific performance budgets *before* interpreting the data. Record raw time-stamped samples as well as the median and spread. Sampled FPS p01/p05 are **not** per-frame 1% lows.
- Compare ECO/HERO at similar state and temperature. Repeat at least twice; reject clearly inconsistent or unrepeatable readings.
- Preserve the device model, exact W11 source SHA, manifest hash, screenshots, method, software/physical distinction, and observed defects in the QA report.
- Avoid making unmeasured claims about thermals, 60 FPS, 8K quality, or photorealism.
- All physical GPU, iOS Safari, battery and heat results remain **NOT MEASURED** until signed-off device evidence is attached.

## Release isolation

R135 W11's checksum-pinned browser release must never overwrite other `/games/*` routes. Preserve rollback to the independent known-good W6.4 build until deployed W11 and adjacent games have passed public byte and route audits.
