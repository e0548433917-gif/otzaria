/* כיוון תפילה — מצב טיסה: מיקום המטוס לפי מסלול המעגל הגדול והזמן, הכיוון לירושלים ביחס לכיוון הטיסה, וזמני היום בדרך.
   החישוב משוער: מניח מסלול ישיר במהירות קבועה בין היציאה לנחיתה. */
const FLY_AP = [["תל אביב – נתב״ג (TLV)", 32.0114, 34.8867], ["רמון – אילת (ETM)", 29.7237, 35.0114], ["ניו יורק – JFK", 40.6413, -73.7781], ["ניוארק (EWR)", 40.6895, -74.1745],
  ["לונדון – הית׳רו (LHR)", 51.47, -0.4543], ["לונדון – לוטון (LTN)", 51.8747, -0.3683], ["לונדון – סטנסטד (STN)", 51.885, 0.235], ["מנצ׳סטר (MAN)", 53.3537, -2.275],
  ["פריז – שארל דה גול (CDG)", 49.0097, 2.5479], ["פריז – אורלי (ORY)", 48.7262, 2.3652], ["בריסל (BRU)", 50.901, 4.4844], ["אמסטרדם (AMS)", 52.3105, 4.7683],
  ["ציריך (ZRH)", 47.4582, 8.5555], ["ז׳נבה (GVA)", 46.2381, 6.109], ["וינה (VIE)", 48.1103, 16.5697], ["פראג (PRG)", 50.1008, 14.26], ["פרנקפורט (FRA)", 50.0379, 8.5622],
  ["מינכן (MUC)", 48.3537, 11.775], ["בודפשט (BUD)", 47.4369, 19.2556], ["ורשה (WAW)", 52.1657, 20.9671], ["קרקוב (KRK)", 50.0777, 19.7848], ["קייב (KBP)", 50.345, 30.8947],
  ["אודסה (ODS)", 46.4268, 30.6765], ["איסטנבול (IST)", 41.2753, 28.7519], ["אתונה (ATH)", 37.9364, 23.9445], ["לרנקה (LCA)", 34.8751, 33.6249], ["דובאי (DXB)", 25.2532, 55.3657],
  ["מיאמי (MIA)", 25.7959, -80.287], ["שיקגו (ORD)", 41.9742, -87.9073], ["לוס אנג׳לס (LAX)", 33.9416, -118.4085], ["טורונטו (YYZ)", 43.6777, -79.6248],
  ["מונטריאול (YUL)", 45.4706, -73.7408], ["מקסיקו סיטי (MEX)", 19.4363, -99.0721], ["בואנוס איירס (EZE)", -34.8222, -58.5358], ["יוהנסבורג (JNB)", -26.1392, 28.246],
  ["מלבורן (MEL)", -37.669, 144.841], ["סידני (SYD)", -33.9399, 151.1753], ["בנגקוק (BKK)", 13.69, 100.7501]];
const FLY = { a: null, b: null, t0: 0, t1: 0, on: false, alt: false, T: null };
function flyPlace(v) {
  v = (v || "").trim(); if (!v) return null;
  const m = v.match(/^\s*(-?\d+(?:\.\d+)?)\s*[, ]\s*(-?\d+(?:\.\d+)?)\s*$/); if (m) return [+m[1], +m[2], v];
  const f = FLY_AP.find(x => x[0] === v) || C.find(x => x[0] === v) || FLY_AP.find(x => x[0].includes(v)) || C.find(x => x[0].includes(v));
  return f ? [f[1], f[2], f[0]] : null;
}
const flyPos = t => { const f = Math.max(0, Math.min(1, (t - FLY.t0) / (FLY.t1 - FLY.t0))); return gc(FLY.a, FLY.b, f) };
const flyHead = t => { const p = flyPos(Math.min(t, FLY.t1 - 6e4)), q = flyPos(Math.min(t, FLY.t1 - 6e4) + 6e4); return bearing(p, q) };
const flyTm = t => { const d = new Date(t), n = new Date(), k = Math.round((new Date(d).setHours(0, 0, 0, 0) - new Date(n).setHours(0, 0, 0, 0)) / 864e5);
  return (k === -1 ? "אתמול " : k === 1 ? "מחר " : k ? d.toLocaleDateString("he-IL") + " " : "") + d.toLocaleTimeString("he-IL", { hour: "2-digit", minute: "2-digit" }) };
