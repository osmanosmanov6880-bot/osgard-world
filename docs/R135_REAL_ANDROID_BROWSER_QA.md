# OSGARD R135 — Android physical-browser evidence capture

This utility **does not claim a benchmark by itself**. It reads the live R135
read-only in-browser Godot QA state from a Chrome instance the tester explicitly
connects through local USB debugging. No FPS data is uploaded to OSGARD servers.

## On an actual Android handset (local tester, not CI)

1. Enable USB debugging only on a device you control. Attach it to the computer.
2. Launch Chrome and open `https://osgard.world/games/r135-service/`.
3. Verify `adb devices` shows your device as authorized.
4. Start a *localhost-only* CDP USB forward:

   `adb forward tcp:9222 localabstract:chrome_devtools_remote`

5. On the development computer, install the project's Playwright dependency.
6. Run:

   `node scripts/r135-device-evidence.mjs --cdp http://127.0.0.1:9222 --url https://osgard.world/games/r135-service/ --seconds 60 --out r135-android-qa.json --physical-device-attested`

7. Save both JSON and PNG as acceptance evidence. Repeat in ECO and HERO.
8. Disable USB debugging and remove port forwarding when finished.

**Security:** never bind CDP to a public interface, and never share a CDP
endpoint or device debugging keys. Evidence stays on the local computer unless
the tester explicitly sends the files.

## What is captured

- Exact server release version and Git source SHA from `release.json`.
- Time-stamped Godot `Engine.get_frames_per_second` samples while foregrounded.
- Sample median, p05, p01, p95, share below 30, viewport dimensions and browser
  context plus a real viewport screenshot.

**Important limitations:**
- Sampled FPS percentiles are not true per-frame 1% low measurements.
- Physical-device status is *user-attested*, not proven by the CDP protocol.
- iPhone Safari needs a separate Web Inspector workflow. No Safari capture is
  claimed here.
- Thermals, battery drain, touch latency and hands-on playability need
  additional independent measurements. None are invented.
- If the screenshot reveals unreadable text or clipping, fail the visual gate
  regardless of FPS.
