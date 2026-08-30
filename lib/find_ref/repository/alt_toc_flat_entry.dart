/// רשומת AltToc שטוחה, מיועדת לחיפוש גלובלי על פני כל הספרים בבת אחת.
///
/// נוצרת מראש (lazy, פעם אחת ל-session) מתוך שאילתת DB אחת שמאחדת את כל
/// טבלאות ה-AltToc. כל שדה — כולל `refTokens` המנורמלים — מחושב פעם אחת
/// בעת בניית הקאש, כך שהפילטר לכל שאילתה הוא O(N) מעבר על הרשימה בלבד.
class AltTocFlatEntry {
  /// מזהה הספר ב-DB.
  final int bookId;

  /// שם הספר (כפי שמופיע ב-`book.title`).
  final String bookTitle;

  /// `book.orderIndex` של הספר — משמש למיון תוצאות, בלי לחפש שוב ב-cache.
  final double bookOrderIndex;

  /// הנתיב המלא של הערך, יחסי לספר (ללא שם הספר). למשל:
  ///   "פרשת לך לך עליה ו"
  final String reference;

  /// ה-`lineIndex` בספר שאליו יש לנווט; 0 אם הערך אינו מקושר לשורה.
  final int segment;

  /// רמת הערך (1 = שורש, 2 = ילד, ...).
  final int level;

  /// `line.id` הגלובלי של השורה המקושרת, אם קיים; 0 אם לא.
  final int dbLineId;

  /// טוקנים מנורמלים של [reference] (אחרי [normalizeForFindRefMatch]).
  /// משמש את הפילטר `queryTokens.every((qt) => refTokens.contains(qt))`.
  final List<String> refTokens;

  const AltTocFlatEntry({
    required this.bookId,
    required this.bookTitle,
    required this.bookOrderIndex,
    required this.reference,
    required this.segment,
    required this.level,
    required this.dbLineId,
    required this.refTokens,
  });
}

/// פילטר ההתאמה של ה-fallback הגלובלי — משותף למסלול המקומי (main isolate)
/// ול-worker isolate, כדי שהסמנטיקה תישאר זהה בשני המסלולים.
///
/// [maxRefTokens] מגביל את אורך הערך (מסלול מילה בודדת); `null` = ללא הגבלה.
bool altTocFlatMatches(
  List<String> refTokens,
  List<String> queryTokens, {
  int? maxRefTokens,
}) {
  if (maxRefTokens != null && refTokens.length > maxRefTokens) return false;
  return queryTokens.every(refTokens.contains);
}
