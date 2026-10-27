// China Compass: a small hash-routed app. All guide content lives in content.<lang>.json
// so the same data can later be bundled into a native iOS app.
// Both language files must keep the same guide/block/item order, because checklist
// progress is stored by position and shared across languages.

const view = document.getElementById("view");
const titleEl = document.getElementById("title");
const backBtn = document.getElementById("back");
const langBtn = document.getElementById("lang-btn");

const LANGS = { en: "English", de: "Deutsch" };

const UI = {
  en: {
    heroTitle: "Understand China, ",
    heroText: "Practical guides for traveling, studying and living in China, written by a student who lives here.",
    whoAreYou: "Who are you?",
    startHere: "Start here",
    language: "Language",
    disclaimer: "Last checked {date}. Rules in China change often. Always confirm visa and permit details with official sources.",
    stepsDone: "{done} of {total} steps done",
    done: "✓ Done",
    min: "{n} min",
    readMeta: "{n} min read · checked {date}",
    nextGuide: "Next guide",
    tip: "💡 Tip",
    warning: "⚠️ Heads up",
    officialLinks: "Official links",
    search: "Search",
    searchPlaceholder: "Try “Alipay”, “X1 visa”, “hot pot”…",
    noResults: "Nothing found for “{q}”.",
    notFound: "Not found",
    notFoundText: "That page doesn't exist.",
    goHome: "Go home",
    loadError: "Couldn't load the guides. Check your connection and reload.",
    back: "Back",
    switchLang: "Switch language",
    tabHome: "Home",
    tabTravel: "Travel",
    tabStudy: "Study",
    tabLife: "Life"
  },
  de: {
    heroTitle: "China verstehen, ",
    heroText: "Praktische Guides zum Reisen, Studieren und Leben in China, geschrieben von einer Person, die hier studiert.",
    whoAreYou: "Was hast du vor?",
    startHere: "Hier starten",
    language: "Sprache",
    disclaimer: "Zuletzt geprüft: {date}. Regeln in China ändern sich oft. Prüfe Visa- und Aufenthaltsfragen immer bei offiziellen Stellen.",
    stepsDone: "{done} von {total} Schritten erledigt",
    done: "✓ Erledigt",
    min: "{n} Min.",
    readMeta: "{n} Min. Lesezeit · geprüft {date}",
    nextGuide: "Nächster Guide",
    tip: "💡 Tipp",
    warning: "⚠️ Achtung",
    officialLinks: "Offizielle Links",
    search: "Suche",
    searchPlaceholder: "Z. B. „Alipay“, „X1-Visum“, „Hotpot“…",
    noResults: "Nichts gefunden für „{q}“.",
    notFound: "Nicht gefunden",
    notFoundText: "Diese Seite gibt es nicht.",
    goHome: "Zur Startseite",
    loadError: "Die Guides konnten nicht geladen werden. Prüfe deine Verbindung und lade neu.",
    back: "Zurück",
    switchLang: "Sprache wechseln",
    tabHome: "Start",
    tabTravel: "Reisen",
    tabStudy: "Studium",
    tabLife: "Leben"
  }
};

const LANG_KEY = "cc-lang";
let lang = loadLang();
let content = null;
const contentCache = {};

function loadLang() {
  try {
    const saved = localStorage.getItem(LANG_KEY);
    if (saved && LANGS[saved]) return saved;
  } catch { /* private mode */ }
  return (navigator.language || "").toLowerCase().startsWith("de") ? "de" : "en";
}

function t(key, vars = {}) {
  const s = UI[lang][key] ?? UI.en[key] ?? key;
  return s.replace(/\{(\w+)\}/g, (_, k) => vars[k] ?? "");
}

async function loadContent(code) {
  if (!contentCache[code]) {
    const res = await fetch(`content.${code}.json`);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    contentCache[code] = await res.json();
  }
  return contentCache[code];
}

async function setLang(code) {
  lang = code;
  try { localStorage.setItem(LANG_KEY, code); } catch { /* private mode */ }
  document.documentElement.lang = code;
  document.querySelectorAll("[data-i18n]").forEach(el => (el.textContent = t(el.dataset.i18n)));
  backBtn.setAttribute("aria-label", t("back"));
  langBtn.textContent = code.toUpperCase();
  langBtn.setAttribute("aria-label", `${t("switchLang")} (${LANGS[code]})`);
  try {
    content = await loadContent(code);
  } catch {
    view.innerHTML = `<p class="empty">${esc(t("loadError"))}</p>`;
    return;
  }
  route();
}

// ---------- Checklist progress (per device) ----------

const STORE_KEY = "cc-checked-v1";

function loadChecked() {
  try { return new Set(JSON.parse(localStorage.getItem(STORE_KEY) || "[]")); }
  catch { return new Set(); }
}

function saveChecked(set) {
  try { localStorage.setItem(STORE_KEY, JSON.stringify([...set])); } catch { /* private mode */ }
}

