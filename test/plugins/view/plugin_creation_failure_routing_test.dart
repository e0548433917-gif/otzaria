import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/view/plugin_tab_page.dart';

/// כשל היצירה מגיע ב-stream גלובלי, וכמה WebViewים נוצרים במקביל (מארח הרקע
/// וטאבים). הבדיקות מוודאות שכשל מנותב רק לטאב שביקש אותו URL.
void main() {
  const tabUrl = 'file:///plugins/a/index.html';
  const otherUrl = 'file:///plugins/b/index.html';
  const tabKey = ValueKey<String>('tab-a');
  const otherKey = ValueKey<String>('tab-b');

  group('shouldHandleCreationFailure', () {
    test('שתי יצירות מקבילות עם אותו URL — רק בעל המפתח התואם מגיב', () {
      // הטאב של תוסף A ממתין; הכשל שייך למופע של תוסף B.
      expect(
        shouldHandleCreationFailure(
          failureKey: otherKey,
          expectedKey: tabKey,
          failureUrl: tabUrl,
          expectedUrl: tabUrl,
          isCreated: false,
          alreadyFailed: false,
        ),
        isFalse,
      );

      expect(
        shouldHandleCreationFailure(
          failureKey: tabKey,
          expectedKey: tabKey,
          failureUrl: tabUrl,
          expectedUrl: tabUrl,
          isCreated: false,
          alreadyFailed: false,
        ),
        isTrue,
      );
    });

    test('טאב שה-WebView שלו כבר נוצר אינו מוחלף במסך שגיאה', () {
      expect(
        shouldHandleCreationFailure(
          failureKey: tabKey,
          expectedKey: tabKey,
          failureUrl: tabUrl,
          expectedUrl: tabUrl,
          isCreated: true,
          alreadyFailed: false,
        ),
        isFalse,
      );
    });

    test('כשל שכבר הוצג אינו מטופל שוב', () {
      expect(
        shouldHandleCreationFailure(
          failureKey: tabKey,
          expectedKey: tabKey,
          failureUrl: tabUrl,
          expectedUrl: tabUrl,
          isCreated: false,
          alreadyFailed: true,
        ),
        isFalse,
      );
    });

    test('אירוע ישן בלי מפתח נופל חזרה להתאמת URL', () {
      for (final unknown in <String?>[null, '']) {
        expect(
          shouldHandleCreationFailure(
            failureKey: null,
            expectedKey: tabKey,
            failureUrl: unknown,
            expectedUrl: tabUrl,
            isCreated: false,
            alreadyFailed: false,
          ),
          isTrue,
          reason: 'URL לא ידוע ($unknown) חייב להמשיך להציג את השגיאה',
        );
      }
    });

    test('אירוע ישן עם URL של טאב אחר אינו מטופל', () {
      expect(
        shouldHandleCreationFailure(
          failureKey: null,
          expectedKey: tabKey,
          failureUrl: otherUrl,
          expectedUrl: tabUrl,
          isCreated: false,
          alreadyFailed: false,
        ),
        isFalse,
      );
    });
  });
}
