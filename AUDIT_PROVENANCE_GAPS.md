# Provenance Blindspots Audit Report

## 1. Executive Summary

An independent audit of the repository's git history, remote branches, workflow configurations, and state models was performed to identify provenance blindspots—specifically, scenarios where work or ideas appear 'blocked' and vanish from project continuity without leaving trace artifacts on the main branch.

Key findings:
- The `main` branch contains only two top-level files (`README.md` and `.github/workflows/cache-godot-4.7.1.yml`), while full subsystems, tests, CI workflows, and documentation exist across isolated, unmerged feature branches (`origin/feat/irl-quality-offensive`, `origin/gapguard-apk-build`, `origin/godot/dortmund-master`, `origin/infra/current-visual-status`, `origin/build/dortmund-godot-apk`).
- Temporary workflows and scripts have been deleted in git commits on `main` (e.g., `08a2c28647eeb6c747fc30ae5e2cdae369a781c9` deleted `.github/workflows/drive-stream-inventory.yml`), creating a distinction between items that were **actually deleted** on `main` versus items that are **catalog-missing** from `main` because they were authored on unmerged feature branches.
- Conflicting state models exist across branches: `origin/infra/current-visual-status` (`docs/status/current.json`) indicates `stage: "PROTOTYPE"` and `next_acceptance_gate: "Recover the canonical Godot project..."`, whereas `origin/godot/dortmund-master` already contains the recovered Godot project (`godot/dortmund/project.godot`, `godot/dortmund/scripts/main.gd`).

---

## 2. Verified Findings & Provenance Blindspots

### 2.1 Assistant / Tool Block Claims Leading to Abandoned Branches
- **Branch**: `origin/copilot/build-provenance-gap-scanner`
- **Commit**: `d74ef50d8dedb8f0ae49d26f2c4299a1870da5c0` ("Initial plan")
- **Details**: An automated assistant created an initial commit adding `.github/workflows/cache-godot-4.7.1.yml` and updating `README.md`, but no scanner or audit code was implemented. The branch remained unmerged and abandoned.
- **Impact**: Without cross-branch discovery, tasks assigned on dedicated feature branches appear stalled or lost when inspecting only `main`.

### 2.2 Catalog-Missing vs. Actually-Deleted State Distinction
- **Actually Deleted on Main**:
  - File: `.github/workflows/drive-stream-inventory.yml`
  - History: Added in commit `170ac6edc2e6461bce5c5898f382a99a79a51cee` ("Trigger optimized data salvage workflow") on `main`.
  - Deleted in commit: `08a2c28647eeb6c747fc30ae5e2cdae369a781c9` ("Remove temporary Drive stream worker after successful salvage") on `main`.
  - Significance: Git commit history explicitly proves prior existence and deliberate removal on `main`.
- **Catalog-Missing from Main (Branch-Isolated)**:
  - `irl-stream-stack/bootstrap.sh`, `irl-stream-stack/verify.sh` on branch `origin/feat/irl-quality-offensive` (commit `8d37002c44ae2a44bb1093fe0539a7d3db2d7fa9`).
  - `.ci/gapguard/gapguard-v0.3.patch`, `builds/gapguard/source.b64.part1-6` on branch `origin/gapguard-apk-build` (commit `5daa2e884fa254962e7e4a1c868236d2a7f49081`).
  - `godot/dortmund/project.godot`, `godot/dortmund/scripts/main.gd` on branch `origin/godot/dortmund-master` (commit `d1e3a17d2f748aec3a6b2c3febd2d117822a3b91`).
  - `docs/status/current.json`, `docs/status/current.png` on branch `origin/infra/current-visual-status` (commit `cc54ea2cdff952c43656b6a56aa9f4e4d93fd569`).
  - Significance: These files are not deleted; they are catalog-missing on `main` due to unmerged topic branches.

