# Full Dortmund asset

Release builds require exactly `assets/dortmund.glb`.

Canonical model metadata:

- size: 143,229,592 bytes (~137 MiB)
- SHA-256: `2dc4b395603448feb2a27eca2046f2aa5c20d217b2df75fa8512a64b7b3f8327`
- geometry: ~704,915 triangles / 2,114,612 vertices
- footprint: ~1,336 m × 1,140 m
- embedded texture: 16,384 × 16,384 JPEG

**Do not substitute `Dortmund_LoD2.glb`.**

The CI workflow resolves the asset in this order:

1. Git LFS checkout if `assets/dortmund.glb` is tracked and available.
2. GitHub Release asset named `dortmund.glb` on tag `dortmund-assets-v1`.
3. Fail the release build explicitly. It never publishes a placeholder as the Full-Model APK.
