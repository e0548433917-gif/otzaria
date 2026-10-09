"""Merge whatever build outputs are ready into the plugin folder; list what is still missing."""
import json, re, subprocess, sys, os

MH = "/home/claude/mh"
KT = "/home/claude/dist/kivun-tefila"
S = os.path.dirname(__file__)


def show(branch, path):
    subprocess.run(["git", "-C", MH, "fetch", "-q", "origin", f"+refs/heads/{branch}:refs/remotes/origin/{branch}"], check=False)
    r = subprocess.run(["git", "-C", MH, "show", f"origin/{branch}:{path}"], capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else None


def areas_of(txt):
    return json.loads(re.search(r"EMB_STREETS=(\[.*\]);", txt, re.S).group(1)) if txt else []


main = areas_of(show("kivun-streets-build", "kivun/streets-data.js"))
vac = areas_of(show("kivun-small-build", "kivun/streets-data.js")) + areas_of(show("kivun-vacation-build", "kivun/streets-data.js")) + areas_of(show("kivun-vacation2-build", "kivun/streets-data.js")) + areas_of(show("kivun-vacation3-build", "kivun/streets-data.js")) + areas_of(show("kivun-vacation4-build", "kivun/streets-data.js"))
names = {a["name"] for a in main}
allareas = main + [a for a in vac if a["name"] not in names and not names.add(a["name"])]  # שם כפול: הראשון (יישובים קטנים) גובר
wide = {a["name"]: a for a in areas_of(show("kivun-abroad-wide", "kivun/streets-data.js"))}
allareas = [wide.get(a["name"], a) for a in allareas]  # חו"ל: רדיוס מורחב
head = "/* רחובות מובנים: © OpenStreetMap contributors, ODbL. */"
emb = [a for a in allareas if len(a["w"]) >= 3]  # אזור בלי רחובות (הבנייה לא מצאה) לא נכלל כמובנה, אבל נשאר ברשימת הערים
open(f"{S}/merged.js", "w", encoding="utf-8").write(head + "\nconst EMB_STREETS=" + json.dumps(emb, ensure_ascii=False, separators=(",", ":")) + ";\n")
subprocess.run([sys.executable, f"{S}/split.py", f"{S}/merged.js", KT], check=True)

# postcodes
il = show("kivun-postcodes-build", "kivun/postcodes.js") or show("kivun-postcodes-il", "kivun/postcodes-il.js")
ab = show("kivun-postcodes-abroad", "kivun/postcodes-abroad.js")
ab2 = show("kivun-postcodes-abroad3", "kivun/postcodes-abroad2.js") or show("kivun-postcodes-abroad2", "kivun/postcodes-abroad2.js")
pc = {"d": "", "f": {}, "p": {}, "x": {}, "y": {}}
for t in (il, ab, ab2):
    if t:
        d = json.loads(re.search(r"PC_PUT\((.*)\);", t, re.S).group(1))
        pc["d"] = d.get("d", pc["d"])
        for k in ("f", "p", "x", "y"):
            pc[k].update(d.get(k) or {})
pcfile = f"{KT}/postcodes.js"
if pc["y"]:
    pc["x"] = {k: v for k, v in pc["x"].items() if k not in pc["y"]}  # הטבלה הישנה רק כגיבוי למיקודים שעוד לא בנויים לפי אזור
if pc["f"] or pc["x"] or pc["y"]:
    open(pcfile, "w", encoding="utf-8").write("/* מיקודים: © OpenStreetMap contributors, ODbL. */\nPC_PUT(" + json.dumps(pc, ensure_ascii=False, separators=(",", ":")) + ");\n")
else:
    open(pcfile, "w", encoding="utf-8").write("/* אין עדיין טבלת מיקודים */\nPC_PUT(null);\n")

# city list: add every embedded area missing from C
idx = open(f"{KT}/index.html", encoding="utf-8").read()
m = re.search(r"const C=(\[.*?\]\]);", idx, re.S)
C = json.loads(m.group(1))
have = {c[0] for c in C}
add = [[a["name"], a["lat"], a["lon"]] for a in allareas if a["name"] not in have]
C += add
idx = idx[:m.start(1)] + json.dumps(C, ensure_ascii=False, separators=(",", ":")) + idx[m.end(1):]

# planned list = whatever did not arrive
planned = []
want14 = ["נתניה – קרית צאנז", "רחובות", "אשקלון", "קרית מלאכי", "ירושלים – רוממה", "גבעת זאב", "ברוקלין – פלטבוש", "ברוקלין – קראון הייטס",
          "פאר רוקוויי", "פסאיק", "קליבלנד", "לונדון – גולדרס גרין", "סרסל", "סידני"]
wantvac = ["מירון", "ספסופה", "ראש פינה", "קצרין", "נהריה", "ים המלח – עין בוקק", "אילת", "הקטסקילס – סאות' פולסבורג"]
got = {a["name"] for a in allareas}
miss = [n for n in want14 if n not in got]
missv = [n for n in wantvac if n not in got]
if miss: planned.append("אזורים מובנים נוספים: " + ", ".join(miss) + ".")
wantvac2 = ["חספין", "עין גב", "מעלות", "שלומי", "מטולה", 'נווה אטי"ב', "עין גדי", "מצפה רמון", "ארוזה (שווייץ)", "דאבוס", "לוגאנו", "מיאמי ביץ'", "דיל (ניו ג'רזי)", "מונטיצ'לו (הקטסקילס)"]
missv += [n for n in wantvac2 if n not in got]
if missv: planned.append("אזורי נופש: " + ", ".join(missv) + ".")
else: planned.append("הצעות מהפורום יתווספו כאן.")
if not pc["f"]: planned.append("חיפוש לפי מיקוד בארץ.")
if not (pc["x"] or pc["y"]): planned.append("חיפוש לפי מיקוד בריכוזי הקהילה בחו״ל.")
li = "".join(f"<li>{p}</li>" for p in planned)
idx = re.sub(r'<ul id="planned">.*?</ul>', f'<ul id="planned">{li}</ul>', idx, flags=re.S)
idx = re.sub(r"\d+ ריכוזי קהילה מובנים בתוסף", f"{len(emb)} ריכוזי קהילה מובנים בתוסף", idx)
open(f"{KT}/index.html", "w", encoding="utf-8").write(idx)
print(f"areas {len(allareas)} (+{len(add)} to city list), postcodes IL {len(pc['f'])} prefix {len(pc['p'])} abroad {len(pc['x'])} by-area {len(pc['y'])}")
print("planned:", planned)
