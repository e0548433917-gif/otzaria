/* כיוון תפילה 2.1 — תצוגת "כדור הארץ": הטלה אורתוגרפית, שני קווי החישוב, מסלול טיסה. גרירה מסובבת את הכדור. */
const GL = { dla: 0, dlo: 0 };
function rhumbPts(a, b, n) {
  let dl = b[1] - a[1]; if (dl > 180) dl -= 360; if (dl < -180) dl += 360;
  const y = f => Math.log(Math.tan(Math.PI / 4 + f * R / 2)), y0 = y(a[0]), y1 = y(b[0]), out = [];
  for (let i = 0; i <= n; i++) { const f = i / n, yy = y0 + (y1 - y0) * f; out.push([(2 * Math.atan(Math.exp(yy)) - Math.PI / 2) / R, a[1] + dl * f]) }
  return out;
}
function globeMap() {
  const svg = $("map"), vb = svg.viewBox.baseVal, W = vb && vb.width || 400, Hh = vb && vb.height || 320, cx = (vb ? vb.x : 0) + W / 2, cy = (vb ? vb.y : 0) + Hh / 2;
  const m = gc(pos, J, .5), c0 = Math.max(-89, Math.min(89, m[0] + GL.dla)) * R, l0 = (m[1] + GL.dlo) * R, r = Math.min(W, Hh) * .45 * (typeof zoom === "number" ? zoom : 1);
  const pr = q => { const f = q[0] * R, l = q[1] * R - l0; return [cx + r * Math.cos(f) * Math.sin(l), cy - r * (Math.cos(c0) * Math.sin(f) - Math.sin(c0) * Math.cos(f) * Math.cos(l)), Math.sin(c0) * Math.sin(f) + Math.cos(c0) * Math.cos(f) * Math.cos(l) > 0] };
  const line = pts => { let d = "", on = false; for (const q of pts) { const [x, y, v] = pr(q); if (v) { d += (on ? "L" : "M") + x.toFixed(1) + "," + y.toFixed(1); on = true } else on = false } return d };
  let land = ""; for (const g of flyRings()) land += line(g);
  if (typeof RIVERS_PATH !== "undefined") { GL.w = GL.w || [RIVERS_PATH, LAKES_PATH].map(t => t.split("M").filter(Boolean).map(s => s.replace(/Z/g, "").split("L").map(q => { const [x, y] = q.split(",").map(Number); return [-y, x] }))); var wat = GL.w.map(rs => rs.map(line).join("")) }
  let grat = ""; for (let lo = -180; lo < 180; lo += 30) { const p = []; for (let la = -90; la <= 90; la += 5) p.push([la, lo]); grat += line(p) }
  for (let la = -60; la <= 60; la += 30) { const p = []; for (let lo = -180; lo <= 180; lo += 5) p.push([la, lo]); grat += line(p) }
  const g = []; for (let i = 0; i <= 96; i++) g.push(gc(pos, J, i / 96));
  const rh = rhumbPts(pos, J, 96), sel = meth();
  const T = (q, t, c) => { const [x, y, v] = pr(q); return v ? `<text x="${x.toFixed(1)}" y="${(y - 8).toFixed(1)}" text-anchor="middle" font-size="12" fill="var(--color-${c})">${t}</text>` : "" };
  const D = (q, rr, c) => { const [x, y, v] = pr(q); return v ? `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${rr}" fill="var(--color-${c})"/>` : "" };
  const st = k => k === sel ? `stroke="var(--color-primary)" stroke-width="3"` : `stroke="var(--color-on-surface-dim)" stroke-width="1.8" stroke-dasharray="6 4"`;
  let h = `<circle cx="${cx}" cy="${cy}" r="${r.toFixed(1)}" fill="var(--color-surface-container-highest)" stroke="var(--color-outline)"/>`
    + `<path d="${grat}" fill="none" stroke="var(--color-outline)" stroke-width=".4" opacity=".6"/>`
    + `<path d="${land}" fill="none" stroke="var(--color-on-surface-dim)" stroke-width=".7"/>`
    + (wat ? `<path d="${wat[1]}" fill="none" stroke="#5b9bd5" stroke-width=".8"/><path d="${wat[0]}" fill="none" stroke="#5b9bd5" stroke-opacity=".8" stroke-width=".7"/>` : "")
    + `<path d="${line(g)}" fill="none" ${st("gc")}/><path d="${line(rh)}" fill="none" ${st("rh")}/>`;
  if (typeof FLY !== "undefined" && FLY.on && FLY.A0) {
    const fr = []; for (let i = 0; i <= 80; i++) fr.push(gc(FLY.A0, FLY.b, i / 80));
    const now = Date.now(), f = (now - FLY.t0) / (FLY.t1 - FLY.t0);
    h += `<path d="${line(fr)}" fill="none" stroke="var(--color-on-surface)" stroke-width="1.5" stroke-dasharray="2 3"/>` + D(FLY.A0, 3, "outline") + D(FLY.b, 3, "outline") + (f >= 0 && f <= 1 ? T(flyPos(now), "✈", "on-surface") : "");
  }
  h += D(J, 6, "primary") + T(J, "ירושלים", "on-surface") + D(pos, 5, "on-surface") + T(pos, "אתה", "on-surface");
  const ly = (vb ? vb.y : 0) + Hh - 8, lx = (vb ? vb.x : 0) + W - 8;
  h += `<text x="${lx}" y="${ly - 16}" text-anchor="end" font-size="11" fill="var(--color-${sel === "gc" ? "primary" : "on-surface-dim"})">${sel === "gc" ? "━" : "╌"} ${typeof LANG !== "undefined" && LANG === "en" ? "shortest line (globe)" : "קו קצר (כדור)"} ${Math.round(bearing(pos, J))}°</text>`
    + `<text x="${lx}" y="${ly}" text-anchor="end" font-size="11" fill="var(--color-${sel === "rh" ? "primary" : "on-surface-dim"})">${sel === "rh" ? "━" : "╌"} ${typeof LANG !== "undefined" && LANG === "en" ? "fixed bearing (map)" : "כיוון קבוע (מפה)"} ${Math.round(rhumb(pos, J))}°</text>`
    + `<text x="${(vb ? vb.x : 0) + 8}" y="${(vb ? vb.y : 0) + 16}" font-size="11" fill="var(--color-on-surface-dim)">גרירה מסובבת את הכדור</text>`;
  svg.innerHTML = h;
  if (typeof $ === "function" && $("stPanel")) $("stPanel").hidden = true;
}
{
  const prev = map;
  map = function () { if ($("mapMode").value === "globe" && pos) return globeMap(); return prev() };
  const svg = $("map"); let dr = null;
  svg.addEventListener("pointerdown", e => { if ($("mapMode").value !== "globe") return; dr = [e.clientX, e.clientY, GL.dla, GL.dlo]; try { svg.setPointerCapture(e.pointerId) } catch (x) {} });
  svg.addEventListener("pointermove", e => { if (!dr) return; const k = 180 / (svg.clientWidth || 400) / (typeof zoom === "number" ? zoom : 1); GL.dlo = dr[3] - (e.clientX - dr[0]) * k; GL.dla = dr[2] + (e.clientY - dr[1]) * k; globeMap() });
  addEventListener("pointerup", () => { dr = null });
  $("mapMode").addEventListener("change", () => { GL.dla = 0; GL.dlo = 0 });
  const zr = $("zReset"); if (zr) zr.addEventListener("click", () => { GL.dla = 0; GL.dlo = 0; if ($("mapMode").value === "globe" && pos) globeMap() });
}

