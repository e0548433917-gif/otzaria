# סידורון 3.7.1 — כפתור "כיוון תפילה"

ענף זה מכיל עדכון לתוסף **סידורון** (`com.moshenahari.siduron`) של Y-PLONI, שנעשה באישורו:
כפתור מצפן בשורת הכלים העליונה שפותח את התוסף **כיוון תפילה** (`com.shiachrina.kivuntefila`).

## הורדה
- התוסף המעודכן: [com.moshenahari.siduron-3.7.1.otzplugin](../../raw/siduron-kivun-tefila/com.moshenahari.siduron-3.7.1.otzplugin)
- כל השינויים מול 3.7.0: [siduron-kivun-tefila.diff](siduron-kivun-tefila.diff)
- הקבצים ששונו בלבד: תיקיית [src](src)

## מה השתנה
- `index.html` — כפתור `#btn-kivun` (אייקון מצפן) ליד "זמני היום".
- `js/app.js` — `openKivunTefila()` קורא ל-`plugin.openOther`; הודעת שגיאה ברורה אם התוסף אינו מותקן או שההרשאה לא אושרה. `updateKivunButton()` מסתיר את הכפתור כש-`plugin.listInstalled` מראה שכיוון תפילה אינו מותקן.
- `css/style.css` — `.tool-btn[hidden]`.
- `manifest.json` — גרסה 3.7.1, הרשאה חדשה `plugin.open_other`, `minAppVersion` 0.9.98 (נדרש: `plugin.openOther` ו-`plugin.listInstalled` קיימים מ-0.9.97).

נבדק מול טבלאות הגרסאות וההרשאות של אוצריא (ענף dev) ונבדק בפועל באוצריא.
הערה: קישור `otzaria://open/plugin/...` אינו עובד מתוך דף תוסף — לכן נעשה שימוש ב-`plugin.openOther`.
