# MOTHERSHIP · Studio OS (MVP 0.1)

**A minimal, honest production hub for film, games, 3D and VR.**

## Start

Open **index.html** in a modern browser. No server, build step, account, or API key is required. The UI is in German and works on mobile. It uses plain JavaScript, CSS and browser localStorage. On a hosted static website the same files can be served as-is.

> GitHub renders index.html as source when you click it in the repository. To operate the app, download the repository ZIP and open index.html, or host the folder as a static site.

## What actually works

- **Ideenlabor:** enter a concept (film/game/both/VR), preserve it locally, promote it to a new production.
- **Production portfolio:** links to publicly available repos dortmundgamemap, tinyrush, alicealpha are seeds. A repository link does **not** imply a working build.
- **Handoffs:** create inter-department requests with explicit deliverables; move through open → in progress → submitted → accepted, or reject a submission back to open.
- **Evidence gate:** submissions require a text/file/commit reference and acceptance requires an explicitly named manual reviewer.
- **Asset registry:** record artifact type, project, location and license/provenance, with an optional manual review note.
- **Session audit trail:** in-app event list, persisted with the working data.
- **Portable backup:** export/import complete state as JSON.
- **Offline, zero-dependency interface:** no trackers or CDN scripts.
- **Automated core tests:** Node built-in test runner and GitHub Actions.

## Important limits

This is a **functional orchestration MVP**, not a renderer, asset converter, cloud service, or ChatGPT connector.

- All edits are local to the current browser profile. There is no cross-device, cross-chat or GitHub synchronization. Export JSON after significant work.
- Submitted task evidence is a **user-supplied reference**, not an automatic file/commit verification.
- Asset manual review is **not** a GLB parsing, topology, texture or rendering test.
- The project names from GitHub are **linked**, not imported as validated progress.
- The archive can be opened locally. A separate hosting setup is needed for a shareable live URL.

## Test

Requires Node.js 22 (no npm install):

    node --check studio/core.js
    node --check studio/app.js
    node --test tests/studio.test.js

The GitHub Actions workflow at .github/workflows/studio-mvp.yml repeats these checks.

## Architecture

    index.html             Responsive user interface (static/offline)
    studio/core.js         Dependency-free state machine and contracts
    studio/app.js          Browser controller, local storage, JSON I/O
    tests/studio.test.js   State-machine and static integration regression tests

A new idea creates a project and an open handoff to Engineering & R&D to assess feasibility. Later pipeline adapters can consume exported handoff JSON and link GitHub Issues or run real asset checks. This version deliberately does not claim they already exist.

## Next technical upgrade

1. Hosted persistence with project permissions (rather than browser-only localStorage).
2. GitHub Issues/Projects bridge with explicit authentication and confirmation.
3. Asset manifest verification against real files, hashes and licensing, using the existing Zweeback/dortmundgamemap/studio tools as a candidate.
4. Real render/build/test workers with execution logs, reproducible artifacts, and evidence-backed release gates.

See the original dortmundgamemap repository for the existing photo/video → 3D → GLB pipeline. Do not duplicate it in this frontend.
