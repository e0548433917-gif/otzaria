/* כיוון תפילה 1.3 — תוספות: בתי כנסת בלחיצה, מצב תפילה, הדפסה, זכירת התצוגה, מיקוד. */

/* ---- שדות המיקום הידני מתעדכנים לפי המיקום הנוכחי ---- */
(function () {
  const sp = setPos;
  setPos = function (p) { sp.apply(this, arguments); if (p) { $("lat").value = (+p[0]).toFixed(5); $("lon").value = (+p[1]).toFixed(5) } };
})();

/* ---- בתי כנסת: לחיצה על ✡, ובית הכנסת הקרוב ---- */
function synText(s) {
  const d = Math.round(dist(pos, [s[1], s[2]]) * 1000), b = bearing(pos, [s[1], s[2]]);
  return `✡ ${stNm(s[0]) || "בית כנסת"}: ${d >= 1000 ? (d / 1000).toFixed(1) + ' ק"מ' : d + " מ'"} ממך, לכיוון ${nm(b)}.`;
}
function synHit(ev) {
  if (!ST.area || !ST.showSyn || !(ST.area.s || []).length) return null;
  const svg = $("map"), pt = svg.createSVGPoint(); pt.x = ev.clientX; pt.y = ev.clientY;
  const c = pt.matrixTransform(svg.getScreenCTM().inverse()), v = stView();
  let best = null;
  for (const s of ST.area.s) { const p = stXY(v, s[1], s[2]), d = Math.hypot(p[0] - c.x, p[1] - c.y + 1); if (d < 11 && (!best || d < best[0])) best = [d, s] }
  return best && best[1];
}
(function () {
  const sc = stClick;
  stClick = function (ev) { if (!ST.setHere) { const s = synHit(ev); if (s) { ST.synSel = s; ST.sel = null; streetMap(); return } } ST.synSel = null; sc(ev) };
  const sm = streetMap;
  streetMap = async function () {
    await sm();
    if (!ST.area || !ST.synSel || !pos) return;
    const p = stXY(stView(), ST.synSel[1], ST.synSel[2]);
    $("map").insertAdjacentHTML("beforeend", `<circle cx="${p[0].toFixed(1)}" cy="${(p[1] - 1).toFixed(1)}" r="11" fill="none" stroke="var(--color-primary)" stroke-width="2.5"/>`);
    $("stTxt").textContent = synText(ST.synSel);
  };
})();
function synNearest() {
  const t = $("stTxt");
  if (!ST.area || !(ST.area.s || []).length) { t.textContent = "אין נתוני בתי כנסת לאזור הזה."; return }
  let best = null; for (const s of ST.area.s) { const d = dist(pos, [s[1], s[2]]); if (!best || d < best[0]) best = [d, s] }
  const s = best[1], [kx, ky] = stM();
  ST.showSyn = true; $("stSyn").checked = true; ST.sel = null; ST.synSel = s;
  ST.pan = [(s[2] - pos[1]) * kx / 2, (s[1] - pos[0]) * ky / 2];
  const far = best[0] * 1000; if (far > 280 / zoom) zoom = Math.max(.25, 280 / (far * 1.1));
  streetMap();
}

/* ---- מצב תפילה: חץ גדול בלבד, מסתובב לפי המצפן אם יש ---- */
let prayT = null;
function prayDraw() {
  if (!pos) { $("prayTxt").textContent = "בחר קודם מיקום."; return }
  const b = bear(), hd = heading != null ? heading + decl() : null, a = hd != null ? b - hd : b;
  $("prayArrow").setAttribute("transform", `rotate(${a.toFixed(1)})`);
  $("prayDeg").textContent = Math.round(b) + "° · " + nm(b);
  $("prayTxt").textContent = hd != null ? "החץ מצביע לירושלים. הפנה את פניך לכיוונו." : "בלי מצפן: למעלה = צפון. סובב את עצמך כך שהחץ יהיה לפניך, לפי החוגה או המפה.";
}
function prayOpen(o) {
  $("pray").hidden = !o; clearInterval(prayT); prayT = null;
  if (o) { if (typeof startCompass === "function") startCompass(); prayDraw(); prayT = setInterval(prayDraw, 150); $("prayX").focus() }
}

