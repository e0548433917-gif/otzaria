**כותרת:** תוספים: אפשרות לבקש מיקום (Geolocation) מה-WebView, בהרשאה מוצהרת

### הרקע
התוסף **כיוון תפילה** (`com.shiachrina.kivuntefila`) מחשב את הכיוון לירושלים. כרגע המשתמש בוחר עיר או מקליד קואורדינטות, וזה עובד גם בלי שום הרשאה. בטלפון ובמחשב עם GPS או Wi-Fi, מיקום אוטומטי היה מדויק בהרבה מעיר שנבחרה ידנית.

### המצב היום
ב-`lib/plugins/services/plugin_webview_permission_gate.dart` הטבלה `requirements` פותחת לתוספים רק את `CLIPBOARD_READ` ואת `LOCAL_FONTS`. כל בקשה אחרת נדחית ונרשמת בלוג, ובכלל זה `GEOLOCATION`. לכן `navigator.geolocation.getCurrentPosition` נכשל תמיד.

### ההצעה
1. להוסיף הרשאה חדשה, למשל `device.geolocation`, לרשימת ההרשאות התקפות ולמסך האישור של המשתמש.
2. להוסיף לטבלה `requirements` את השורה `'GEOLOCATION': pluginGeolocationPermission`. כך ההרשאה עוברת באותו מנגנון קיים: הצהרה במניפסט ואחריה אישור מפורש של המשתמש.
3. **אנדרואיד:** WebView של אנדרואיד לא מבקש מיקום דרך `onPermissionRequest` אלא דרך `onGeolocationPermissionsShowPrompt`. צריך לחבר גם אותו לאותו שער (ב-`plugin_tab_page.dart` וב-`plugin_background_host.dart`). בנוסף צריך `ACCESS_COARSE_LOCATION` ב-`AndroidManifest.xml`, כרגע אין שם הרשאת מיקום. לצורך התוסף מספיק מיקום משוער (Coarse).
4. **רשות, לא חובה:** חיישני כיוון (`DeviceOrientationEvent`) בטלפון, לתצוגת מצפן חי. בלי זה התוסף ממשיך לעבוד עם חוגה, שמש וצל.

### פרטיות
- המיקום לא יוצא מהמכשיר. החישוב נעשה כולו בתוך התוסף.
- הכתובת היחידה שמקבלת קואורדינטות היא `nominatim.openstreetmap.org/reverse`, וגם זה רק כדי להציג את שם היישוב. היא כבר נכללת ב-PR של ה-allowlist.
- בלי ההרשאה, התוסף נופל חזרה למיקום משוער לפי IP או לבחירה ידנית.

תודה!
