"use strict";
const assert = require("node:assert/strict");
const test = require("node:test");
const fs = require("node:fs");
const path = require("node:path");
const C = require("../studio/core.js");

test("new studio uses only linked existing repositories, no fake completions", () => {
  const s = C.emptyState();
  assert.equal(s.projects.length, 3);
  assert.deepEqual(s.tasks, []);
  assert.deepEqual(s.ideas, []);
  assert.deepEqual(s.assets, []);
  assert.ok(s.projects.every(p => p.stage === "linked" && p.repository.startsWith("https://github.com/Zweeback/")));
});

test("idea -> production produces one real handoff in open state", () => {
  let s = C.emptyState();
  s = C.idea(s, { title: "Testschloss", description: "Film und Spiel teilen eine Szene", medium: "shared" });
  assert.equal(s.ideas[0].id, "I-001");
  assert.equal(s.ideas[0].status, "draft");
  s = C.promote(s, "I-001");
  assert.equal(s.ideas[0].status, "promoted");
  assert.equal(s.projects[0].id, "P-004");
  assert.equal(s.projects[0].ideaId, "I-001");
  assert.equal(s.tasks[0].projectId, "P-004");
  assert.equal(s.tasks[0].status, "open");
  assert.throws(() => C.promote(s, "I-001"), /bereits/);
});

test("handoff requires known project and valid department", () => {
  const s = C.emptyState();
  const input = {
    projectId: "P-001", title: "Gebäude GLB", from: "Ideenlabor",
    to: "3D Asset Factory", deliverable: "Mesh mit nachvollziehbarer Lizenz"
  };
  let next = C.handoff(s, input);
  assert.equal(next.tasks[0].id, "T-001");
  assert.equal(next.tasks[0].to, "3D Asset Factory");
  assert.throws(() => C.handoff(s, { ...input, projectId: "P-404" }), /Projekt nicht gefunden/);
  assert.throws(() => C.handoff(s, { ...input, to: "Unsichtbare Abteilung" }), /ungültig/);
});

test("handoff cannot be approved without evidence and reviewer", () => {
  const s = C.handoff(C.emptyState(), {
    projectId: "P-002", title: "Testlauf", from: "Engineering & R&D",
    to: "QA & Review", deliverable: "Testprotokoll"
  });
  assert.throws(() => C.taskUpdate(s, "T-001", "approve", { approvedBy: "QA" }), /Ungültiger Statuswechsel/);
  const started = C.taskUpdate(s, "T-001", "start");
  assert.equal(started.tasks[0].status, "in_progress");
  assert.throws(() => C.taskUpdate(started, "T-001", "submit", { evidence: "" }), /erforderlich/);
  const submitted = C.taskUpdate(started, "T-001", "submit", { evidence: "reports/qa.json" });
  assert.throws(() => C.taskUpdate(submitted, "T-001", "approve", { approvedBy: "" }), /erforderlich/);
  const accepted = C.taskUpdate(submitted, "T-001", "approve", { approvedBy: "Prüfer" });
  assert.equal(accepted.tasks[0].status, "accepted");
  assert.equal(C.stats(accepted).tasks, 0);
  assert.equal(C.stats(accepted).accepted, 1);
  assert.equal(s.tasks[0].status, "open", "operations must not mutate their inputs");
});

test("returned work can be rejected back to open", () => {
  let s = C.handoff(C.emptyState(), { projectId: "P-003", title: "Shader", from: "Art Direction", to: "Engineering & R&D", deliverable: "GLSL-Datei" });
  s = C.taskUpdate(s, "T-001", "start");
  s = C.taskUpdate(s, "T-001", "submit", { evidence: "commit abc" });
  s = C.taskUpdate(s, "T-001", "reopen");
  assert.equal(s.tasks[0].status, "open");
  assert.equal(s.tasks[0].approvedBy, "");
});

test("asset cannot be created without provenance and manual review leaves verifiable field", () => {
  const input = { projectId: "P-001", name: "Schloss", format: ".glb", location: "models/schloss.glb", license: "Eigene Produktion" };
  assert.throws(() => C.asset(C.emptyState(), { ...input, license: " " }), /erforderlich/);
  const s = C.asset(C.emptyState(), input);
  assert.equal(s.assets[0].status, "registered");
  assert.throws(() => C.assetReview(s, "A-001", "", "B"), /erforderlich/);
  const reviewed = C.assetReview(s, "A-001", "Manueller Blicktest", "B");
  assert.equal(reviewed.assets[0].status, "reviewed");
  assert.equal(s.assets[0].status, "registered");
});

test("import/export validation rejects wrong schema, duplicate IDs and missing fields", () => {
  const s = C.emptyState();
  assert.deepEqual(C.validateImport(JSON.parse(JSON.stringify(s))), s);
  assert.throws(() => C.validateImport({ version: 99 }), /Datenversion/);
  const malformed = C.emptyState();
  malformed.ideas.push({ id: "I-001", title: "Titel", medium: "film", description: "x", status: "draft" });
  malformed.ideas.push({ ...malformed.ideas[0] });
  assert.throws(() => C.validateImport(malformed), /doppelte ID/);
  assert.throws(() => C.validateImport({ ...s, assets: {} }), /Datenstruktur/);
});

test("static page references existing scripts and exposes required controls", () => {
  const html = fs.readFileSync(path.join(__dirname, "../index.html"), "utf8");
  for (const id of ["idea-form", "task-form", "asset-form", "export-btn", "import-file", "view-projects", "view-data"]) {
    assert.ok(html.includes('id="' + id + '"'), "Missing element: " + id);
  }
  assert.ok(fs.existsSync(path.join(__dirname, "../studio/core.js")));
  assert.ok(fs.existsSync(path.join(__dirname, "../studio/app.js")));
  assert.match(html, /<meta name="viewport"/);
  assert.match(html, /src="studio\/core\.js"/);
  assert.match(html, /src="studio\/app\.js"/);
});