/* ---- הדפסת דף כיוון ---- */
function printSheet() {
  if (!pos) return;
  const b = bear(), when = new Date().toLocaleDateString("he-IL");
  $("printHead").innerHTML = `<h1>כיוון התפילה לירושלים</h1><p><b>${esc(src || "המיקום")}</b> (${pos[0].toFixed(5)}, ${pos[1].toFixed(5)})</p>`
    + `<p class="pbig">${Math.round(b)}° מהצפון · ${esc(nm(b))}</p><p>${esc($("stTxt").textContent || "")}</p><p><small>הודפס ב-${when} מתוך התוסף "כיוון תפילה" לאוצריא. החישוב אל הר הבית; בשאלה מעשית יש להתייעץ עם רב.</small></p>`;
  try { window.print() } catch (e) { $("stMsg").textContent = "ההדפסה אינה זמינה כאן." }
}

/* ---- זכירת התצוגה: סוג המפה, סיבוב וזום ---- */
let viewLast = "";
function viewSave() {
  const v = JSON.stringify({ m: $("mapMode").value, r: Math.round(ST.rot), z: +zoom.toFixed(3) });
  if (v === viewLast) return; viewLast = v;
  try { O ? O.call("storage.set", { key: "kivun-view", value: v }).catch(() => {}) : localStorage.setItem("kivun-view", v) } catch (e) {}
}
async function viewRestore() {
  let v = null;
  try { v = O ? dat(await O.call("storage.get", { key: "kivun-view" })) : localStorage.getItem("kivun-view") } catch (e) {}
  try { v = typeof v === "string" ? JSON.parse(v) : v } catch (e) { v = null }
  if (v && typeof v === "object") {
    if (["street", "near", "far"].includes(v.m)) $("mapMode").value = v.m;
    if (isFinite(v.r)) ST.rot = v.r;
    if (isFinite(v.z) && v.z > 0) zoom = v.z;
    viewLast = JSON.stringify(v);
    if (pos) map();
  }
  setInterval(viewSave, 1500);
}

/* ---- מיקוד (ישראל וריכוזי הקהילה בחו״ל): טבלה מובנית מכתובות OpenStreetMap ---- */
let PC = null; function PC_PUT(d) { PC = d }
function pcLoad() {
  return new Promise(res => {
    if (PC) return res(PC);
    const s = document.createElement("script"); s.src = "postcodes.js";
    s.onload = () => res(PC); s.onerror = () => res(null); document.head.append(s);
  });
}
function pcGoTo(raw, e) {
  const st = (e[3] || []).length ? " (" + e[3].slice(0, 2).join(", ") + ")" : "";
  $("city").value = ""; setPos([e[0], e[1]], "מיקוד " + raw + ", " + e[2] + st, null, false);
  mode = "m:" + e[0] + "," + e[1]; save(mode); $("pcPick").replaceChildren();
}
function pcChoose(raw, L) {
  const box = $("pcPick"); box.replaceChildren();
  if (L.length === 1) { pcGoTo(raw, L[0]); return }
  const t = document.createElement("small"); t.textContent = "המיקוד נמצא בכמה מקומות, בחר: "; box.append(t);
  for (const e of L) { const b = document.createElement("button"); b.textContent = e[2] + ((e[3] || []).length ? " — " + e[3].slice(0, 3).join(", ") : ""); b.onclick = () => pcGoTo(raw, e); box.append(b) }
}
async function pcFind() {
  const raw = ($("pc").value || "").trim().toUpperCase(), z = raw.replace(/[^0-9A-Z]/g, ""), t = $("txt");
  if (z.length < 3) { t.textContent = "יש להזין מיקוד (בארץ 7 ספרות; בחו\u05f4ל כפי שהוא, למשל 11219 או N16 6XS)."; return }
  const d = await pcLoad();
  if (!d) { t.textContent = "טבלת המיקודים אינה זמינה בגרסה זו."; return }
  let p = null, lbl = "מיקוד " + raw;
  if (/^\d{7}$/.test(z)) { p = d.f[z]; if (!p && d.p[z.slice(0, 5)]) { p = d.p[z.slice(0, 5)]; lbl += " (משוער לפי האזור)" } }
  /* חו"ל לפי אזור (y): אותו מיקוד יכול להופיע בכמה מקומות — מציגים בחירה, עם שמות הרחובות */
  if (!p && d.y) {
    let L = d.y[z]; if (!L && raw.includes(" ")) L = d.y[raw.split(/\s+/)[0]];
    if (L && L.length) { pcChoose(raw, L); return }
  }
  if (!p && d.x) { p = d.x[z]; if (!p && raw.includes(" ")) { p = d.x[raw.split(/\s+/)[0]]; if (p) lbl += " (משוער לפי האזור)" } }
  if (!p) { t.textContent = `המיקוד ${raw} לא נמצא בטבלה. נסה קואורדינטות או בחירת עיר.`; return }
  $("city").value = ""; setPos([p[0], p[1]], lbl, null, false);
  mode = "m:" + p[0] + "," + p[1]; save(mode);
}