const checked = loadChecked();

function checklistIds(guide) {
  const ids = [];
  guide.blocks.forEach((b, bi) => {
    if (b.type === "checklist") b.items.forEach((_, ii) => ids.push(`${guide.id}:${bi}:${ii}`));
  });
  return ids;
}

function progress(guides) {
  const ids = guides.flatMap(checklistIds);
  const done = ids.filter(id => checked.has(id)).length;
  return { done, total: ids.length, pct: ids.length ? Math.round((done / ids.length) * 100) : 0 };
}

// ---------- Helpers ----------

function esc(s) {
  return String(s).replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}

// Tiny inline formatting: **bold** and [label](https://url)
function fmt(s) {
  return esc(s)
    .replace(/\*\*(.+?)\*\*/g, "<strong>$1</strong>")
    .replace(/\[(.+?)\]\((https?:\/\/[^)\s]+)\)/g, '<a href="$2" target="_blank" rel="noopener">$1</a>');
}

function bar(p) {
  if (!p.total) return "";
  return `<div class="bar"><i style="width:${p.pct}%"></i></div>
    <div class="bar-label">${esc(t("stepsDone", p))}</div>`;
}

function findGuide(id) {
  for (const persona of content.personas) {
    const guide = persona.guides.find(g => g.id === id);
    if (guide) return { persona, guide };
  }
  return null;
}

function setChrome({ title, tab, back }) {
  titleEl.textContent = title;
  document.title = title === "China Compass" ? title : `${title} · China Compass`;
  backBtn.hidden = !back;
  backBtn.onclick = () => (history.length > 1 ? history.back() : (location.hash = back));
  document.querySelectorAll(".tabbar a").forEach(a => a.classList.toggle("active", a.dataset.tab === tab));
}

// ---------- Views ----------

function renderHome() {
  setChrome({ title: "China Compass", tab: "home" });
  view.innerHTML = `
    <section class="hero">
      <h2>${esc(t("heroTitle"))}<span class="zh" lang="zh-CN">一步一步</span></h2>
      <p>${esc(t("heroText"))}</p>
    </section>
    <div class="section-label">${esc(t("whoAreYou"))}</div>
    ${content.personas.map(p => `
      <a class="persona" href="#/p/${p.id}">
        <div class="emoji">${p.emoji}</div>
        <div style="flex:1;min-width:0">
          <h3>${esc(p.title)}</h3>
          <p>${esc(p.tagline)}</p>
          ${bar(progress(p.guides))}
        </div>
      </a>`).join("")}
    <div class="section-label">${esc(t("startHere"))}</div>
    <div class="guide-list">
      ${content.featured.map(id => guideCard(findGuide(id).guide)).join("")}
    </div>
    <div class="section-label">${esc(t("language"))}</div>
    <div class="lang-switch" role="group" aria-label="${esc(t("language"))}">
      ${Object.entries(LANGS).map(([code, name]) =>
        `<button type="button" data-lang="${code}" aria-pressed="${code === lang}">${name}</button>`).join("")}
    </div>
    <p class="disclaimer">${esc(t("disclaimer", { date: content.updated }))}</p>`;

  view.querySelectorAll(".lang-switch button").forEach(btn => {
    btn.addEventListener("click", () => { if (btn.dataset.lang !== lang) setLang(btn.dataset.lang); });
  });
}

function guideCard(g) {
  const p = progress([g]);
  const meta = p.total && p.done === p.total
    ? `<span class="meta done">${esc(t("done"))}</span>`
    : `<span class="meta">${p.total ? `${p.done}/${p.total}` : esc(t("min", { n: g.minutes }))}</span>`;
  return `<a class="guide-card" href="#/g/${g.id}">
    <span class="emoji">${g.emoji}</span>
    <div class="body"><h4>${esc(g.title)}</h4><p>${esc(g.summary)}</p></div>
    ${meta}
  </a>`;
}

function renderPersona(id) {
  const p = content.personas.find(x => x.id === id);
  if (!p) return renderNotFound();
  setChrome({ title: p.title, tab: p.id });
  view.innerHTML = `
    <section class="persona-head">
      <p>${esc(p.intro)}</p>
      ${bar(progress(p.guides))}
    </section>
    <div class="guide-list">${p.guides.map(guideCard).join("")}</div>`;
}

