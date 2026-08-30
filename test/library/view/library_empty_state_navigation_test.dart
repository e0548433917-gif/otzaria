import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/view/library_browser.dart';

void main() {
  group('libraryEmptyStateAction — לחצני "חזור"/"בית" במצב "אין תוצאות"', () {
    test('חיפוש בתת-תיקייה — הטקסט נשמר ומורץ מחדש בהיקף הרחב יותר', () {
      expect(
        libraryEmptyStateAction(hasSearchText: true, inSubCategory: true),
        LibraryEmptyStateAction.navigateKeepingSearch,
      );
    });

    test('חיפוש בתיקייה הראשית — אין היקף רחב יותר, החיפוש מתאפס', () {
      expect(
        libraryEmptyStateAction(hasSearchText: true, inSubCategory: false),
        LibraryEmptyStateAction.resetSearch,
      );
    });

    test('תיקייה ריקה בלי חיפוש — ניווט רגיל, אין מה לשמר או לאפס', () {
      expect(
        libraryEmptyStateAction(hasSearchText: false, inSubCategory: true),
        LibraryEmptyStateAction.navigate,
      );
      expect(
        libraryEmptyStateAction(hasSearchText: false, inSubCategory: false),
        LibraryEmptyStateAction.navigate,
      );
    });

    test('שמירת הטקסט והרמז "לחפש בתיקייה אחרת" מותנים באותו תנאי', () {
      // הרמז מוצג בדיוק כשיש היקף רחב יותר לנסות בו את אותו טקסט.
      for (final hasText in [true, false]) {
        for (final inSub in [true, false]) {
          final keepsSearch =
              libraryEmptyStateAction(
                hasSearchText: hasText,
                inSubCategory: inSub,
              ) ==
              LibraryEmptyStateAction.navigateKeepingSearch;
          expect(keepsSearch, hasText && inSub);
        }
      }
    });
  });
}
