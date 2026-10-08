/* כיוון תפילה 1.3 — תוספות: בתי כנסת בלחיצה, מצב תפילה, הדפסה, זכירת התצוגה, מיקוד. */

/* ---- שדות המיקום הידני מתעדכנים לפי המיקום הנוכחי ---- */
(function () {
  const sp = setPos;
  setPos = function (p) { sp.apply(this, arguments); if (p) { $("lat").value = (+p[0]).toFixed(5); $("lon").value = (+p[1]).toFixed(5) } };
})();

/* ---- בתי כנסת: לחיצה על ✡, ובית הכנסת הקרוב ---- */
function synText(s) {
  const d = Math.round(dist(pos, [s[1], s[2]]) * 1000), b = bearing(pos, [s[1], s[2]]);
  return `✡ ${s[0] || "בית כנסת"}: ${d >= 1000 ? (d / 1000).toFixed(1) + ' ק"מ' : d + " מ'"} ממך, לכיוון ${nm(b)}.`;
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
async function pcFind() {
  const raw = ($("pc").value || "").trim().toUpperCase(), z = raw.replace(/[^0-9A-Z]/g, ""), t = $("txt");
  if (z.length < 3) { t.textContent = "יש להזין מיקוד (בארץ 7 ספרות; בחו\u05f4ל כפי שהוא, למשל 11219 או N16 6XS)."; return }
  const d = await pcLoad();
  if (!d) { t.textContent = "טבלת המיקודים אינה זמינה בגרסה זו."; return }
  let p = null, lbl = "מיקוד " + raw;
  if (/^\d{7}$/.test(z)) { p = d.f[z]; if (!p && d.p[z.slice(0, 5)]) { p = d.p[z.slice(0, 5)]; lbl += " (משוער לפי האזור)" } }
  if (!p && d.x) { p = d.x[z]; if (!p && raw.includes(" ")) { p = d.x[raw.split(/\s+/)[0]]; if (p) lbl += " (משוער לפי האזור)" } }
  if (!p) { t.textContent = `המיקוד ${raw} לא נמצא בטבלה. נסה קואורדינטות או בחירת עיר.`; return }
  $("city").value = ""; setPos([p[0], p[1]], lbl, null, false);
  mode = "m:" + p[0] + "," + p[1]; save(mode);
}

/* ---- מראי מקומות: פתיחה בספריית אוצריא ---- */
async function openSrc(q, r) {
  if (!O) return;
  try {
    const l = dat(await O.call("library.findBooks", { query: q, limit: 10 })) || [];
    const b = l.find(x => x.title === q || x.bookId === q) || l.find(x => (x.title || "").includes(q)) || l[0];
    if (b) { const ok = dat(await O.call("reader.openBookAtRef", { bookId: b.bookId, ref: r, highlight: true })); if (ok !== false) return }
  } catch (e) {}
  try { await O.call("reader.openSearchTab", { query: q + " " + r }) } catch (e) {}
}
document.querySelectorAll("button.src").forEach(b => b.onclick = () => openSrc(b.dataset.q, b.dataset.r));
if (!O) document.querySelectorAll("button.src").forEach(b => b.disabled = true);

/* ---- מצפן זמין: מציגים את מצב התפילה גם במכשיר שאינו מגע ---- */
setInterval(() => { if (heading != null) document.body.classList.add("hascompass") }, 2000);

/* ---- הורדת האזור של המיקום הנוכחי מתוך ההגדרות ---- */
$("setDl").onclick = () => { if (!pos) return; pop("bSet", "set", false); $("mapMode").value = "street"; map(); setTimeout(() => stDownload(), 300) };

/* ---- דף ההורדה: פותח בדפדפן, ומעתיק את הכתובת ללוח ---- */
const DL_URL = "https://github.com/e0548433917-gif/otzaria/tree/%D7%9B%D7%99%D7%95%D7%95%D7%9F-%D7%AA%D7%A4%D7%99%D7%9C%D7%94";
$("dlLink").onclick = () => { copyText(DL_URL); let w = null; try { w = window.open(DL_URL, "_blank", "noopener") } catch (e) {} if (!w && O) O.call("app.openUrl", { url: DL_URL }).catch(() => {}); $("dlLink").textContent = "הכתובת הועתקה ללוח" };

/* ---- הסבר השימוש במפה מוצג בשורה התחתונה, רק בתצוגת הרחובות ---- */
(function () { const mp = map; map = function () { const r = mp.apply(this, arguments); $("stHint").hidden = $("stPanel").hidden; return r } })();

/* ---- חיבור ---- */
$("bPray").onclick = () => prayOpen(true);
$("prayX").onclick = () => prayOpen(false);
addEventListener("keydown", e => { if (e.key === "Escape" && !$("pray").hidden) prayOpen(false) });
$("stSynNear").onclick = synNearest;
$("bPrint").onclick = printSheet;
$("bHal").onclick = () => pop("bHal", "hal", $("hal").hidden);
$("pcGo").onclick = pcFind;
$("pc").onkeydown = e => { if (e.key === "Enter") pcFind() };
$("mapMode").addEventListener("change", () => { ST.synSel = null });
/* הסבר קצר ליד שדה המיקוד, לפי מה שיש בחבילה */
function pcCheck() { pcLoad().then(d => { $("pcNote").textContent = d ? "בארץ: 7 ספרות. בחו\u05f4ל: כפי שהוא, בריכוזי הקהילה." : "טבלת המיקודים בבנייה ותצורף בגרסה 1.3.0." }) }
function extrasBoot() { viewRestore(); pcCheck() }
if (!O) extrasBoot();