### 2.3 Ephemeral Secrets, Signed URLs, and Credential Exposure Vectors
- **Google Drive Stream File ID**:
  - File: `.github/workflows/drive-stream-inventory.yml` (commit `170ac6edc2e6461bce5c5898f382a99a79a51cee`, line 12)
  - Raw value: `FILE_ID: 1rONvxcNPn1r41h_ELj5IJ5d7keEmd6Uj`
  - Significance: Directly exposes external resource identifiers in workflow environment variables without anonymization or secret storage.
- **Pinggy Free Raw-TCP Tunnel Script**:
  - File: `irl-stream-stack/temporary-free-rtmp-tunnel.sh` (commit `8d37002c44ae2a44bb1093fe0539a7d3db2d7fa9`, lines 22-29)
  - Detail: Connects to `tcp@free.pinggy.io` over port 443 with SSH option `StrictHostKeyChecking=no`.
- **Generated Muxshed API Key Format**:
  - File: `irl-stream-stack/bootstrap.sh` (commit `8d37002c44ae2a44bb1093fe0539a7d3db2d7fa9`, line 32)
  - Detail: Key matching regex `^mxs_[0-9a-f]{48}$` written to local runtime environment file `/opt/irl-stack/runtime-secrets.env`.

---

## 3. Duplicate and Conflicting State Models

| Subsystem / Subject | State in `main` | State in Remote Branch | Conflict / Discrepancy | File / Line References |
| :--- | :--- | :--- | :--- | :--- |
| Project Status Visual | Non-existent | `docs/status/current.json` on `origin/infra/current-visual-status` | Claims `stage: PROTOTYPE` and `runtime_verified: false` | `docs/status/current.json` lines 1-8 |
| Dortmund Godot Engine | Missing from catalog | Fully present on `origin/godot/dortmund-master` | `docs/status` claims Godot project needs recovery, but `godot/dortmund` is already intact with 15 files and CI workflow | `godot/dortmund/project.godot`, `.github/workflows/dortmund-full-apk.yml` |
| IRL Stream Stack | Missing from catalog | Present on `origin/feat/irl-quality-offensive` | Stack bootstrap and contract tests pass, but stack code is absent from `main` | `irl-stream-stack/bootstrap.sh`, `irl-stream-stack/README.md` |
| GapGuard APK Build | Missing from catalog | Present on `origin/gapguard-apk-build` | Base64 source split parts (`source.b64.part1-6`) and patch file exist on feature branch, completely absent from `main` | `builds/gapguard/`, `.ci/gapguard/gapguard-v0.3.patch` |

---

## 4. Regression Fixtures & Test Verification

Regression fixtures and unit tests were added under `tests/`:

1. **`tests/fixtures/block_and_abandon_scenario.json`**:
   Models assistant block claims, abandoned feature branches, missing artifacts, and subsequent rediscovery on isolated branches.
2. **`tests/fixtures/catalog_vs_deleted_scenario.json`**:
   Differentiates between files missing from `main` catalog (branch-isolated), files deleted via explicit git commits on `main`, and non-existent paths.
3. **`tests/fixtures/ephemeral_secrets_scenario.json`**:
   Provides sample raw evidence including Google Drive File IDs, Pinggy RTMP tunnel endpoints, OAuth Bearer tokens, JWT strings, and Muxshed API keys.
4. **`tests/test_provenance_regressions.py`**:
   Includes tests validating the fixtures and testing secret redaction (`redact_secrets`).

### Test Execution Output

```
python3 -m unittest discover -s tests
...
----------------------------------------------------------------------
Ran 3 tests in 0.003s

OK
```

---

## 5. Remaining Unknowns

1. **Remote Build Artifact Preservation**:
   Whether APK build artifacts generated in historical GitHub Actions runs for `gapguard-apk-build` or `dortmund-full-apk` remain downloadable or have expired past GitHub's retention policy (typically 30-90 days).
2. **Upstream Google Drive Blob Accessibility**:
   Whether the Google Drive File ID (`1rONvxcNPn1r41h_ELj5IJ5d7keEmd6Uj`) referenced in `drive-stream-inventory.yml` remains publicly accessible or requires authorization credentials.
