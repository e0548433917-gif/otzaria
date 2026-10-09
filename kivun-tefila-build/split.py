"""Split the monolithic streets-data.js into an index + per-area delta-encoded files."""
import json, re, sys, os, glob

src, out = sys.argv[1], sys.argv[2]
txt = open(src, encoding="utf-8").read()
head = txt.split("\n", 1)[0]
areas = json.loads(re.search(r"EMB_STREETS=(\[.*\]);", txt, re.S).group(1))
for f in glob.glob(os.path.join(out, "st-*.js")):
    os.remove(f)
idx = []
for n, a in enumerate(areas, 1):
    B = (round(a["lat"] * 1e5), round(a["lon"] * 1e5))
    w = []
    for name, hw, g in a["w"]:
        x, y, o = B[0], B[1], []
        for i in range(0, len(g), 2):
            X, Y = round(g[i] * 1e5), round(g[i + 1] * 1e5)
            o += [X - x, Y - y]
            x, y = X, Y
        w.append([name, hw, o])
    s = [[nm, round(la * 1e5) - B[0], round(lo * 1e5) - B[1]] for nm, la, lo in a.get("s", [])]
    fn = f"st-{n:02d}.js"
    d = {k: a[k] for k in ("v", "k", "lat", "lon", "r", "d", "name", "emb")}
    d.update(z=2, w=w, s=s)
    open(os.path.join(out, fn), "w", encoding="utf-8").write(
        "EMB_PUT(" + json.dumps(d, ensure_ascii=False, separators=(",", ":")) + ");\n")
    idx.append({k: a[k] for k in ("k", "lat", "lon", "r", "d", "name")} | {"n": len(a["w"]), "f": fn})
open(os.path.join(out, "streets-data.js"), "w", encoding="utf-8").write(
    head + "\n/* אינדקס האזורים המובנים; נתוני כל אזור בקובץ st-NN.js */\nconst EMB_STREETS="
    + json.dumps(idx, ensure_ascii=False, separators=(",", ":")) + ";\n")
print(len(idx), "areas;", "bnei brak" if any(a["name"] == "בני ברק" for a in idx) else "NO BNEI BRAK",
      "; syn:", sum(len(a.get("s", [])) for a in areas))
