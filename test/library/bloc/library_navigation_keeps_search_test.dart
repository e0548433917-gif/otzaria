import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/library/bloc/library_state.dart';
import 'package:otzaria/models/books.dart';

void main() {
  group('ניווט בספרייה משמר את שאילתת החיפוש', () {
    test('NavigateUp/NavigateToCategory מאפסים תוצאות בלבד — השאילתה נשמרת', () {
      const query = 'רמבם';
      final searched = const LibraryState().copyWith(
        searchQuery: query,
        searchResults: const <Book>[],
      );

      // ה-copyWith שמבצעים _onNavigateUp ו-_onNavigateToCategory.
      final navigated = searched.copyWith(
        searchQuery: null,
        searchResults: null,
        selectedTopics: null,
      );

      expect(
        navigated.searchQuery,
        query,
        reason:
            'לחצני "חזור"/"בית" במצב "אין תוצאות" מסתמכים על כך שה-SearchBooks '
            'שאחרי הניווט ירוץ עם אותו טקסט בתיקיית היעד',
      );
      expect(navigated.searchResults, isNull);
    });

    test('רק UpdateSearchQuery ריק מאפס את השאילתה', () {
      final cleared = const LibraryState()
          .copyWith(searchQuery: 'רמבם')
          .copyWith(searchQuery: '');

      expect(
        cleared.searchQuery,
        isEmpty,
        reason:
            'ניקוי תיבת החיפוש הוא מה שמאפס את החיפוש — לכן ניווט מהמצב הריק '
            'אינו מנקה אותה',
      );
    });
  });
}
