import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/plugins/utils/fluent_icon_resolver.dart';
import 'package:otzaria_icons/otzaria_icons.dart';

/// docs/plugin-sdk/ICONS.md הוא הרשימה שמחברי תוספים עובדים לפיה, והיא
/// מתיישנת בשקט בכל עדכון של otzaria_icons (pubspec.lock אינו במעקב).
void main() {
  const path = 'docs/plugin-sdk/ICONS.md';
  late String doc;
  late Iterable<RegExpMatch> rows;
  late Set<String> shared;

  setUpAll(() {
    final file = File(path);
    expect(
      file.existsSync(),
      isTrue,
      reason: '$path חסר — אם הוזז, עדכן את הנתיב בבדיקה',
    );
    doc = file.readAsStringSync();
    rows = RegExp(
      r'^\| `([a-z0-9_]+)` \|(.*)\|$',
      multiLine: true,
    ).allMatches(doc);
    shared = OtzariaIcons.allIcons.keys
        .where((n) => fluentIconFromName(n) != null)
        .toSet();
  });

  group('ICONS.md מסונכרן עם ספריית האייקונים', () {
    test('הטבלה מכילה בדיוק את אייקוני אוצריא', () {
      expect(
        rows,
        isNotEmpty,
        reason: 'לא נמצאה אף שורת טבלה — כנראה שעיצוב הטבלה השתנה',
      );
      expect(
        rows.map((m) => m.group(1)!).toSet(),
        OtzariaIcons.allIcons.keys.toSet(),
        reason: 'עדכן את הטבלה ב-$path',
      );
    });

    test('סימון "גם בפלואנט" תואם לחפיפה בפועל', () {
      for (final row in rows) {
        final name = row.group(1)!;
        expect(
          row.group(2)!.contains('✔'),
          shared.contains(name),
          reason: name,
        );
      }
    });

    test('המספרים בפרוזה תואמים לספריות', () {
      expect(
        doc,
        contains('${OtzariaIcons.allIcons.length} אייקונים'),
        reason: 'מספר האייקונים בפתיחת $path התיישן',
      );
      expect(
        doc,
        contains('${shared.length} מתוך ${OtzariaIcons.allIcons.length}'),
        reason: 'מספר השמות המשותפים ב-$path התיישן',
      );
    });
  });
}
