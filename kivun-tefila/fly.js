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
const flyDip = () => FLY.alt ? Math.acos(6371 / (6371 + 11)) / R : 0;
const FLY_EV = () => [["עלות השחר (16.1°)", -16.1], ["הנץ החמה", -0.833 - flyDip()], ["שקיעה", -0.833 - flyDip()], ["צאת הכוכבים (8.5°)", -8.5]];
/* סורקים דקה אחר דקה את גובה השמש; posAt מחזיר את המיקום בכל רגע (קבוע, או לאורך הטיסה) */
function flyScan(t0, t1, posAt) {
  const out = []; let prev = null, prevT = 0, peak = -99, peakT = 0, rising = null;
  for (let t = t0; t <= t1; t += 6e4) {
    const p = posAt(t), a = sun(p[0], p[1], new Date(t)).alt;
    if (prev != null) {
      for (const [n, h] of FLY_EV()) {
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
function flyRel(d) {
  const r = Math.round(((d % 360) + 360) % 360), clock = Math.round(r / 30) % 12 || 12;
  const side = r <= 15 || r >= 345 ? "ישר לפנים" : r < 165 ? `${r}° מימין לכיוון הטיסה` : r <= 195 ? "מאחור" : `${360 - r}° משמאל לכיוון הטיסה`;
  return `${side} (בכיוון השעה ${clock})`;
}
function flyDraw() {
  if (!FLY.a) return;
  const now = Date.now(), f = (now - FLY.t0) / (FLY.t1 - FLY.t0), p = flyPos(now), o = $("flyOut");
  const st = f < 0 ? `לפני ההמראה (עוד ${Math.round((FLY.t0 - now) / 6e4)} דק׳). המיקום: נקודת היציאה.` : f > 1 ? "הטיסה הסתיימה לפי השעות שהוזנו." : `באוויר: ${Math.round(f * 100)}% מהדרך, נותרו כ-${Math.round((FLY.t1 - now) / 6e4)} דק׳.`;
  const bj = bearing(p, J), hd = flyHead(now);
  const here = flyScan(now - 12 * 36e5, now + 12 * 36e5, () => p).filter(e => e[0] > now - 36e5 * 12);
  const route = flyScan(FLY.t0, FLY.t1, flyPos);
  const row = e => `<tr><td>${flyTm(e[0])}</td><td>${esc(e[1])}</td><td><small>${flyLL(e[2])}</small></td></tr>`;
  o.innerHTML = `<p><b>${st}</b></p><p>מיקום משוער: ${flyLL(p)} · כיוון הטיסה ${Math.round(hd)}° (${nm(hd)})</p>`
    + `<p class="flybig">ירושלים: ${flyRel(bj - hd)}</p><p>מהצפון: ${Math.round(bj)}° · ${nm(bj)}. מרחק: ${Math.round(dist(p, J)).toLocaleString("he-IL")} ק״מ.</p>`
    + `<h3>זמני היום במיקום הנוכחי</h3>` + (here.length ? `<table class="halt">${here.map(row).join("")}</table>` : "<p>אין שינוי בשעות הקרובות.</p>")
    + `<h3>לאורך הטיסה</h3>` + (route.length ? `<table class="halt">${route.map(row).join("")}</table>` : "<p>אין זריחה, שקיעה או צאת הכוכבים בזמן הטיסה.</p>")
    + `<p><small>השעות לפי השעון במכשיר שלך. חישוב משוער (מסלול ישיר, מהירות קבועה), בדיוק של דקות ספורות. ${FLY.alt ? "הזריחה והשקיעה לפי גובה הטיסה." : "הזריחה והשקיעה לפי גובה פני הקרקע שמתחת למטוס."} האם להתחשב בגובה המטוס, ובכלל הזמנים בטיסה, היא שאלה לרב.</small></p>`;
  if (FLY.on && f >= 0) setPos(p, f > 1 ? "נחיתה: " + FLY.b[2] : "במטוס, בדרך ל" + FLY.b[2], null, false);
}
function flyStart() {
  const a = flyPlace($("flyA").value), b = flyPlace($("flyB").value), t0 = Date.parse($("flyT0").value), t1 = Date.parse($("flyT1").value), m = $("flyMsg");
  if (!a || !b) { m.textContent = "לא זוהה מקום היציאה או הנחיתה. בחר מהרשימה, או הקלד קואורדינטות (למשל 40.64, -73.78)."; return }
  if (!(t1 > t0)) { m.textContent = "שעת הנחיתה צריכה להיות אחרי שעת היציאה."; return }
  if (t1 - t0 > 22 * 36e5) { m.textContent = "טיסה ארוכה מ-22 שעות? כדאי לבדוק את התאריכים."; return }
  m.textContent = ""; Object.assign(FLY, { a, b, t0, t1, on: true, alt: $("flyAlt").checked });
  try { const v = JSON.stringify({ a: $("flyA").value, b: $("flyB").value, t0: $("flyT0").value, t1: $("flyT1").value, alt: FLY.alt }); O ? O.call("storage.set", { key: "kivun-fly", value: v }).catch(() => {}) : localStorage.setItem("kivun-fly", v) } catch (e) {}
  $("mapMode").value = "far"; flyDraw(); clearInterval(FLY.T); FLY.T = setInterval(flyDraw, 60000); $("flyStop").hidden = false;
}
function flyStop() { FLY.on = false; clearInterval(FLY.T); FLY.T = null; $("flyStop").hidden = true; $("flyMsg").textContent = "המעקב הופסק. המיקום נשאר האחרון שחושב." }
(function () {
  const dl = $("flyList"); dl.replaceChildren(...[...FLY_AP, ...C].map(x => { const o = document.createElement("option"); o.value = x[0]; return o }));
  const loc = d => new Date(d - d.getTimezoneOffset() * 6e4).toISOString().slice(0, 16), n = new Date();
  $("flyT0").value = loc(n); $("flyT1").value = loc(new Date(+n + 4 * 36e5));
  $("bFly").onclick = () => pop("bFly", "fly", $("fly").hidden);
  $("flyGo").onclick = flyStart; $("flyStop").onclick = flyStop;
  (async () => {
    let v = null;
    try { v = O ? dat(await O.call("storage.get", { key: "kivun-fly" })) : localStorage.getItem("kivun-fly"); v = typeof v === "string" ? JSON.parse(v) : v } catch (e) { v = null }
    if (v && typeof v === "object") { $("flyA").value = v.a || ""; $("flyB").value = v.b || ""; if (v.t0) $("flyT0").value = v.t0; if (v.t1) $("flyT1").value = v.t1; $("flyAlt").checked = !!v.alt }
  })();
})();