/* ---- מראי מקומות: פתיחה בספריית אוצריא ---- */
/* בוחרים את הספר עצמו ולא פירוש עליו (למשל חק יעקב "על שולחן ערוך אורח חיים"): כל מילות השאילתה בכותרת, והכותרת הקצרה ביותר */
const srcNorm = t => (t || "").replace(/[^\u05d0-\u05eaA-Za-z0-9 ]/g, " ").replace(/\s+/g, " ").trim();
async function openSrc(q, r) {
  if (!O) return;
  for (const qq of q.split("|")) {
    try {
      const l = dat(await O.call("library.findBooks", { query: qq, limit: 30 })) || [], w = srcNorm(qq).split(" ");
      const m = l.filter(x => { const t = " " + srcNorm(x.title) + " "; return w.every(y => t.includes(" " + y + " ")) })
        .sort((a, b) => srcNorm(a.title).length - srcNorm(b.title).length);
      const b = m[0];
      if (b) { const ok = dat(await O.call("reader.openBookAtRef", { bookId: b.bookId, ref: r, highlight: true })); if (ok !== false) return }
    } catch (e) {}
  }
  try { await O.call("reader.openSearchTab", { query: q.split("|")[0] + " " + r }) } catch (e) {}
}
document.querySelectorAll("button.src").forEach(b => b.onclick = () => openSrc(b.dataset.q, b.dataset.r));
if (!O) document.querySelectorAll("button.src").forEach(b => b.disabled = true);

/* ---- מצפן זמין: מציגים את מצב התפילה גם במכשיר שאינו מגע ---- */
/* בלי מצפן (מחשב): הסבר שהחוגה אינה מצביעה בחדר, והפניה לשיטות שעובדות במחשב */
function compassNote() { if (heading != null) document.body.classList.add("hascompass"); $("noCompass").hidden = heading != null || manual != null || !pos }
setInterval(compassNote, 1000);

/* ---- הורדת האזור של המיקום הנוכחי מתוך ההגדרות ---- */
$("setDl").onclick = () => { if (!pos) return; pop("bSet", "set", false); $("mapMode").value = "street"; map(); setTimeout(() => stDownload(), 300) };

/* ---- דף ההורדה: פותח בדפדפן, ומעתיק את הכתובת ללוח ---- */
const DL_URL = "https://github.com/e0548433917-gif/otzaria/tree/%D7%9B%D7%99%D7%95%D7%95%D7%9F-%D7%AA%D7%A4%D7%99%D7%9C%D7%94";
$("dlLink").onclick = () => { copyText(DL_URL); let w = null; try { w = window.open(DL_URL, "_blank", "noopener") } catch (e) {} if (!w && O) O.call("app.openUrl", { url: DL_URL }).catch(() => {}); $("dlLink").textContent = "הכתובת הועתקה ללוח" };

/* ---- הסבר השימוש במפה מוצג בשורה התחתונה, רק בתצוגת הרחובות ---- */
(function () { const mp = map; map = function () { const r = mp.apply(this, arguments); $("stHint").hidden = $("stPanel").hidden; $("stRotRow").hidden = $("stPanel").hidden; return r } })();