const flyLL = p => `${p[0].toFixed(1)}°, ${p[1].toFixed(1)}°`;
/* שקיעת האופק בגובה הטיסה: כ-3.4° בגובה 11 ק״מ (רק כשהמשתמש בוחר בכך) */
/* גובה המטוס בק״מ: מה שהמשתמש הזין (מעודכן מהמסך במושב), ואם לא הוזן — הערכה: טיפוס 25 דק׳, שיוט 11 ק״מ, הנמכה 30 דק׳ */
function flyAltKm(t) {
  if (t < FLY.t0 || t > FLY.t1) return 0;
  if (FLY.altKm != null && t >= FLY.altAt) return FLY.altKm;
  const up = (t - FLY.T0) / 15e5, down = (FLY.t1 - t) / 18e5;
  return 11 * Math.max(0, Math.min(1, up, down));
}
const flyDip = t => FLY.alt ? Math.acos(6371 / (6371 + flyAltKm(t))) / R : 0;
const FLY_EV = t => [["עלות השחר (16.1°)", -16.1], ["הנץ החמה", -0.833 - flyDip(t)], ["שקיעה", -0.833 - flyDip(t)], ["צאת הכוכבים (8.5°)", -8.5]];
/* סורקים דקה אחר דקה את גובה השמש; posAt מחזיר את המיקום בכל רגע (קבוע, או לאורך הטיסה) */
function flyScan(t0, t1, posAt) {
  const out = []; let prev = null, prevT = 0, peak = -99, peakT = 0, rising = null;
  for (let t = t0; t <= t1; t += 6e4) {
    const p = posAt(t), a = sun(p[0], p[1], new Date(t)).alt;
    if (prev != null) {
      for (const [n, h] of FLY_EV(t)) {
        const up = n === "עלות השחר (16.1°)" || n === "הנץ החמה";
        if (up && prev < h && a >= h) out.push([t, n, p]);
        if (!up && prev > h && a <= h) out.push([t, n, p]);
      }
      if (a > prev) rising = true; else if (rising && a < prev && prev > -10) { out.push([prevT, "חצות היום (השמש בשיאה)", posAt(prevT)]); rising = false }
    }
    prev = a; prevT = t;
  }
  return out.sort((x, y) => x[0] - y[0]);
}
/* זמנים לפי שעות זמניות במקום שבו נמצא המטוס באותו רגע: הנץ ושקיעה ביום של אותו מקום (בגובה הקרקע), ופתרון חוזר כי המקום זז עם הזמן */
function flyDay(p, t) {
  let best = -99, tr = t;
  for (let u = t - 432e5; u <= t + 432e5; u += 3e5) { const a = sun(p[0], p[1], new Date(u)).alt; if (a > best) { best = a; tr = u } }
  const cross = (from, step, want) => { let prev = sun(p[0], p[1], new Date(from)).alt; for (let u = from + step, i = 0; i < 1000; u += step, i++) { const a = sun(p[0], p[1], new Date(u)).alt; if ((prev - want) * (a - want) <= 0) return u; prev = a } return null };
  const sr = cross(tr, -6e4, -0.833), ss = cross(tr, 6e4, -0.833);
  return sr && ss ? { sr, ss } : null;
}
const FLY_Z = [["סוף זמן קריאת שמע (מג״א)", d => d.sr - 72 * 6e4 + 3 * (d.ss - d.sr + 144 * 6e4) / 12],
  ["סוף זמן קריאת שמע (גר״א)", d => d.sr + 3 * (d.ss - d.sr) / 12], ["סוף זמן תפילה (גר״א)", d => d.sr + 4 * (d.ss - d.sr) / 12]];
