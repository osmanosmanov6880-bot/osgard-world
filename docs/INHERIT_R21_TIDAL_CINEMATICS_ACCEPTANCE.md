# INHERIT R21 — cinematic surf / hardware acceptance

## Implementation
A real, original coastline ribbon replaces the R16 flat white line with a mesh
that follows the same coast as the terrain. A single merged draw call covers
three LODs: low **384**, medium **1,280**, high **2,880** triangles.
Shader-animated swells, foam filaments and seamless wave breakage respond to the
fictional game's season, wind and light. Reduced-motion freezes the animation;
nothing touches placements, generations, saves, game rights, or account logic.
No CDN, remote textures, extra animation timers, runtime fetch or WebGL2-only API.

## Build and acceptance
1. `npm ci && npm run qa:inherit-3d && npm run build`.
2. In actual desktop Chrome, run `npm run qa:inherit-benchmark:gpu`.
3. Run the in-game 10-second FPS benchmark on an actual mobile GPU; capture
   viewport/DPR, quality tier, camera/settings, p95 frame time, CPU submission,
   GPU timer only if supported, and device power/thermal conditions.
4. Test tide/wind/sun/mist, Low/Medium/High, 2D fallback, Atlas replay,
   saved-place interactions, reduced motion and browser context loss.
5. Compare screenshots for visual quality and profile real performance separately
   on a mobile and desktop device. Headless SwiftShader is not a physical GPU.
6. Evaluate observed JSON through `scripts/inherit-device-acceptance.mjs`.
   Do not label hardware verified solely from WebGL adapter strings.

Do not merge until browser QA is green. Actual physical-GPU FPS remains
**unverified in this remote environment** until on-device reports are attached.
