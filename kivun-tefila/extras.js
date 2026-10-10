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
  let lab = src; try { lab = stLabel() || src } catch (e) {}
  $("prayHow").textContent = (lab ? "המקום: " + lab + ". " : "") + "השיטה: " + (meth() === "rh" ? "כיוון קבוע על המפה" : "הקו הקצר על הכדור") + " (משנים בשורה העליונה). "
    + (hd != null ? "המצפן כולל תיקון לסטייה המגנטית. החזק את המכשיר שטוח, הרחק ממתכת וממגנטים; אם החץ קופץ, הנע את המכשיר בצורת 8 לכיול." : "במכשיר אנדרואיד עם מצפן מובנה החץ מסתובב מעצמו לפי המצפן.")
    + (dist(pos, J) > 19000 ? " שים לב: המקום קרוב לצד השני של הכדור מול ירושלים; ראה בהלכות." : "");
}
function prayOpen(o) {
  $("pray").hidden = !o; clearInterval(prayT); prayT = null;
  if (o) { if (typeof startCompass === "function") startCompass(); prayDraw(); prayT = setInterval(prayDraw, 150); $("prayX").focus() }
}

/* ---- הדפסת דף כיוון ---- */
/* הדפסה: דף כיוון עם מפת האזור שנבחר (הרחובות סביבי, כשיש מפה) והקו המקווקו לירושלים */
function printSheet(again) {
  if (!pos) return;
  if (!again && $("mapMode").value !== "street" && typeof ST !== "undefined" && ST.area) { $("mapMode").value = "street"; map(); return setTimeout(() => printSheet(true), 500) }
  let lab = src; try { lab = stLabel() || src } catch (e) {}
  const b = bear(), when = new Date().toLocaleDateString("he-IL");
  $("printHead").innerHTML = `<h1>כיוון התפילה לירושלים</h1><p><b>${esc(lab || "המיקום")}</b> (${pos[0].toFixed(5)}, ${pos[1].toFixed(5)})</p>`
    + `<p class="pbig">${Math.round(b)}° מהצפון · ${esc(nm(b))}</p><p>${esc($("stTxt").textContent || "")}</p><p><small>במפה: הנקודה השחורה היא המקום, והקו המקווקו מוביל לכיוון ירושלים. הודפס ב-${when} מתוך התוסף "כיוון תפילה" לאוצריא. החישוב אל הר הבית; בשאלה מעשית יש להתייעץ עם רב.</small></p>`;
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
    if (["street", "near", "far", "globe"].includes(v.m)) $("mapMode").value = v.m;
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
/* בוחרים את הספר עצמו ולא פירוש עליו (למשל חק יעקב ״על שולחן ערוך אורח חיים״): כל מילות השאילתה בכותרת, והכותרת הקצרה ביותר */
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
  $("zFull").classList.toggle("on", o); mapVB(); if (pos) map(); $("fTxt").hidden = !o; $("fLoc").hidden = !o; $("fMode").value = $("mapMode").value;
}
/* במסך מלא: בועה צפה עם שם המקום (פינת הרחובות) והכיוון */
function fLocTxt() { if (!pos) return ""; let n = src; try { if (ST.area && !/^(במטוס|נחיתה)/.test(src)) n = stLabel() || src } catch (e) {} return `📍 ${n} · ${Math.round(bear())}°` }
$("fMode").onchange = () => { $("mapMode").value = $("fMode").value; $("mapMode").dispatchEvent(new Event("change", { bubbles: true })) };
setInterval(() => { if (document.body.classList.contains("mapfull")) { const l = fLocTxt(); if ($("fLoc").textContent !== l) $("fLoc").textContent = l; if ($("fMode").value !== $("mapMode").value) $("fMode").value = $("mapMode").value } }, 400);
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
$("bPrint").onclick = () => printSheet();
$("bHal").onclick = () => {
  if (pos) $("halHere").textContent = `במקום שלך: הקו הקצר ${Math.round(bearing(pos, J))}°, הכיוון הקבוע ${Math.round(rhumb(pos, J))}° (מהצפון, עם כיוון השעון).` + (dist(pos, J) > 19000 ? " המקום שלך קרוב לנקודה שמול ירושלים בצד השני של הכדור (ראה למטה)." : "");
  pop("bHal", "hal", $("hal").hidden) };
