(function (root) {
  "use strict";
  var VERSION = 1;
  var MEDIA = ["film", "game", "shared", "vr"];
  var DEPARTMENTS = [
    "Ideenlabor", "Writers' Room", "Art Direction", "3D Asset Factory",
    "Worldbuilding", "Animation & Cinematics", "Engineering & R&D",
    "Audio Studio", "Pipeline Engineering", "QA & Review", "Release"
  ];
  var REPOS = [
    { id: "P-001", name: "GTA Dortmund", medium: "game", stage: "linked",
      repository: "https://github.com/Zweeback/dortmundgamemap", origin: "GitHub-Repository" },
    { id: "P-002", name: "Tidy Rush / Parking Panic", medium: "game", stage: "linked",
      repository: "https://github.com/Zweeback/tinyrush", origin: "GitHub-Repository" },
    { id: "P-003", name: "ALICE", medium: "shared", stage: "linked",
      repository: "https://github.com/Zweeback/alicealpha", origin: "GitHub-Repository" }
  ];

  function emptyState() {
    return {
      version: VERSION,
      ideas: [],
      projects: REPOS.map(function (project) { return Object.assign({}, project); }),
      tasks: [],
      assets: [],
      events: []
    };
  }
  function copy(state) {
    return JSON.parse(JSON.stringify(state));
  }
  function str(value, maximum) {
    return String(value == null ? "" : value).trim().slice(0, maximum || 2000);
  }
  function required(value, field) {
    var result = str(value);
    if (!result) throw new Error(field + " ist erforderlich.");
    return result;
  }
  function oneOf(value, values, label) {
    if (values.indexOf(value) < 0) throw new Error(label + " ist ungültig.");
    return value;
  }
  function nextId(items, prefix) {
    var highest = items.reduce(function (max, item) {
      var match = new RegExp("^" + prefix + "-(\\d+)$").exec(item.id);
      return match ? Math.max(max, Number(match[1])) : max;
    }, 0);
    return prefix + "-" + String(highest + 1).padStart(3, "0");
  }
  function record(state, eventType, ref, detail) {
    state.events.unshift({
      at: new Date().toISOString(),
      type: eventType,
      ref: ref,
      detail: str(detail, 400)
    });
    state.events = state.events.slice(0, 250);
  }
  function idea(state, input) {
    var title = required(input.title, "Titel");
    var description = required(input.description, "Beschreibung");
    var medium = oneOf(input.medium, MEDIA, "Medium");
    var next = copy(state);
    var item = {
      id: nextId(next.ideas, "I"),
      title: title.slice(0, 120),
      medium: medium,
      description: description.slice(0, 1500),
      status: "draft",
      createdAt: new Date().toISOString()
    };
    next.ideas.unshift(item);
    record(next, "idea.created", item.id, item.title);
    return next;
  }
  function promote(state, ideaId) {
    var next = copy(state);
    var item = next.ideas.find(function (i) { return i.id === ideaId; });
    if (!item) throw new Error("Idee nicht gefunden.");
    if (item.status !== "draft") throw new Error("Idee wurde bereits übernommen.");
    var project = {
      id: nextId(next.projects, "P"),
      name: item.title,
      medium: item.medium,
      stage: "concept",
      ideaId: item.id,
      origin: "Ideenlabor"
    };
    next.projects.unshift(project);
    item.status = "promoted";
    var task = {
      id: nextId(next.tasks, "T"), projectId: project.id,
      title: "Konzept und Machbarkeit prüfen",
      from: "Ideenlabor", to: "Engineering & R&D",
      deliverable: "Konzeptprüfung mit technischen Risiken und Quellen",
      status: "open", evidence: "", approvedBy: ""
    };
    next.tasks.unshift(task);
    record(next, "idea.promoted", item.id, "Produktion " + project.id + " + Aufgabe " + task.id);
    return next;
  }
  function handoff(state, input) {
    var next = copy(state);
    if (!next.projects.some(function (p) { return p.id === input.projectId; })) {
      throw new Error("Projekt nicht gefunden.");
    }
    var item = {
      id: nextId(next.tasks, "T"),
      projectId: input.projectId,
      title: required(input.title, "Auftragstitel").slice(0, 120),
      from: oneOf(input.from, DEPARTMENTS, "Absenderabteilung"),
      to: oneOf(input.to, DEPARTMENTS, "Zielabteilung"),
      deliverable: required(input.deliverable, "Liefergegenstand").slice(0, 1200),
      status: "open", evidence: "", approvedBy: ""
    };
    next.tasks.unshift(item);
    record(next, "task.handoff", item.id, item.from + " → " + item.to);
    return next;
  }
  function taskUpdate(state, id, action, params) {
    var next = copy(state);
    var item = next.tasks.find(function (t) { return t.id === id; });
    if (!item) throw new Error("Aufgabe nicht gefunden.");
    var allowed = {
      start: ["open", "in_progress"],
      submit: ["in_progress", "submitted"],
      approve: ["submitted", "accepted"],
      reopen: ["submitted", "open"]
    };
    if (!allowed[action] || allowed[action][0] !== item.status) {
      throw new Error("Ungültiger Statuswechsel.");
    }
    if (action === "start") item.status = "in_progress";
    if (action === "submit") {
      item.evidence = required(params && params.evidence, "Nachweis").slice(0, 1200);
      item.status = "submitted";
    }
    if (action === "approve") {
      item.approvedBy = required(params && params.approvedBy, "Prüfende Person").slice(0, 120);
      item.status = "accepted";
    }
    if (action === "reopen") {
      item.status = "open";
      item.approvedBy = "";
    }
    record(next, "task." + action, id, item.status);
    return next;
  }
  function asset(state, input) {
    var next = copy(state);
    if (!next.projects.some(function (p) { return p.id === input.projectId; })) {
      throw new Error("Projekt nicht gefunden.");
    }
    var item = {
      id: nextId(next.assets, "A"),
      projectId: input.projectId,
      name: required(input.name, "Assetname").slice(0, 120),
      format: required(input.format, "Format").slice(0, 20),
      location: required(input.location, "Dateiverweis").slice(0, 1000),
      license: required(input.license, "Lizenz / Herkunft").slice(0, 200),
      status: "registered",
      reviewEvidence: "",
      reviewer: ""
    };
    next.assets.unshift(item);
    record(next, "asset.registered", item.id, item.name);
    return next;
  }
  function assetReview(state, id, evidence, reviewer) {
    var next = copy(state);
    var item = next.assets.find(function (a) { return a.id === id; });
    if (!item) throw new Error("Asset nicht gefunden.");
    item.reviewEvidence = required(evidence, "Prüfvermerk").slice(0, 1200);
    item.reviewer = required(reviewer, "Prüfende Person").slice(0, 120);
    item.status = "reviewed";
    record(next, "asset.reviewed", id, item.reviewer);
    return next;
  }
  function stats(state) {
    return {
      ideas: state.ideas.filter(function (i) { return i.status === "draft"; }).length,
      productions: state.projects.length,
      tasks: state.tasks.filter(function (t) { return t.status !== "accepted"; }).length,
      accepted: state.tasks.filter(function (t) { return t.status === "accepted"; }).length,
      assets: state.assets.length
    };
  }
  function validId(value) {
    return /^[A-Z]-\d{3,}$/.test(value);
  }
  function validateImport(data) {
    if (!data || data.version !== VERSION) throw new Error("Unbekannte Datenversion.");
    ["ideas", "projects", "tasks", "assets", "events"].forEach(function (key) {
      if (!Array.isArray(data[key]) || data[key].length > 5000) {
        throw new Error("Ungültige Datenstruktur: " + key);
      }
    });
    var requiredKeys = {
      ideas: ["id", "title", "medium", "description", "status"],
      projects: ["id", "name", "medium", "stage"],
      tasks: ["id", "title", "projectId", "from", "to", "status", "deliverable"],
      assets: ["id", "projectId", "name", "format", "location", "license", "status"]
    };
    Object.keys(requiredKeys).forEach(function (key) {
      var seen = {};
      data[key].forEach(function (item) {
        if (!item || typeof item !== "object" || !validId(item.id) || seen[item.id]) {
          throw new Error("Ungültige / doppelte ID: " + key);
        }
        seen[item.id] = true;
        requiredKeys[key].forEach(function (prop) {
          if (typeof item[prop] !== "string" || !item[prop].trim()) {
            throw new Error("Ungültiges Feld " + key + "." + prop);
          }
        });
      });
    });
    return copy(data);
  }
  var core = {
    VERSION: VERSION, DEPARTMENTS: DEPARTMENTS, MEDIA: MEDIA, REPOS: REPOS,
    emptyState: emptyState, idea: idea, promote: promote,
    handoff: handoff, taskUpdate: taskUpdate, asset: asset,
    assetReview: assetReview, stats: stats, validateImport: validateImport
  };
  if (typeof module !== "undefined" && module.exports) module.exports = core;
  root.StudioCore = core;
})(typeof window !== "undefined" ? window : globalThis);
