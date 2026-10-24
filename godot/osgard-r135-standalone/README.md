# OSGARD R135 — isolated standalone bootstrapping

This directory contains the reconstructed standalone scene and app configuration.

**Important**: This GitHub directory is currently a SOURCE BOOTSTRAP, not a complete playable artifact: it requires `R135ServiceDirector.gd`, 2 original GLBs, and associated PBR textures from the reconstructed 107 MB ZIP delivered in the conversation. The complete ZIP contains its own more feature-complete `StandaloneMain.gd` with reset-camera control and HUD.

The legacy R135 `Main.gd` depended on absent R131–R134 sources. This implementation avoids those dependencies and uses the standalone R135 controller. Do not deploy or overwrite `godot/osgard-r136-precision`. Godot runtime testing has not been performed; asset SHA checks passed.