$("pcGo").onclick = pcFind;
$("pc").onkeydown = e => { if (e.key === "Enter") pcFind() };
$("mapMode").addEventListener("change", () => { ST.synSel = null });
/* הסבר קצר ליד שדה המיקוד, לפי מה שיש בחבילה */
function pcCheck() { pcLoad().then(d => { $("pcNote").textContent = d ? "בארץ: 7 ספרות. בחו\u05f4ל: כפי שהוא, בריכוזי הקהילה." : "טבלת המיקודים בבנייה ותצורף בגרסה 1.3.0." }) }
function extrasBoot() { viewRestore(); pcCheck(); prayLoad() }
/* כפתור מצב תפילה: מוסתר כברירת מחדל, מופיע מעצמו כשמתגלה מצפן מובנה; בהגדרות אפשר להפעיל או לכבות */
let prayPref = null;
function prayBtn() { const on = prayPref === "1" || (prayPref == null && heading != null); $("bPray").hidden = !on; $("prayShow").checked = on }
async function prayLoad() { try { prayPref = O ? dat(await O.call("storage.get", { key: "kivun-pray" })) : localStorage.getItem("kivun-pray") } catch (e) {} if (prayPref !== "1" && prayPref !== "0") prayPref = null; prayBtn() }
$("prayShow").onchange = () => { prayPref = $("prayShow").checked ? "1" : "0"; try { O ? O.call("storage.set", { key: "kivun-pray", value: prayPref }).catch(() => {}) : localStorage.setItem("kivun-pray", prayPref) } catch (e) {} prayBtn() };
if (!O) prayLoad();
const FORUM_URL = "https://tora-forum.co.il/threads/%D7%9C%D7%90%D7%99%D7%96%D7%94-%D7%A6%D7%93-%D7%9E%D7%AA%D7%A4%D7%9C%D7%9C%D7%99%D7%9D-%D7%91%D7%90%D7%99%D7%99-%D7%94%D7%95%D7%95%D7%90%D7%99.5898/";
document.querySelectorAll("button.fl").forEach(b => b.onclick = () => { copyText(b.dataset.u); let w = null; try { w = window.open(b.dataset.u, "_blank", "noopener") } catch (x) {} if (!w && O) O.call("app.openUrl", { url: b.dataset.u }).catch(() => {}); $("halForumMsg").textContent = "הכתובת הועתקה ללוח." });
$("halForum").onclick = () => { copyText(FORUM_URL).then(ok => $("halForumMsg").textContent = ok ? "הכתובת הועתקה ללוח." : FORUM_URL); let w = null; try { w = window.open(FORUM_URL, "_blank", "noopener") } catch (e) {} if (!w && O) O.call("app.openUrl", { url: FORUM_URL }).catch(() => {}) };
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

/* כשאזור הרחובות נטען: שורת המיקום מקבלת את שם פינת הרחובות */
(function () { const sm = streetMap; streetMap = async function () { const r = await sm.apply(this, arguments); try { if (pos) locText() } catch (e) {} return r } })();

/* ---- המקומות השמורים מסומנים על מפת הרחובות: לחיצה על הסיכה עוברת למקום ---- */
function plPins() {
  const svg = $("map"); if (!svg || typeof ST === "undefined" || !ST.area || !pos || $("mapMode").value !== "street" || typeof places === "undefined") return;
  const old = svg.querySelector("#plPins"); if (old) old.remove();
  const v = stView(), g = document.createElementNS("http://www.w3.org/2000/svg", "g"); g.id = "plPins";
  places.forEach((p, i) => {
    if (!isFinite(p.lat) || !isFinite(p.lon)) return; const [x, y] = stXY(v, p.lat, p.lon);
    if (x < ST.vb.x0 - 5 || x > ST.vb.x1 + 5 || y < ST.vb.y0 - 5 || y > ST.vb.y1 + 5) return;
    if (Math.abs(p.lat - pos[0]) < 2e-5 && Math.abs(p.lon - pos[1]) < 2e-5) return;
    const k = document.createElementNS("http://www.w3.org/2000/svg", "g"); k.setAttribute("transform", `translate(${x.toFixed(1)},${y.toFixed(1)})`); k.style.cursor = "pointer";
    k.innerHTML = `<title>עבור אל ${esc(p.n)}</title><path d="M0,0 C-6,-8 -7,-11 -7,-14 A7,7 0 1,1 7,-14 C7,-11 6,-8 0,0Z" fill="var(--color-primary)" stroke="var(--color-surface)" stroke-width="1.5"/><circle cy="-14" r="2.6" fill="var(--color-surface)"/><text y="-24" text-anchor="middle" font-size="11" font-weight="700" fill="var(--color-on-surface)" paint-order="stroke" stroke="var(--color-surface)" stroke-width="3">${esc(p.n)}</text>`;
    k.addEventListener("pointerdown", e => e.stopPropagation());
    k.addEventListener("click", e => { e.stopPropagation(); $("pl").value = String(i); $("pl").dispatchEvent(new Event("change")) });
    g.appendChild(k);
  });
  svg.appendChild(g);
}
(function () { const sm = streetMap; streetMap = async function () { const r = await sm.apply(this, arguments); try { plPins() } catch (e) {} return r } })();

