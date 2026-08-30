import 'package:otzaria/models/links.dart';

/// עוזר לסנכרון מפרשים - מוצא את הקישור הטוב ביותר
class CommentarySyncHelper {
  /// בדיקה אם שורה היא כותרת (H1, H2, H3, H4...)
  static bool isHeaderLine(String line) {
    final headerPattern = RegExp(r'^\s*<h[1-6]', caseSensitive: false);
    return headerPattern.hasMatch(line);
  }

  /// מציאת האינדקס הלוגי (עם טיפול בכותרות)
  /// אם השורה היא כותרת, מחזיר את השורה הבאה
  static int getLogicalIndex(int currentIndex, List<String> content) {
    if (currentIndex < 0 || currentIndex >= content.length) {
      return currentIndex;
    }

    // אם השורה הנוכחית היא כותרת, נדלג לשורה הבאה
    int logicalIndex = currentIndex;
    while (logicalIndex < content.length &&
        isHeaderLine(content[logicalIndex])) {
      logicalIndex++;
    }

    // אם הגענו לסוף הטקסט, נחזור לאינדקס המקורי
    if (logicalIndex >= content.length) {
      return currentIndex;
    }

    return logicalIndex;
  }

  /// מחשב את אינדקס היעד במפרש עבור שורת מקור נתונה.
  ///
  /// היעד נקבע לפי הקישור הקודם הקרוב ביותר (before) — המפרש נצמד אליו עד
  /// שהשורה הנראית מגיעה לקישור הבא. אם אין קישור קודם, נצמדים לקישור הבא
  /// הראשון.
  ///
  /// [linksForCommentary] - הקישורים של המפרש (לא חייבים להיות ממוינים)
  /// [logicalMainIndex] - אינדקס השורה הלוגי במקור (0-based)
  /// מחזיר אינדקס 0-based במפרש, או null אם אין קישורים כלל.
  static int? getCommentaryTargetIndex({
    required List<Link> linksForCommentary,
    required int logicalMainIndex,
  }) {
    if (linksForCommentary.isEmpty) {
      return null;
    }

    final mainLineNumber = logicalMainIndex + 1; // המרה ל-1-based

    // שורת מקור אחת מקושרת לעיתים לעשרות שורות מפרש; בוחרים את תחילת הבלוק,
    // אחרת היעד נקבע לפי סדר הרשימה — שאינו מובטח — והנחיתה משתנה בין טעינות.
    Link? before;
    Link? after;
    for (final link in linksForCommentary) {
      if (link.index1 <= mainLineNumber) {
        if (before == null ||
            link.index1 > before.index1 ||
            (link.index1 == before.index1 && link.index2 < before.index2)) {
          before = link;
        }
      } else {
        if (after == null ||
            link.index1 < after.index1 ||
            (link.index1 == after.index1 && link.index2 < after.index2)) {
          after = link;
        }
      }
    }

    // תמיד מעדיפים את הקישור הקודם הקרוב; אם אין — את הקישור הבא הראשון
    if (before != null) {
      return before.index2 - 1; // המרה ל-0-based
    }
    return after == null ? null : after.index2 - 1;
  }

  /// המרחק בפיקסלים שיש לגלול כדי ששורת היעד תשב על קו העוגן.
  ///
  /// [leadingEdge] - הקצה העליון של שורת היעד, כשבר מגובה החלון
  /// [viewportHeight] - גובה חלון המפרש בפיקסלים
  /// [alignment] - קו העוגן, כשבר מגובה החלון
  /// [epsilon] - סף בפיקסלים שמתחתיו היעד נחשב במקומו
  /// מחזיר null כשאין צורך לזוז — כך שתזוזה של שבר פיקסל לא תירה אנימציה
  /// חדשה שמבטלת את הקודמת.
  static double? glideDelta({
    required double leadingEdge,
    required double viewportHeight,
    required double alignment,
    required double epsilon,
  }) {
    final delta = (leadingEdge - alignment) * viewportHeight;
    if (!delta.isFinite || delta.abs() < epsilon) {
      return null;
    }
    return delta;
  }

  /// האם להזיז את המפרש אל [targetIndex], בהינתן הסנכרון האחרון.
  ///
  /// המפרש זז רק כשהיעד או השורה הנבחרת שממנה הוא נגזר השתנו. הבדיקה היא על
  /// *שינוי* השורה הנבחרת ולא על עצם קיומה: בחירת טקסט פולטת מצב בכל תזוזת
  /// עכבר, ואנימציית הגלילה שנורית מחדש בכל אחת מהן מרעידה את המפרש
  /// (issue #976).
  ///
  /// [targetIndex] - אינדקס היעד במפרש
  /// [selectedMainIndex] - השורה הנבחרת בטקסט הראשי, או null כשאין
  /// [lastSyncedIndex] / [lastSyncedMainIndex] - מה שסונכרן בפעם הקודמת
  static bool shouldMoveCommentary({
    required int targetIndex,
    required int? selectedMainIndex,
    required int? lastSyncedIndex,
    required int? lastSyncedMainIndex,
  }) {
    return targetIndex != lastSyncedIndex ||
        selectedMainIndex != lastSyncedMainIndex;
  }
}