/* הורדה אופציונלית: נהרות, אגמים וכבישים מפורטים (Natural Earth 1:10m), נשמרים במחשב */
let GEOX = null;
const GEOX_URL = "https://raw.githubusercontent.com/e0548433917-gif/otzaria/%D7%9B%D7%99%D7%95%D7%95%D7%9F-%D7%AA%D7%A4%D7%99%D7%9C%D7%94/kivun-tefila-data/geo-extra.json";
async function geoxLoad() {
  let t = null; try { t = O ? dat(await O.call("fs.readFile", { path: "geo-extra.json" })) : localStorage.getItem("kivun-geo-extra") } catch (e) {}
  try { if (t) { GEOX = typeof t === "string" ? JSON.parse(t) : t; $("geoMsg").textContent = "הורד ✓"; if (pos) map() } } catch (e) {}
}
$("geoDl").onclick = async () => {
  const m = $("geoMsg"); m.textContent = "מוריד…";
  try { const j = await getJ(GEOX_URL); if (!j || !j.r) throw 0; GEOX = j; const s = JSON.stringify(j);
    try { O ? await O.call("fs.writeFile", { path: "geo-extra.json", content: s }) : localStorage.setItem("kivun-geo-extra", s) } catch (e) {}
    m.textContent = "הורד ✓"; if (pos) map() } catch (e) { m.textContent = "ההורדה נכשלה. צריך חיבור לאינטרנט." }
};
setTimeout(geoxLoad, 1500);
