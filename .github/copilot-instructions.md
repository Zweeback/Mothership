# Copilot instructions — Dortmund GameMap

Primary project: `godot/dortmund/`.

- Engine target: Godot 4.7.1, GDScript, GL Compatibility renderer, Android ARM64.
- Canonical city asset: `godot/dortmund/assets/dortmund.glb`.
- Canonical GLB SHA-256: `2dc4b395603448feb2a27eca2046f2aa5c20d217b2df75fa8512a64b7b3f8327`.
- Never silently replace the Full Model with `Dortmund_LoD2.glb`, procedural blocks, or another mesh in release work.
- Preserve the GLB's embedded materials and 16K texture unless a deliberate optimized derivative is being created under a different filename.
- The source GLB uses very large georeferenced coordinates; keep the recenter-to-local-space step.
- Default startup mode is the orthographic full-map view. `PLAY` changes to third person.
- Prefer mobile-safe optimizations that do not destroy the canonical source asset: import settings, derived textures, streaming/chunking, simplified collision and runtime LODs.
- Do not generate dense per-triangle collision from the full visual mesh for Android.
- CI must verify the canonical GLB hash before claiming a Full-Model APK.
- Keep project changes under `godot/dortmund/` unless modifying its dedicated workflow or these Copilot instructions.