function flyZmanim() {
  const out = [];
  for (const [n, f] of FLY_Z) for (const s0 of [FLY.t0, (FLY.t0 + FLY.t1) / 2, FLY.t1]) {
    /* פתרון t = זמן(מקום המטוס ב-t), בהחלשה כדי שיתכנס; תוצאה שלא התכנסה לא מוצגת */
    let t = s0, ok = false;
    for (let i = 0; i < 14; i++) { const d = flyDay(flyPos(t), t); if (!d) break; const nt = f(d); if (Math.abs(nt - t) < 6e4) { t = nt; ok = true; break } t = (t + nt) / 2 }
    if (ok && t >= FLY.t0 && t <= FLY.t1 && !out.some(e => e[1] === n && Math.abs(e[0] - t) < 3 * 36e5)) out.push([t, n, flyPos(t)]);
  }
  return out;
}
/* התראות: התראת מערכת של אוצריא (מתוזמנת מראש, עובדת גם כשהתוסף סגור) והודעה בתוך התוסף; ברירת מחדל 15 דק׳ לפני */
const FLY_ALERT = /^(סוף זמן|שקיעה|הנץ)/;
async function flySchedule(route) {
  if (!O || !$("flyNotify").checked) return;
  const lead = +$("flyLead").value * 6e4, now = Date.now();
  try { await O.call("notifications.cancelAll") } catch (e) {}
  let id = 6100;
  for (const e of route) {
    if (!FLY_ALERT.test(e[1]) || e[0] - lead <= now) continue;
    try { await O.call("notifications.scheduleSystem", { title: `✈ ${e[1]} בעוד ${$("flyLead").value} דק׳`, body: `בשעה ${flyTm(e[0])} (שעון המכשיר), לפי מיקום המטוס המשוער. כיוון תפילה`, scheduledTime: new Date(e[0] - lead).toISOString(), id: id++ }) } catch (er) {}
  }
}
function flyAlerts(route, now) {
  const lead = +$("flyLead").value * 6e4, key = route.map(e => e[1] + Math.round(e[0] / 6e4)).join("|") + lead + $("flyNotify").checked;
  if (key !== FLY.schedKey) { FLY.schedKey = key; flySchedule(route) }
  FLY.shown = FLY.shown || {};
  for (const e of route) {
    if (!FLY_ALERT.test(e[1])) continue;
    const k = e[1] + Math.round(e[0] / 6e4), left = e[0] - now;
    if (left > 0 && left <= lead && !FLY.shown[k]) {
      FLY.shown[k] = 1; const msg = `${e[1]} בעוד ${Math.round(left / 6e4)} דק׳ (${flyTm(e[0])})`;
      $("flyAlert").textContent = "⏰ " + msg; $("flyAlert").hidden = false;
      if (O) O.call("notifications.showInApp", { message: "✈ " + msg, type: "info" }).catch(() => {});
    }
  }
}
function flyRel(d) {
  const r = Math.round(((d % 360) + 360) % 360), clock = Math.round(r / 30) % 12 || 12;
  const side = r <= 15 || r >= 345 ? "ישר לפנים" : r < 165 ? `${r}° מימין לכיוון הטיסה` : r <= 195 ? "מאחור" : `${360 - r}° משמאל לכיוון הטיסה`;
  return `${side} (בכיוון השעה ${clock})`;
}
function flyDraw() {
  if (!FLY.a) return;
  const now = Date.now(), f = (now - FLY.t0) / (FLY.t1 - FLY.t0), p = flyPos(now), o = $("flyOut");
  const st = f < 0 ? `לפני ההמראה (עוד ${Math.round((FLY.t0 - now) / 6e4)} דק׳). המיקום: נקודת היציאה.` : f > 1 ? "הטיסה הסתיימה לפי השעות שהוזנו." : `באוויר: ${Math.round(100 * dist(FLY.A0, p) / (dist(FLY.A0, p) + dist(p, FLY.b) || 1))}% מהדרך, נותרו כ-${Math.round((FLY.t1 - now) / 6e4)} דק׳.`;
  const bj = bearing(p, J), hd = flyHead(now);
  const here = flyScan(now - 12 * 36e5, now + 12 * 36e5, () => p).filter(e => e[0] > now - 36e5 * 12);
  const route = flyScan(FLY.t0, FLY.t1, flyPos).concat(flyZmanim()).sort((x, y) => x[0] - y[0]); flyAlerts(route, now);
  const row = e => `<tr><td>${flyTm(e[0])}</td><td>${esc(e[1])}</td><td><small>${flyLL(e[2])}</small></td></tr>`;
  const ak = flyAltKm(now), altTxt = f >= 0 && f <= 1 ? ` · גובה ${FLY.altKm != null && now >= FLY.altAt ? "" : "משוער "}${(ak * 1000).toLocaleString("he-IL", { maximumFractionDigits: 0 })} מ׳ (${Math.round(ak * 3280.84).toLocaleString("he-IL")} רגל)` : "";
  FLY.last = { now, p, bj, hd, here, route };
  o.innerHTML = `<p><b>${st}</b></p><p>מיקום משוער: ${flyLL(p)} · כיוון הטיסה ${Math.round(hd)}° (${nm(hd)})${altTxt}</p>`
    + `<p class="flybig">ירושלים: ${flyRel(bj - hd)}</p><p>מהצפון: ${Math.round(bj)}° · ${nm(bj)}. מרחק: ${Math.round(dist(p, J)).toLocaleString("he-IL")} ק״מ.</p>`
    + `<h3>זמני היום במיקום הנוכחי</h3>` + (here.length ? `<table class="halt">${here.map(row).join("")}</table>` : "<p>אין שינוי בשעות הקרובות.</p>")
    + `<h3>לאורך הטיסה${FLY.re ? " (מהעדכון האחרון)" : ""}</h3>` + (route.length ? `<table class="halt">${route.map(row).join("")}</table>` : "<p>אין זריחה, שקיעה או צאת הכוכבים בזמן הטיסה.</p>")
    + `<p><small>השעות לפי השעון במכשיר שלך. חישוב משוער (מסלול ישיר, מהירות קבועה), בדיוק של דקות ספורות. ${FLY.alt ? "הזריחה והשקיעה לפי גובה המטוס בכל רגע." : "הזריחה והשקיעה לפי גובה פני הקרקע שמתחת למטוס."} האם להתחשב בגובה המטוס, ובכלל הזמנים בטיסה, היא שאלה לרב.</small></p>`;
  $("flyGlobe").innerHTML = flyGlobe(FLY.A0, FLY.b, f >= 0 && f <= 1 ? p : null);
  if (FLY.on && f >= 0) setPos(p, f > 1 ? "נחיתה: " + FLY.b[2] : "במטוס, בדרך ל" + FLY.b[2], null, false);
}
/* כדור הארץ: המסלול (קו קצר), המטוס וירושלים, בהטלה אורתוגרפית סביב אמצע המסלול */
let FLY_RINGS = null;
function flyRings() {
  if (FLY_RINGS) return FLY_RINGS; FLY_RINGS = [];
  if (typeof WORLD_PATH !== "undefined") for (const s of WORLD_PATH.split("M")) if (s) FLY_RINGS.push(s.replace(/Z/g, "").split("L").map(q => { const [x, y] = q.split(",").map(Number); return [-y, x] }).filter(q => isFinite(q[0]) && isFinite(q[1])));
  return FLY_RINGS;
}
function flyGlobe(a, b, p) {
  const m = gc(a, b, .5), c0 = m[0] * R, l0 = m[1] * R, r = 100;
  const pr = q => { const f = q[0] * R, l = q[1] * R - l0; return [r * Math.cos(f) * Math.sin(l), -r * (Math.cos(c0) * Math.sin(f) - Math.sin(c0) * Math.cos(f) * Math.cos(l)), Math.sin(c0) * Math.sin(f) + Math.cos(c0) * Math.cos(f) * Math.cos(l) > 0] };
  const line = pts => { let d = "", on = false; for (const q of pts) { const [x, y, v] = pr(q); if (v) { d += (on ? "L" : "M") + x.toFixed(1) + "," + y.toFixed(1); on = true } else on = false } return d };
  let land = ""; for (const g of flyRings()) land += line(g);
  const rt = []; for (let i = 0; i <= 80; i++) rt.push(gc(a, b, i / 80));
  const dot = (q, c, s, t) => { const [x, y, v] = pr(q); return v ? `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${s}" class="${c}"/>` + (t ? `<text x="${x.toFixed(1)}" y="${(y - 5).toFixed(1)}" text-anchor="middle">${esc(t)}</text>` : "") : "" };
  return `<svg class="flyglobe" viewBox="-104 -104 208 208" role="img" aria-label="מסלול הטיסה על כדור הארץ"><circle r="100" class="sea"/><path class="gl" d="${land}"/><path class="rt" d="${line(rt)}"/>${dot(a, "pa", 2.5)}${dot(b, "pa", 2.5)}${dot(J, "pj", 3, "ירושלים")}${p ? dot(p, "pp", 4) : ""}</svg>`;
}
/* זמן טיסה משוער לפי המרחק: מהירות שיוט ממוצעת כ-830 קמ״ש ועוד כחצי שעה להמראה ולנחיתה */
const flyEstMin = (a, b) => Math.round(dist(a, b) / 830 * 60 + 30);
function flyPrev() {
  const a = flyPlace($("flyA").value), b = flyPlace($("flyB").value), t = $("flyEstTxt");
  if (!a || !b) { t.textContent = ""; if (!FLY.on) $("flyGlobe").innerHTML = ""; return }
  const mn = flyEstMin(a, b);
  t.innerHTML = `מרחק: ${Math.round(dist(a, b)).toLocaleString("he-IL")} ק״מ · זמן טיסה משוער: כ-${Math.floor(mn / 60)}:${String(mn % 60).padStart(2, "0")} שעות <button id="flyEst" type="button">קבע נחיתה לפי ההערכה</button> <small>(הזמן בפועל תלוי ברוחות ובנתיב)</small>`;
  $("flyEst").onclick = () => { const t0 = Date.parse($("flyT0").value); if (!isFinite(t0)) return; const d = new Date(t0 + mn * 6e4); $("flyT1").value = new Date(d - d.getTimezoneOffset() * 6e4).toISOString().slice(0, 16) };
  if (!FLY.on) $("flyGlobe").innerHTML = flyGlobe(a, b, null);
}
function flyStart() {
  const a = flyPlace($("flyA").value), b = flyPlace($("flyB").value), t0 = Date.parse($("flyT0").value), t1 = Date.parse($("flyT1").value), m = $("flyMsg");
  if (!a || !b) { m.textContent = "לא זוהה מקום היציאה או הנחיתה. בחר מהרשימה, או הקלד קואורדינטות (למשל 40.64, -73.78)."; return }
  if (!(t1 > t0)) { m.textContent = "שעת הנחיתה צריכה להיות אחרי שעת היציאה."; return }
  if (t1 - t0 > 22 * 36e5) { m.textContent = "טיסה ארוכה מ-22 שעות? כדאי לבדוק את התאריכים."; return }
  m.textContent = ""; Object.assign(FLY, { a, b, A0: a, t0, t1, T0: t0, on: true, alt: $("flyAlt").checked, altKm: null, altAt: 0, re: false }); flyReadAlt();
  try { const v = JSON.stringify({ a: $("flyA").value, b: $("flyB").value, t0: $("flyT0").value, t1: $("flyT1").value, alt: FLY.alt, h: $("flyH").value, hu: $("flyHU").value }); O ? O.call("storage.set", { key: "kivun-fly", value: v }).catch(() => {}) : localStorage.setItem("kivun-fly", v) } catch (e) {}
  $("mapMode").value = "far"; flyDraw(); clearInterval(FLY.T); FLY.T = setInterval(flyDraw, 60000); $("flyStop").hidden = false;
}
/* גובה שהוזן ידנית (מהמסך במושב): ברגל או במטרים */
function flyReadAlt() { const v = parseFloat($("flyH").value); if (isFinite(v) && v > 0) { FLY.altKm = $("flyHU").value === "ft" ? v * .0003048 : v / 1000; FLY.altAt = Date.now() } else FLY.altKm = null }
/* עדכון באמצע הטיסה: שעת נחיתה חדשה (מהמסך או מהצוות) וגובה. המסלול ממשיך מהמיקום הנוכחי, כך שאין קפיצה */
function flyUpdate() {
  const m = $("flyMsg"), t1 = Date.parse($("flyT1").value), now = Date.now();
  if (!FLY.a) { flyStart(); return }
  if (!(t1 > now)) { m.textContent = "שעת הנחיתה המעודכנת צריכה להיות מאוחרת מעכשיו."; return }
  if (now > FLY.t0 && now < FLY.t1) { const p = flyPos(now); FLY.a = [p[0], p[1], "המיקום בעדכון"]; FLY.t0 = now; FLY.re = true }
  FLY.t1 = t1; FLY.alt = $("flyAlt").checked; flyReadAlt(); m.textContent = "עודכן."; flyDraw();
}
/* ״המראנו עכשיו״: שעת ההמראה = עכשיו, ושעת הנחיתה זזה באותו הפרש */
function flyTakeoff() { const now = new Date(), d = Date.parse($("flyT1").value) - Date.parse($("flyT0").value), loc = x => new Date(x - x.getTimezoneOffset() * 6e4).toISOString().slice(0, 16);
  $("flyT0").value = loc(now); if (d > 0) $("flyT1").value = loc(new Date(+now + d)); flyStart() }