/* ---- מפה במסך מלא ---- */
/* במסך מלא: מרחיבים את שטח הציור (viewBox) במקום למתוח אותו, כך שרואים יותר רחובות בגודל טקסט רגיל */
function mapVB() {
  const full = document.body.classList.contains("mapfull"), svg = $("map");
  if (!full) { ST.vb = { x0: 0, y0: 0, x1: 400, y1: 320 }; svg.setAttribute("viewBox", "0 0 400 320"); return }
  const r = svg.getBoundingClientRect(), k = 1.7, W = r.width / k, H = r.height / k;
  ST.vb = { x0: 200 - W / 2, y0: 160 - H / 2, x1: 200 + W / 2, y1: 160 + H / 2 };
  svg.setAttribute("viewBox", `${ST.vb.x0.toFixed(1)} ${ST.vb.y0.toFixed(1)} ${W.toFixed(1)} ${H.toFixed(1)}`);
}
function mapFull(o) {
  document.body.classList.toggle("mapfull", o); $("mapFullBar").hidden = !o;
  $("zFull").classList.toggle("on", o); mapVB(); if (pos) map(); $("fTxt").hidden = !o;
}
setInterval(() => { if (document.body.classList.contains("mapfull")) { const t = $("mapMode").value === "street" ? $("stTxt").textContent : $("txt").textContent; if ($("fTxt").textContent !== t) $("fTxt").textContent = t } }, 300);
addEventListener("resize", () => { if (document.body.classList.contains("mapfull")) { mapVB(); if (pos) map() } });
$("zFull").onclick = () => mapFull(!document.body.classList.contains("mapfull"));
$("fX").onclick = () => mapFull(false);
const fFind = () => { $("stQ").value = $("fQ").value; stFind() };
$("fGo").onclick = fFind; $("fQ").onkeydown = e => { if (e.key === "Enter") fFind() };
$("fIn").onclick = () => $("zIn").click(); $("fOut").onclick = () => $("zOut").click();
addEventListener("keydown", e => { if (e.key === "Escape" && document.body.classList.contains("mapfull")) mapFull(false) });

/* ---- מיקוד: השלמה תוך כדי הקלדה (קוד — קהילה — רחוב ראשי) ---- */
let pcKeys = null;
async function pcSuggest() {
  const v = ($("pc").value || "").trim().toUpperCase().replace(/[^0-9A-Z]/g, ""), dl = $("pcList");
  if (v.length < 3) { dl.replaceChildren(); return }
  const d = await pcLoad(); if (!d) return;
  if (!pcKeys) pcKeys = Object.keys(d.y || {}).concat(Object.keys(d.f || {}), Object.keys(d.x || {})).sort();
  const out = [];
  for (const k of pcKeys) {
    if (!k.startsWith(v)) continue;
    const ys = (d.y || {})[k];
    if (ys) for (const e of ys) out.push([k, e[2] + ((e[3] || [])[0] ? " — " + e[3][0] : "")]);
    else out.push([k, (d.f || {})[k] ? "ישראל" : ""]);
    if (out.length >= 40) break;
  }
  dl.replaceChildren(...out.map(([k, l]) => { const o = document.createElement("option"); o.value = k; o.label = l; o.textContent = l; return o }));
}
$("pc").addEventListener("input", () => { clearTimeout(pcSuggest.t); pcSuggest.t = setTimeout(pcSuggest, 200) });

/* ---- לחיצה על רחוב: מציגה גם את המיקוד הקרוב, כשהוא ידוע (חו"ל) ---- */
let pcNear = null;
async function pcNearIndex() {
  if (pcNear) return pcNear; const d = await pcLoad(); pcNear = [];
  if (d && d.y) for (const k in d.y) for (const e of d.y[k]) if (/^[0-9]+$/.test(k) || k.length > 4) pcNear.push([k, e[0], e[1], e[2]]);
  return pcNear;
}
(function () {
  const st = stText;
  stText = function () {
    st.apply(this, arguments);
    if (!ST.sel || !ST.area) return;
    const g = ST.area.w[ST.sel.i][2], k = ST.sel.k, la = (g[k] + g[k + 2]) / 2, lo = (g[k + 1] + g[k + 3]) / 2, t = $("stTxt"), base = t.textContent;
    pcNearIndex().then(L => {
      let b = null; for (const e of L) { const dd = dist([la, lo], [e[1], e[2]]); if (dd < .35 && (!b || dd < b[0])) b = [dd, e[0]] }
      if (b && t.textContent === base) t.textContent = base + ` (מיקוד באזור: ${b[1]})`;
    });
  };
})();

