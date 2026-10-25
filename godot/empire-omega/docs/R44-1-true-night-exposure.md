# EMPIRE Ω R44.1 — night luminance defect found from actual engine screenshots

First genuine Godot XVFB R44 output revealed a material defect not caught by
the original night capture gate: the frame at 22:00 was BRIGHTER than the noon
frame. The scripted clock changed window emissive lights but kept strong sky
and ambient light. A close lamp also occluded the car in the QA capture.

This patch adjusts **actual Godot Environment, sky, directional sunlight**
after the original weather-dependent grade. 18:00–20:00 and 05:30–07:30
interpolate safely. At 22:00: 0.018 directional sun energy; 0.20 residual
ambient, no black image; a darker procedural sky/ground and 0.86 filmic
brightness. Existing four warm local OmniLight3D nodes supply nearby visible
light, subject to LOW/STANDARD/CINEMATIC budget. No extra draw calls, GPU
shadowmaps, screen overlays or user data changes.

Native v68 verifies daylight, dusk/night transitions, nonfinite time,
actual world renderer and 4-light cap. Real day/night captures are required
to pass a **night mean luminance below 86% of noon mean**, plus existing black/
white range and non-identical pixel checks. Captured car is repositioned 9m
away from the original lamp-occluded QA angle; actual rendered game and
collision models are not modified. Human review of both PNGs still required.

No claim of AAA materials or GPU FPS from software-rasterized CI.