/* לוח זמני הטיסה כטקסט מסודר, להעתקה או להדפסה */
function flySheet() {
  if (!FLY.last) flyDraw(); const L = FLY.last; if (!L) return null;
  const rows = []; for (let t = FLY.t0; t <= FLY.t1 + 1; t += 18e5) { const p = flyPos(t), h = flyHead(t), b = bearing(p, J); rows.push([t, p, flyRel(b - h), Math.round(b)]) }
  return { L, rows };
}
function flyText() { const S = flySheet(); if (!S) return "";
  const head = `טיסה מ${FLY.A0[2]} ל${FLY.b[2]} · המראה ${flyTm(FLY.T0)} · נחיתה ${flyTm(FLY.t1)} (שעון המכשיר)`;
  return [head, "", "זמני היום לאורך הטיסה:", ...(S.L.route.length ? S.L.route.map(e => `${flyTm(e[0])}  ${e[1]}  (${flyLL(e[2])})`) : ["אין זריחה, שקיעה או צאת הכוכבים בזמן הטיסה."]),
    "", "כיוון ירושלים כל חצי שעה:", ...S.rows.map(r => `${flyTm(r[0])}  ${flyLL(r[1])}  ירושלים ${r[2]} (${r[3]}° מהצפון)`),
    "", "חישוב משוער (מסלול ישיר, מהירות קבועה). בשאלה מעשית יש לשאול רב. — כיוון תפילה, אוצריא"].join("\n") }