/* ---- חיבור ---- */
$("bPray").onclick = () => prayOpen(true);
$("prayX").onclick = () => prayOpen(false);
addEventListener("keydown", e => { if (e.key === "Escape" && !$("pray").hidden) prayOpen(false) });
$("stSynNear").onclick = synNearest;
$("bPrint").onclick = printSheet;
$("bHal").onclick = () => {
  if (pos) $("halHere").textContent = `במקום שלך: הקו הקצר ${Math.round(bearing(pos, J))}°, הכיוון הקבוע ${Math.round(rhumb(pos, J))}° (מהצפון, עם כיוון השעון).`;
  pop("bHal", "hal", $("hal").hidden) };
$("pcGo").onclick = pcFind;
$("pc").onkeydown = e => { if (e.key === "Enter") pcFind() };
$("mapMode").addEventListener("change", () => { ST.synSel = null });
/* הסבר קצר ליד שדה המיקוד, לפי מה שיש בחבילה */
function pcCheck() { pcLoad().then(d => { $("pcNote").textContent = d ? "בארץ: 7 ספרות. בחו\u05f4ל: כפי שהוא, בריכוזי הקהילה." : "טבלת המיקודים בבנייה ותצורף בגרסה 1.3.0." }) }
function extrasBoot() { viewRestore(); pcCheck() }
if (!O) extrasBoot();

/* ---- רשימות נפתחות בעכבר: ב-Windows הרשימה המקורית נסגרת ברגע שהעכבר נכנס אליה, ולכן מציגים רשימה משלנו. במגע — הרשימה המקורית ---- */
(function () {
  let dd = null, pt = "mouse";
  document.addEventListener("pointerdown", e => { pt = e.pointerType }, true);
  const close = () => { if (dd) { dd.remove(); dd = null } };
  document.addEventListener("mousedown", e => {
    const s = e.target.closest && e.target.closest("select");
    if (dd && !dd.contains(e.target)) { close(); if (s) { e.preventDefault(); return } }
    if (!s || s.disabled || s.multiple || e.button !== 0 || pt === "touch" || pt === "pen") return;
    e.preventDefault(); s.focus();
    const r = s.getBoundingClientRect(); dd = document.createElement("div"); dd.className = "dd"; dd.setAttribute("role", "listbox");
    [...s.options].forEach((o, i) => {
      if (o.hidden) return;
      const d = document.createElement("div"); d.textContent = o.text; d.setAttribute("role", "option");
      if (o.disabled) d.style.opacity = ".5"; if (i === s.selectedIndex) d.className = "sel on";
      d.onmousedown = ev => ev.preventDefault();
      d.onclick = () => { if (o.disabled) return; close(); if (s.selectedIndex !== i) { s.selectedIndex = i; s.dispatchEvent(new Event("input", { bubbles: true })); s.dispatchEvent(new Event("change", { bubbles: true })) } };
      dd.appendChild(d);
    });
    document.body.appendChild(dd);
    const below = innerHeight - r.bottom - 8, above = r.top - 8, up = below < 160 && above > below;
    dd.style.maxHeight = Math.max(120, up ? above : below) + "px"; dd.style.minWidth = r.width + "px";
    dd.style.left = Math.max(4, Math.min(r.left, innerWidth - dd.offsetWidth - 4)) + "px";
    dd.style.top = (up ? r.top - dd.offsetHeight : r.bottom) + "px";
    const on = dd.querySelector(".sel"); if (on) on.scrollIntoView({ block: "nearest" });
  }, true);
  addEventListener("keydown", e => { if (dd && e.key === "Escape") { e.stopPropagation(); close() } }, true);
  addEventListener("resize", close); addEventListener("blur", close);
  document.addEventListener("scroll", e => { if (dd && !dd.contains(e.target)) close() }, true);
})();
