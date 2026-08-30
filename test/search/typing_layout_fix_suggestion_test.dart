import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/view/layout_fix_suggestion_banner.dart';
import 'package:otzaria/widgets/text/rtl_text_field.dart';

/// issue #975 — הצעת תיקון-מקלדת חיה תוך כדי הקלדה, על הטקסט הגולמי.
/// כך פסיק ונקודה (המקשים של ת ו-ץ) נכללים בהצעה — בניגוד לשאילתה
/// המנורמלת של החיפוש, שממנה הם כבר נמחקו.
Widget _host(
  TextEditingController controller, {
  ValueChanged<String>? onApplied,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: TypingLayoutFixSuggestion(
          controller: controller,
          onApplied: onApplied,
        ),
      ),
    ),
  );
}

void main() {
  late TextEditingController controller;

  setUp(() {
    controller = TextEditingController();
  });

  tearDown(() {
    controller.dispose();
  });

  testWidgets('ההצעה מופיעה ונעלמת בעקבות ההקלדה', (tester) async {
    await tester.pumpWidget(_host(controller));
    expect(find.textContaining('האם התכוונת'), findsNothing);

    controller.text = 'akuo';
    await tester.pump();
    expect(find.textContaining('שלום'), findsOneWidget);

    controller.text = 'שלום';
    await tester.pump();
    expect(find.textContaining('האם התכוונת'), findsNothing);
  });

  testWidgets('פסיק ונקודה נכללים בהצעה — cshe, → בדיקת', (tester) async {
    // "בדיקת" במצב מקלדת אנגלי: ב=c ד=s י=h ק=e ת=פסיק
    controller.text = 'cshe,';
    await tester.pumpWidget(_host(controller));
    expect(find.textContaining('בדיקת'), findsOneWidget);
  });

  group('נגישות מקלדת בסגנון Gmail (Tab מהשדה, Enter מחיל)', () {
    late FocusNode fieldNode;

    Widget keyboardHost() {
      return MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: [
                RtlTextField(controller: controller, focusNode: fieldNode),
                TypingLayoutFixSuggestion(
                  controller: controller,
                  fieldFocusNode: fieldNode,
                ),
              ],
            ),
          ),
        ),
      );
    }

    setUp(() {
      fieldNode = FocusNode(debugLabel: 'field');
    });

    tearDown(() {
      fieldNode.dispose();
    });

    testWidgets('Tab בשדה קופץ להצעה, Enter מחיל ומחזיר את הפוקוס לשדה', (
      tester,
    ) async {
      controller.text = 'akuo';
      await tester.pumpWidget(keyboardHost());
      fieldNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(fieldNode.hasFocus, isFalse, reason: 'Tab העביר את הפוקוס להצעה');

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(controller.text, 'שלום');
      expect(fieldNode.hasFocus, isTrue, reason: 'אחרי ההחלה חוזרים לשדה');
    });

    testWidgets('Ctrl+Tab (מעבר טאבים) אינו נבלע גם כשההצעה מוצגת', (
      tester,
    ) async {
      controller.text = 'akuo';
      await tester.pumpWidget(keyboardHost());
      fieldNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(
        controller.text,
        'akuo',
        reason: 'Ctrl+Tab שמור למעבר טאבים — ההצעה לא נגעה בו',
      );
    });

    testWidgets('בלי הצעה — Tab אינו נבלע ע"י הבאנר', (tester) async {
      controller.text = 'שלום';
      await tester.pumpWidget(keyboardHost());
      fieldNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      // אין באנר — הפוקוס עבר לפי סדר המעבר הרגיל (ואינו בבאנר שאינו קיים).
      expect(find.textContaining('האם התכוונת'), findsNothing);
    });

    testWidgets('ה-handler מוסר מצומת השדה כשהווידג\'ט יורד מהעץ', (
      tester,
    ) async {
      controller.text = 'akuo';
      await tester.pumpWidget(keyboardHost());
      expect(fieldNode.onKeyEvent, isNotNull);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(
        fieldNode.onKeyEvent,
        isNull,
        reason: 'dispose משחזר את ה-handler הקודם (null) — בלי דליפה',
      );
    });
  });

  testWidgets('לחיצה מחליפה את תוכן השדה, מציבה סמן בסוף וקוראת ל-onApplied', (
    tester,
  ) async {
    String? applied;
    controller.text = ',urv';
    await tester.pumpWidget(_host(controller, onApplied: (s) => applied = s));

    // עצם ההצגה לא נוגעת בשדה — ההחלפה רק בלחיצה.
    expect(controller.text, ',urv');
    expect(applied, isNull);

    await tester.tap(find.byType(InkWell));
    await tester.pump();

    expect(controller.text, 'תורה');
    expect(controller.selection.baseOffset, 'תורה'.length);
    expect(applied, 'תורה');

    // אחרי ההחלפה הטקסט עברי — ההצעה נעלמת.
    expect(find.textContaining('האם התכוונת'), findsNothing);
  });
}
