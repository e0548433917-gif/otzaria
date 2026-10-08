**כותרת:** allowlist: כתובות רשת לתוסף כיוון תפילה (com.shiachrina.kivuntefila)

הוספת הכתובות של התוסף **כיוון תפילה** ל-`plugin_network_allowlist.txt`. התוסף מצהיר על אותן כתובות ב-`network.allowlist` במניפסט שלו.

| כתובת | שימוש |
|---|---|
| `https://get.geojs.io/v1/ip/geo.json` | מיקום משוער לפי IP, כשאין GPS במחשב |
| `https://nominatim.openstreetmap.org/reverse` | שם היישוב לפי קואורדינטות, להצגה בלבד |
| `https://overpass-api.de/api/interpreter` | מפת הרחובות הסמוכים (OpenStreetMap), לזיהוי הכיוון לפי רחוב |
| `https://overpass.kumi.systems/api/interpreter` | שרת גיבוי לאותה שאילתה |

אזור רחובות שהורד נשמר בתיקייה הפרטית של התוסף, ומשם הוא עובד בלי אינטרנט. כלומר, הפנייה לרשת היא חד-פעמית לכל אזור. כל שאר התוסף עובד גם בלי הכתובות האלה.

התוסף והסבר מלא: https://github.com/e0548433917-gif/otzaria/tree/כיוון-תפילה

בנוסף, יש בקשה נפרדת (Issue) לפתיחת הרשאת Geolocation ל-WebView של תוספים.