function renderBlock(b, bi, guide) {
  switch (b.type) {
    case "text":
      return `<section class="block">
        ${b.heading ? `<h3>${esc(b.heading)}</h3>` : ""}
        ${(b.paragraphs || []).map(s => `<p>${fmt(s)}</p>`).join("")}
        ${b.bullets ? `<ul>${b.bullets.map(s => `<li>${fmt(s)}</li>`).join("")}</ul>` : ""}
      </section>`;
    case "tip":
    case "warning":
      return `<div class="callout ${b.type}"><strong>${esc(t(b.type))}</strong>${fmt(b.text)}</div>`;
    case "checklist":
      return `<section class="block">
        ${b.heading ? `<h3>${esc(b.heading)}</h3>` : ""}
        <ul class="checklist">${b.items.map((item, ii) => {
          const cid = `${guide.id}:${bi}:${ii}`;
          const on = checked.has(cid);
          return `<li class="${on ? "checked" : ""}"><label>
            <input type="checkbox" data-id="${cid}" ${on ? "checked" : ""}>
            <span><span class="text">${fmt(item.text)}</span>${item.note ? `<span class="note">${fmt(item.note)}</span>` : ""}</span>
          </label></li>`;
        }).join("")}</ul>
      </section>`;
    case "phrases":
      return `<section class="block">
        ${b.heading ? `<h3>${esc(b.heading)}</h3>` : ""}
        <div class="phrases">${b.items.map(ph => `
          <div class="phrase"><div class="meaning">${esc(ph.meaning)}</div><div class="zh" lang="zh-CN">${esc(ph.zh)}</div><div class="py">${esc(ph.pinyin)}</div></div>`).join("")}
        </div>
      </section>`;
    case "links":
      return `<section class="block links">
        <h3>${esc(b.heading || t("officialLinks"))}</h3>
        ${b.items.map(l => `<a href="${esc(l.url)}" target="_blank" rel="noopener">${esc(l.label)} ↗</a>`).join("")}
      </section>`;
    default:
      return "";
  }
}

function renderGuide(id) {
  const found = findGuide(id);
  if (!found) return renderNotFound();
  const { persona, guide } = found;
  setChrome({ title: guide.title, tab: persona.id, back: `#/p/${persona.id}` });

  const idx = persona.guides.indexOf(guide);
  const next = persona.guides[idx + 1];

  view.innerHTML = `
    <section class="guide-head">
      <div class="emoji">${guide.emoji}</div>
      <h2>${esc(guide.title)}</h2>
      <p>${esc(guide.summary)}</p>
      <div class="updated">${esc(t("readMeta", { n: guide.minutes, date: content.updated }))}</div>
    </section>
    ${guide.blocks.map((b, bi) => renderBlock(b, bi, guide)).join("")}
    ${next ? `<a class="next-guide" href="#/g/${next.id}"><small>${esc(t("nextGuide"))}</small>${next.emoji} ${esc(next.title)} →</a>` : ""}`;

  view.querySelectorAll(".checklist input").forEach(input => {
    input.addEventListener("change", () => {
      if (input.checked) checked.add(input.dataset.id); else checked.delete(input.dataset.id);
      input.closest("li").classList.toggle("checked", input.checked);
      saveChecked(checked);
    });
  });
}

function guideText(g) {
  return [g.title, g.summary, ...g.blocks.flatMap(b => [
    b.heading, b.text, ...(b.paragraphs || []), ...(b.bullets || []),
    ...(b.items || []).map(i => [i.text, i.note, i.meaning, i.zh, i.pinyin, i.label].join(" ")),
  ])].join(" ").toLowerCase();
}

function renderSearch() {
  setChrome({ title: t("search"), tab: "", back: "#/" });
  view.innerHTML = `
    <input class="search-input" type="search" placeholder="${esc(t("searchPlaceholder"))}" autofocus>
    <div class="guide-list" id="results" style="margin-top:12px"></div>`;
  const input = view.querySelector("input");
  const results = view.querySelector("#results");
  const all = content.personas.flatMap(p => p.guides);
  const run = () => {
    const q = input.value.trim().toLowerCase();
    if (!q) { results.innerHTML = ""; return; }
    const terms = q.split(/\s+/);
    const hits = all.filter(g => { const text = guideText(g); return terms.every(term => text.includes(term)); });
    results.innerHTML = hits.length ? hits.map(guideCard).join("") : `<p class="empty">${esc(t("noResults", { q }))}</p>`;
  };
  input.addEventListener("input", run);
  input.focus();
}

function renderNotFound() {
  setChrome({ title: t("notFound"), tab: "", back: "#/" });
  view.innerHTML = `<p class="empty">${esc(t("notFoundText"))} <a href="#/">${esc(t("goHome"))}</a></p>`;
}

// ---------- Router ----------

function route() {
  if (!content) return;
  const [, kind, id] = (location.hash.slice(1) || "/").split("/");
  if (!kind) renderHome();
  else if (kind === "p") renderPersona(id);
  else if (kind === "g") renderGuide(id);
  else if (kind === "search") renderSearch();
  else renderNotFound();
  window.scrollTo(0, 0);
}

langBtn.addEventListener("click", () => {
  const codes = Object.keys(LANGS);
  setLang(codes[(codes.indexOf(lang) + 1) % codes.length]);
});

window.addEventListener("hashchange", route);

if ("serviceWorker" in navigator && location.protocol !== "file:") {
  navigator.serviceWorker.register("sw.js").catch(() => {});
}

setLang(lang);
