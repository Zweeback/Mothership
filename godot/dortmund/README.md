# Dortmund GameMap — Full Model

Godot 4.7.1 mobile-first Dortmund exploration project.

## Canonical model

This project uses **`assets/dortmund.glb`**, not the LoD2 substitute.

- 143,229,592 bytes
- SHA-256 `2dc4b395603448feb2a27eca2046f2aa5c20d217b2df75fa8512a64b7b3f8327`
- ~704,915 triangles
- ~2,114,612 vertices
- ~1.336 × 1.140 km footprint
- embedded 16K JPEG texture

## Current game flow

1. Import the full GLB with Godot.
2. Preserve its original embedded materials/textures.
3. Recenter the large georeferenced coordinates into stable local game space.
4. Start in an orthographic bird's-eye map view framed to the model footprint.
5. `PLAY` switches to third-person exploration.
6. Android touch joystick, right-side drag look, jump, run, reset and MAP/PLAY HUD are available.

## Local

Open `project.godot` with Godot 4.7.1. `assets/dortmund.glb` must be present for the real map.

## CI / Android

`.github/workflows/dortmund-full-apk.yml` builds ARM64 Android and validates the exact GLB SHA before import/export. The workflow first checks Git LFS, then the persistent GitHub Release `dortmund-assets-v1`.

The release workflow deliberately fails if the full asset is missing. A placeholder must never be labeled as a Dortmund Full-Model build.
