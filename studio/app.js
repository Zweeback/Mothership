(function () {
  "use strict";
  var C = window.StudioCore;
  var KEY = "mothership-studio-v1";
  var state;
  var navTitles = {
    home: ["Studio / Überblick", "Die Studiozentrale.", "Ein Ideenlabor. Viele Produktionen. Gemeinsame Ressourcen."],
    ideas: ["Creative Development", "Das Ideenlabor.", "Aus Gedanken werden definierte Produktionen."],
    projects: ["Production Management", "Das Portfolio.", "Ein Projekt hat eine Quelle und einen transparenten Zustand."],
    tasks: ["Production Pipeline", "Die Übergaben.", "Kein Auftrag ohne Liefergegenstand und Nachweis."],
    assets: ["Asset Factory", "Die Asset-Bibliothek.", "Jede Datei mit Herkunft, Verweis und Prüfung."],
    data: ["Studio Infrastructure", "Die Datenzentrale.", "Exportierbare Informationen statt Chat-Silos."]
  };
  function el(id) { return document.getElementById(id); }
  function esc(value) {
    return String(value == null ? "" : value).replace(/[&<>"']/g, function (char) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[char];
    });
  }
  function allowedURL(value) {
    try {
      var u = new URL(value);
      return (u.protocol === "https:" || u.protocol === "http:") ? u.href : "";
    } catch (_) { return ""; }
  }
  function projectLabel(id) {
    var p = state.projects.find(function (item) { return item.id === id; });
    return p ? p.name : "Unbekanntes Projekt";
  }
  function notify(message, bad) {
    var bar = el("toast");
    bar.textContent = message;
    bar.classList.toggle("bad", !!bad);
    bar.hidden = false;
    clearTimeout(notify.timeout);
    notify.timeout = setTimeout(function () { bar.hidden = true; }, 4700);
  }
  function load() {
    try {
      var raw = localStorage.getItem(KEY);
      return raw ? C.validateImport(JSON.parse(raw)) : C.emptyState();
    } catch (error) {
      setTimeout(function () { notify("Lokale Daten unlesbar. Der ursprüngliche Speicher wird nicht überschrieben.", true); }, 200);
      return C.emptyState();
    }
  }
  function persist(next) {
    try {
      localStorage.setItem(KEY, JSON.stringify(next));
      state = next;
      render();
    } catch (error) {
      notify("Speichern fehlgeschlagen: Browserspeicher prüfen oder JSON exportieren.", true);
    }
  }
  function mutate(fn) {
    try { persist(fn(state)); notify("Gespeichert."); }
    catch (error) { notify(error.message || "Vorgang fehlgeschlagen.", true); }
  }
  function view(id) {
    if (!navTitles[id]) return;
    Array.from(document.querySelectorAll(".view")).forEach(function (node) {
      node.hidden = node.id !== "view-" + id;
    });
    Array.from(document.querySelectorAll("[data-nav]")).forEach(function (node) {
      var selected = node.dataset.nav === id;
      node.classList.toggle("active", selected);
      node.setAttribute("aria-current", selected ? "page" : "false");
    });
    el("breadcrumb").textContent = navTitles[id][0];
    el("page-title").textContent = navTitles[id][1];
    el("page-subtitle").textContent = navTitles[id][2];
    window.scrollTo({ top: 0, behavior: "instant" });
  }
  function pill(label, accent) {
    return '<span class="tag ' + (accent || "") + '">' + esc(label) + "</span>";
  }
  function renderIdeas() {
    el("idea-list").innerHTML = state.ideas.length ? state.ideas.map(function (i) {
      return '<article class="item"><div class="item-top"><div><div class="meta">' + esc(i.id) + ' · ' + esc(i.medium.toUpperCase()) + '</div><h3>' + esc(i.title) + '</h3></div>' +
        pill(i.status === "draft" ? "ENTWURF" : "ÜBERNOMMEN", i.status === "draft" ? "gold" : "cyan") +
        '</div><p>' + esc(i.description) + '</p>' +
        (i.status === "draft" ? '<button class="btn small primary" data-promote="' + esc(i.id) + '">In Produktion übernehmen</button>' : '<span class="meta">Produktion wurde aus dieser Idee angelegt.</span>') +
        '</article>';
    }).join("") : '<div class="empty">Noch keine Ideen. Hier startet alles.</div>';
  }
  function projectCard(p, compact) {
    var url = allowedURL(p.repository);
    var tasks = state.tasks.filter(function (t) { return t.projectId === p.id; }).length;
    var assets = state.assets.filter(function (a) { return a.projectId === p.id; }).length;
    return '<article class="item"><div class="item-top"><div><div class="meta">' + esc(p.id) + ' · ' + esc(p.medium.toUpperCase()) + '</div><h3>' + esc(p.name) + '</h3></div>' +
      pill(p.stage === "linked" ? "REPO VERLINKT" : "KONZEPT", p.stage === "linked" ? "cyan" : "gold") +
      '</div><div class="meta">' + esc(p.origin || "") + (compact ? "" : ' · ' + tasks + ' Übergaben · ' + assets + ' Assets') + '</div>' +
      (url ? '<div style="margin-top:10px"><a href="' + esc(url) + '" target="_blank" rel="noopener noreferrer">Repository öffnen ↗</a></div>' : '') +
      (!compact ? '<div class="btn-row" style="margin-top:13px"><button class="btn small ghost" data-go="tasks">Übergabe erstellen</button><button class="btn small ghost" data-go="assets">Asset erfassen</button></div>' : '') +
      '</article>';
  }
  function renderProjects() {
    el("project-list").innerHTML = state.projects.map(function (p) { return '<div class="card" style="margin:0">' + projectCard(p, false) + '</div>'; }).join("");
    el("home-projects").innerHTML = state.projects.slice(0, 4).map(function (p) { return projectCard(p, true); }).join("");
    [el("task-project"), el("asset-project")].forEach(function (select) {
      var value = select.value;
      select.innerHTML = state.projects.map(function (p) {
        return '<option value="' + esc(p.id) + '">' + esc(p.name) + '</option>';
      }).join("");
      if (state.projects.some(function (p) { return p.id === value; })) select.value = value;
    });
  }
  function taskControls(t) {
    var actions = {
      open: '<button class="btn small primary" data-task="' + esc(t.id) + '" data-action="start">Starten</button>',
      in_progress: '<button class="btn small primary" data-task="' + esc(t.id) + '" data-action="submit">Nachweis einreichen</button>',
      submitted: '<button class="btn small primary" data-task="' + esc(t.id) + '" data-action="approve">Manuell freigeben</button><button class="btn small ghost" data-task="' + esc(t.id) + '" data-action="reopen">Zurückweisen</button>',
      accepted: ''
    };
    return actions[t.status] || "";
  }
  function renderTasks() {
    el("task-list").innerHTML = state.tasks.length ? state.tasks.map(function (t) {
      return '<article class="item"><div class="item-top"><div><div class="meta">' + esc(t.id) + ' · ' + esc(projectLabel(t.projectId)) + '</div><h3>' + esc(t.title) + '</h3></div>' +
        pill(t.status.toUpperCase(), t.status === "accepted" ? "cyan" : "gold") +
        '</div><div class="meta">' + esc(t.from) + ' → ' + esc(t.to) + '</div><p><strong>Liefergegenstand:</strong> ' + esc(t.deliverable) + '</p>' +
        (t.evidence ? '<p><strong>Nachweis (Angabe):</strong> ' + esc(t.evidence) + '</p>' : '') +
        (t.approvedBy ? '<div class="meta">Manuell bestätigt von: ' + esc(t.approvedBy) + '</div>' : '') +
        '<div class="btn-row">' + taskControls(t) + '<button class="btn small ghost" data-copy="' + esc(t.id) + '">Übergabepaket kopieren</button></div></article>';
    }).join("") : '<div class="empty">Noch keine Übergaben. Eine Idee kann eine erste technische Prüfung erzeugen.</div>';
  }
  function renderAssets() {
    el("asset-list").innerHTML = state.assets.length ? state.assets.map(function (a) {
      var url = allowedURL(a.location);
      return '<article class="item"><div class="item-top"><div><div class="meta">' + esc(a.id) + ' · ' + esc(projectLabel(a.projectId)) + '</div><h3>' + esc(a.name) + '</h3></div>' +
        pill(a.status === "reviewed" ? "MANUELL GEPRÜFT" : "REGISTRIERT", a.status === "reviewed" ? "cyan" : "gold") +
        '</div><div class="meta">' + esc(a.format) + ' · Herkunft: ' + esc(a.license) + '</div>' +
        '<p>' + (url ? '<a href="' + esc(url) + '" target="_blank" rel="noopener noreferrer">' + esc(a.location) + '</a>' : esc(a.location)) + '</p>' +
        (a.reviewEvidence ? '<div class="meta">Prüfvermerk: ' + esc(a.reviewEvidence) + ' · ' + esc(a.reviewer) + '</div>' : '') +
        (a.status !== "reviewed" ? '<button class="btn small ghost" data-asset-review="' + esc(a.id) + '">Manuelle Prüfung dokumentieren</button>' : '') +
        '</article>';
    }).join("") : '<div class="empty">Noch keine Assets registriert. Hier landen später die Ergebnisse der Asset Factory.</div>';
  }
  function renderEvents() {
    el("home-events").innerHTML = state.events.length ? state.events.slice(0, 10).map(function (e) {
      var time = new Date(e.at);
      return '<div class="event"><div><strong>' + esc(e.type) + '</strong><br>' + esc(e.ref) + ' · ' + esc(e.detail) + '</div><span class="event-time">' + (isNaN(time) ? "–" : esc(time.toLocaleDateString("de-DE"))) + '</span></div>';
    }).join("") : '<div class="empty">Noch keine Aktionen protokolliert.</div>';
  }
  function render() {
    var s = C.stats(state);
    el("stat-ideas").textContent = s.ideas;
    el("stat-projects").textContent = s.productions;
    el("stat-tasks").textContent = s.tasks;
    el("stat-assets").textContent = s.assets;
    renderIdeas();
    renderProjects();
    renderTasks();
    renderAssets();
    renderEvents();
  }
  function values(form) {
    return Object.fromEntries(new FormData(form).entries());
  }
  function exportState() {
    var date = new Date().toISOString().slice(0, 10);
    var blob = new Blob([JSON.stringify(state, null, 2) + "\n"], { type: "application/json" });
    var url = URL.createObjectURL(blob);
    var link = document.createElement("a");
    link.href = url;
    link.download = "mothership-studio-" + date + ".json";
    document.body.appendChild(link);
    link.click();
    link.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 2000);
    notify("JSON exportiert. Datei bitte sicher aufbewahren.");
  }
  function copyTask(id) {
    var task = state.tasks.find(function (t) { return t.id === id; });
    if (!task) return;
    var payload = JSON.stringify({
      schema: "mothership/handoff/v1", project: projectLabel(task.projectId),
      task: task, note: "Die Freigabe ist manuell. Kein Build- oder Dateinachweis wurde automatisch verifiziert."
    }, null, 2);
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(payload).then(function () { notify("Übergabepaket kopiert."); }, function () {
        window.prompt("JSON zum Kopieren:", payload);
      });
    } else window.prompt("JSON zum Kopieren:", payload);
  }
  document.addEventListener("click", function (event) {
    var go = event.target.closest("[data-go], [data-nav]");
    if (go) { view(go.dataset.go || go.dataset.nav); return; }
    var promote = event.target.closest("[data-promote]");
    if (promote) {
      mutate(function (s) { return C.promote(s, promote.dataset.promote); });
      return;
    }
    var copy = event.target.closest("[data-copy]");
    if (copy) { copyTask(copy.dataset.copy); return; }
    var action = event.target.closest("[data-task]");
    if (action) {
      var id = action.dataset.task;
      var type = action.dataset.action;
      if (type === "start" || type === "reopen") mutate(function (s) { return C.taskUpdate(s, id, type); });
      else if (type === "submit") {
        var evidence = window.prompt("Nachweis: Commit-Link, Dateiverweis oder Prüfprotokoll. Keine automatische Verifikation:");
        if (evidence !== null) mutate(function (s) { return C.taskUpdate(s, id, "submit", { evidence: evidence }); });
      } else if (type === "approve") {
        var reviewer = window.prompt("Manuelle Freigabe: Name der prüfenden Person:");
        if (reviewer !== null) mutate(function (s) { return C.taskUpdate(s, id, "approve", { approvedBy: reviewer }); });
      }
      return;
    }
    var asset = event.target.closest("[data-asset-review]");
    if (asset) {
      var evidence = window.prompt("Was wurde tatsächlich geprüft? (Manueller Prüfvermerk)");
      if (evidence === null) return;
      var reviewer = window.prompt("Prüfende Person:");
      if (reviewer !== null) mutate(function (s) { return C.assetReview(s, asset.dataset.assetReview, evidence, reviewer); });
    }
  });
  el("idea-form").addEventListener("submit", function (event) {
    event.preventDefault();
    var form = event.currentTarget;
    mutate(function (s) { return C.idea(s, values(form)); });
    if (state.ideas.length && state.ideas[0].title === form.elements.title.value.trim()) form.reset();
  });
  el("task-form").addEventListener("submit", function (event) {
    event.preventDefault();
    var form = event.currentTarget;
    var old = state.tasks.length;
    mutate(function (s) { return C.handoff(s, values(form)); });
    if (state.tasks.length > old) form.reset();
  });
  el("asset-form").addEventListener("submit", function (event) {
    event.preventDefault();
    var form = event.currentTarget;
    var old = state.assets.length;
    mutate(function (s) { return C.asset(s, values(form)); });
    if (state.assets.length > old) form.reset();
  });
  el("export-btn").addEventListener("click", exportState);
  el("import-file").addEventListener("change", function (event) {
    var file = event.target.files[0];
    if (!file) return;
    if (file.size > 2000000) { notify("JSON-Datei ist zu groß (max. 2 MB).", true); return; }
    file.text().then(function (text) {
      var data = C.validateImport(JSON.parse(text));
      if (!window.confirm("Lokalen Datenstand durch importierte Datei ersetzen?")) return;
      persist(data);
      notify("Studio-Daten importiert.");
    }).catch(function (error) { notify("Import abgebrochen: " + error.message, true); });
    event.target.value = "";
  });
  [el("task-from"), el("task-to")].forEach(function (select, index) {
    select.innerHTML = C.DEPARTMENTS.map(function (name) {
      return '<option value="' + esc(name) + '">' + esc(name) + '</option>';
    }).join("");
    select.value = index ? "3D Asset Factory" : "Ideenlabor";
  });
  state = load();
  render();
})();
