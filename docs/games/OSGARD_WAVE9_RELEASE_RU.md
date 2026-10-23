# OSGARD WORLD / Wave 9 — precision art and coastlines

**Projects:** VECTOR//ZERO Blackfield and CHRONOS CITY, built with Godot 4.7.2.

## What changed

VECTOR//ZERO gains one prominent new 3D focal assembly: an exposed, indexed copper helical busbar, three concentric PBR CNC rings, 48/96 GPU-instanced forged clamps, two polarity-driven servo jaws, hydraulic reservoirs, physically modeled industrial piping, inspection signals and restrained warm highlights. Gameplay physics and existing Russian HUD remain untouched.

CHRONOS CITY gains a GPU-batched, physically supported coastal promenade with 24/48 foundation piles; seven biodiverse terraced parks with instanced geometry; a unique waterfront observatory; twin moving service shuttles; balanced sky and low-key post processing. Economic saves and production rates remain unchanged.

- Each new material has its own albedo, normal, metallic and roughness controls sourced from prior Wave 8 maps.
- Web uses reduced radial segment counts / instance counts; Windows Forward+ retains higher detail.
- No external commercial game assets are used.
- No inference that high-poly geometry equals photorealism is made.

## Verification and deployment

CI should run baseline smoke tests, Wave 9 smoke tests, Godot Web export, Windows PC export and a native renderer capture. CI software performance is **not** physical GPU evidence.

Hardware certification requires actually executing the Windows builds with `TEST_GPU_WAVE7_ALL.cmd` and inspecting the eight JSON results from 1080p/1440p + Ultra/Balanced. The connected environment has no `/dev/dri` and no NVIDIA GPU.

Target criteria on the user's intended hardware: stable 60 FPS (mean), p95 <= 16.67 ms for each profile, and no instability. The target is not a claim of measured performance.

This work does **not** merge its PRs or deploy to osgard.world. Additional art iteration and physical performance testing are required before production.
