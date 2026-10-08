# כיוון תפילה — שיח רינה-עמודי שש

## הורדה
- **כיוון תפילה 1.0.0:** [kivun-tefila-1.0.0.otzplugin](https://github.com/e0548433917-gif/otzaria/raw/%D7%9B%D7%99%D7%95%D7%95%D7%9F-%D7%AA%D7%A4%D7%99%D7%9C%D7%94/kivun-tefila-1.0.0.otzplugin)
- **סידורון 3.7.1 התואם** (עם כפתור לפתיחת כיוון תפילה; התוסף של Y-PLONI, נערך באישורו): [com.moshenahari.siduron-3.7.1.otzplugin](https://github.com/e0548433917-gif/otzaria/raw/%D7%9B%D7%99%D7%95%D7%95%D7%9F-%D7%AA%D7%A4%D7%99%D7%9C%D7%94/siduron/com.moshenahari.siduron-3.7.1.otzplugin) — פירוט השינויים בתיקיית [siduron](siduron)

---

# כיוון תפילה 1.0.0 — שיח רינה-עמודי שש

## בקשה לאוצריא (לזיהוי מיקום אוטומטי בלבד; כל השאר עובד בלעדיה)
1. הוספה ל-`plugin_network_allowlist.txt` (שורש הריפו Otzaria/otzaria, ענף `dev`) עבור `com.shiachrina.kivuntefila`:
   https://get.geojs.io/v1/ip/geo.json
   https://nominatim.openstreetmap.org/reverse
   (הקובץ נמשך בזמן ריצה; הקובץ המקומפל מחולל אוטומטית.)
2. גישת Geolocation ל-WebView של תוספים, ורצוי גם חיישני כיוון (DeviceOrientation).

## פתיחת התוסף מתוסף אחר (למשל סידורון)
- מתוך דף של תוסף: `Otzaria.call('plugin.openOther', { pluginId: 'com.shiachrina.kivuntefila' })`
  — דורש הצהרה על ההרשאה `plugin.open_other` ו-`minAppVersion` של 0.9.97 לפחות.
- הקישור `otzaria://open/plugin/com.shiachrina.kivuntefila` מיועד לפתיחה מחוץ לאוצריא בלבד
  (אתר, קיצור דרך, אפליקציה אחרת). מתוך דף של תוסף הוא אינו עובד.

נתוני מפה: Natural Earth. סטייה מגנטית: WMM-2025 (NOAA). שניהם נחלת הכלל.