/* זיהוי ידני: הסבר מורחב ואיור לכל דרך. למעלה באיור = הכיוון לירושלים; השמש, הצל והצפון מתעדכנים לפי השעה והמיקום */
function wayIll(a, mark) {
  const x = (50 + 34 * Math.sin(a * R)).toFixed(1), y = (50 - 34 * Math.cos(a * R)).toFixed(1);
  return `<svg viewBox="0 0 100 100" aria-hidden="true"><circle cx="50" cy="50" r="40" fill="none" stroke="var(--color-outline)"/><path d="M50,50 L50,14" stroke="var(--color-primary)" stroke-width="3"/><path d="M44,22 L50,10 L56,22Z" fill="var(--color-primary)"/><circle cx="50" cy="50" r="4" fill="var(--color-on-surface)"/>${mark(x, y)}</svg>`;
}
function wayExtra(t, b, s) {
  const N = "<small>החץ באיור = הכיוון לירושלים. האיור והמספרים מתעדכנים לפי השעה והמיקום.</small>";
  const sunM = (x, y) => `<circle cx="${x}" cy="${y}" r="7" fill="#e0a526"/>`;
  const dot = (c, txt) => (x, y) => `<circle cx="${x}" cy="${y}" r="4" fill="${c}"/><text x="${x}" y="${(+y - 7).toFixed(1)}" text-anchor="middle" font-size="11" fill="var(--color-on-surface)">${txt}</text>`;
  if (t === "מצפן רגיל" || t === "מצפן המכשיר") return wayIll(-b, dot("var(--color-on-surface)", "צ")) + `<span>הצפון נמצא במקום שמסומן ״צ״ ביחס לכיוון שאליו אתה פונה. מצפן מושפע ממתכת, ממגנטים ומרמקולים; בדוק אותו בשני מקומות. ${N}</span>`;
  if (t === "לפי השמש") return wayIll(s.az - b, sunM) + `<span>העיגול הזהוב הוא מקום השמש ביחס אליך כשאתה פונה לירושלים. השמש זזה כ-15° בשעה, ולכן ההוראה נכונה לרגע זה בלבד. ${N}</span>`;
  if (t === "לפי הצל") return wayIll(s.az + 180 - b, (x, y) => `<path d="M50,50 L${x},${y}" stroke="var(--color-on-surface-dim)" stroke-width="5" stroke-linecap="round" opacity=".6"/>`) + `<span>הפס האפור הוא הצל שלך כשאתה פונה לירושלים. אפשר גם לנעוץ מקל באדמה ולהסתכל על הצל שלו. ${N}</span>`;
  if (t === "לפי כוכב הצפון") return wayIll(-b, dot("#e0a526", "★")) + `<span>כוכב הצפון כמעט אינו זז במשך הלילה, וגובהו מעל האופק שווה בערך לקו הרוחב שלך. ${N}</span>`;
  if (t === "מקום מוכר") return `<span>בחר מקום מוכר בעיר (מגדל, הר, כביש ראשי) שהכיוון אליו ידוע לך, והשווה לחוגה.</span>`;
  if (t === "סיבוב ידני של החוגה") return `<span>מתאים למחשב בלי מצפן: מסובבים את החוגה עד שהיא תואמת את המציאות, ומאותו רגע החץ מראה את ירושלים.</span>`;
  return null;
}
const SID_URL = "https://github.com/e0548433917-gif/otzaria/raw/%D7%9B%D7%99%D7%95%D7%95%D7%9F-%D7%AA%D7%A4%D7%99%D7%9C%D7%94/siduron/com.moshenahari.siduron-3.7.1.otzplugin";
$("sidDl").onclick = () => { copyText(SID_URL); let w = null; try { w = window.open(SID_URL, "_blank", "noopener") } catch (x) {} if (!w && O) O.call("app.openUrl", { url: SID_URL }).catch(() => {}); $("sidMsg").textContent = "הכתובת הועתקה ללוח. אחרי ההורדה: התקנה מקובץ בחנות התוספים של אוצריא." };