function flyPrint() { const S = flySheet(); if (!S) return; const row = r => `<tr>${r.map(x => `<td>${x}</td>`).join("")}</tr>`;
  $("printHead").innerHTML = `<h1>זמני היום וכיוון התפילה בטיסה</h1><p><b>${esc(FLY.A0[2])} ← ${esc(FLY.b[2])}</b> · המראה ${flyTm(FLY.T0)} · נחיתה ${flyTm(FLY.t1)}</p>`
    + `<h2>זמני היום לאורך הטיסה</h2><table class="halt">${S.L.route.length ? S.L.route.map(e => row([flyTm(e[0]), esc(e[1]), flyLL(e[2])])).join("") : "<tr><td>אין זריחה, שקיעה או צאת הכוכבים בזמן הטיסה.</td></tr>"}</table>`
    + `<h2>כיוון ירושלים כל חצי שעה</h2><table class="halt">${S.rows.map(r => row([flyTm(r[0]), flyLL(r[1]), "ירושלים " + r[2], r[3] + "°"])).join("")}</table>`
    + `<p><small>השעות לפי השעון במכשיר. חישוב משוער (מסלול ישיר, מהירות קבועה). בשאלה מעשית יש לשאול רב.</small></p>`;
  document.body.classList.add("printfly"); try { window.print() } catch (e) {} setTimeout(() => document.body.classList.remove("printfly"), 1500) }
