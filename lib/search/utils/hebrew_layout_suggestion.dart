/// זיהוי שאילתה שהוקלדה בעברית כשהמקלדת הייתה במצב אנגלית, והצעת התיקון.
///
/// המיפוי הוא לפי מיקום פיזי במקלדת (פריסת עברית תקנית SI-1452 מול QWERTY):
/// מי שהתכוון להקליד "תיקון" כשהמקלדת באנגלית קיבל ",heui". ההמרה הפוכה —
/// תו-אחר-תו לפי המקש — משחזרת את הכוונה.
///
/// עקרון מחייב (issue #975): התוצאה היא *הצעה בלבד*. שום קוד כאן או אצל
/// הקוראים לא מחליף את שאילתת המשתמש ולא מרחיב אותה — ההחלפה נעשית רק
/// בלחיצה מפורשת של המשתמש על ההצעה.
library;

/// QWERTY ← עברית תקנית: מה מפיק כל מקש כשהמקלדת במצב עברית.
const Map<String, String> _qwertyToHebrew = {
  'q': '/', 'w': "'", 'e': 'ק', 'r': 'ר', 't': 'א',
  'y': 'ט', 'u': 'ו', 'i': 'ן', 'o': 'ם', 'p': 'פ',
  'a': 'ש', 's': 'ד', 'd': 'ג', 'f': 'כ', 'g': 'ע',
  'h': 'י', 'j': 'ח', 'k': 'ל', 'l': 'ך',
  'z': 'ז', 'x': 'ס', 'c': 'ב', 'v': 'ה', 'b': 'נ',
  'n': 'מ', 'm': 'צ',
  // מקשי הפיסוק של השורות התחתונות מפיקים אותיות/פיסוק אחרים בעברית.
  ';': 'ף', "'": ',', ',': 'ת', '.': 'ץ', '/': '.', '`': ';',
};

final RegExp _hebrewLetter = RegExp(r'[א-ת]');
final RegExp _latinLetter = RegExp(r'[a-zA-Z]');

/// אם [query] נראית כהקלדה עברית שנעשתה במצב מקלדת אנגלי — מחזירה את
/// הטקסט המומר לפי מיקום המקשים; אחרת מחזירה null.
///
/// תנאי ההצעה שמרניים בכוונה:
/// - השאילתה מכילה לפחות שתי אותיות לטיניות (תו בודד = רעש).
/// - השאילתה אינה מכילה אף אות עברית (עירוב שפות הוא כנראה מכוון).
/// - התוצאה המומרת מכילה לפחות אות עברית אחת ושונה מהמקור.
///
/// תווים שאינם ממופים (רווחים, ספרות, גרשיים וכו') עוברים כמות שהם.
String? suggestHebrewKeyboardFix(String query) {
  if (query.isEmpty || _hebrewLetter.hasMatch(query)) return null;
  if (_latinLetter.allMatches(query).length < 2) return null;

  final buffer = StringBuffer();
  for (final rune in query.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_qwertyToHebrew[char.toLowerCase()] ?? char);
  }
  final converted = buffer.toString();

  if (converted == query || !_hebrewLetter.hasMatch(converted)) return null;
  return converted;
}
