import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/search/view/layout_fix_suggestion_banner.dart';
import 'package:otzaria/settings/l10n/settings_l10n_exports.dart';

Widget _host(
  String query,
  ValueChanged<String> onAccept, {
  SettingsLanguage language = SettingsLanguage.hebrew,
}) {
  return MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: SettingsTextScope(
        language: language,
        child: Scaffold(
          body: LayoutFixSuggestionBanner(query: query, onAccept: onAccept),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('שאילתה עברית רגילה — אין באנר', (tester) async {
    await tester.pumpWidget(_host('שלום עולם', (_) {}));
    expect(find.byType(InkWell), findsNothing);
    expect(find.textContaining('האם התכוונת'), findsNothing);
  });

  testWidgets('שאילתה במיפוי מקלדת אנגלי — הבאנר מוצג עם ההצעה', (
    tester,
  ) async {
    await tester.pumpWidget(_host('akuo', (_) {}));
    expect(find.textContaining('האם התכוונת'), findsOneWidget);
    expect(find.textContaining('שלום'), findsOneWidget);
  });

  testWidgets('לחיצה על הבאנר מוסרת את הטקסט המומר — ורק אז', (tester) async {
    String? accepted;
    await tester.pumpWidget(_host(',urv', (s) => accepted = s));

    // עצם ההצגה אינה מפעילה כלום — ההחלפה רק ביוזמת המשתמש.
    await tester.pump();
    expect(accepted, isNull);

    await tester.tap(find.byType(InkWell));
    expect(accepted, 'תורה');
  });

  testWidgets('שאילתה אנגלית שאינה ממופה לעברית (qw) — אין באנר', (
    tester,
  ) async {
    await tester.pumpWidget(_host('qw', (_) {}));
    expect(find.textContaining('האם התכוונת'), findsNothing);
  });

  testWidgets('בממשק אנגלי אין הצעת תיקון', (tester) async {
    await tester.pumpWidget(
      _host('akuo', (_) {}, language: SettingsLanguage.english),
    );
    expect(find.textContaining('האם התכוונת'), findsNothing);
  });
}