function flyStop() { if (O) O.call("notifications.cancelAll").catch(() => {}); $("flyAlert").hidden = true; FLY.on = false; clearInterval(FLY.T); FLY.T = null; $("flyStop").hidden = true; $("flyMsg").textContent = "המעקב הופסק. המיקום נשאר האחרון שחושב." }
(function () {
  const dl = $("flyList"); dl.replaceChildren(...[...FLY_AP, ...C].map(x => { const o = document.createElement("option"); o.value = x[0]; return o }));
  const loc = d => new Date(d - d.getTimezoneOffset() * 6e4).toISOString().slice(0, 16), n = new Date();
  $("flyT0").value = loc(n); $("flyT1").value = loc(new Date(+n + 4 * 36e5));
  $("bFly").onclick = () => pop("bFly", "fly", $("fly").hidden);
  for (const k of ["flyA", "flyB"]) { $(k).addEventListener("change", flyPrev); $(k).addEventListener("input", flyPrev) }
  $("flyGo").onclick = flyStart; $("flyStop").onclick = flyStop; $("flyUpd").onclick = flyUpdate; $("flyNow").onclick = flyTakeoff;
  $("flyCopy").onclick = () => { const t = flyText(); if (t) copyText(t).then(ok => $("flyMsg").textContent = ok ? "הלוח הועתק. אפשר להדביק בכל מקום." : "ההעתקה לא הצליחה.") };
  $("flyPrint").onclick = flyPrint;
  $("flyNotify").onchange = async () => {
    if ($("flyNotify").checked && O) { try { const r = dat(await O.call("notifications.requestPermissions")); if (r && r.granted === false) { $("flyNotify").checked = false; $("flyMsg").textContent = "אוצריא לא קיבלה הרשאה להתראות מערכת. ההודעה בתוך התוסף תמשיך לעבוד." } } catch (e) {} }
    FLY.schedKey = null; if (FLY.on) flyDraw() };
  $("flyLead").onchange = () => { FLY.schedKey = null; if (FLY.on) flyDraw() };
  (async () => {
    let v = null;
    try { v = O ? dat(await O.call("storage.get", { key: "kivun-fly" })) : localStorage.getItem("kivun-fly"); v = typeof v === "string" ? JSON.parse(v) : v } catch (e) { v = null }
    if (v && typeof v === "object") { $("flyA").value = v.a || ""; $("flyB").value = v.b || ""; if (v.t0) $("flyT0").value = v.t0; if (v.t1) $("flyT1").value = v.t1; $("flyAlt").checked = !!v.alt; if (v.h) $("flyH").value = v.h; if (v.hu) $("flyHU").value = v.hu }
    flyPrev();
  })();
})();
