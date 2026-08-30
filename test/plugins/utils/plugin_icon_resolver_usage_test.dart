import 'dart:io';

import 'package:test/test.dart';

/// בדיקה סטטית: כל מסלול שפותר שם אייקון שהגיע מתוסף חייב לעבור דרך
/// `pluginIconFromName`. פנייה ישירה לאחת משתי הספריות מדלגת על סדר
/// הקדימות ועל התחיליות, ואז אותו שם מוצג אחרת בשני מסכים.
const _resolverPath = 'lib/plugins/utils/plugin_icon_resolver.dart';
const _generatedFluentMap = 'lib/plugins/utils/fluent_icon_resolver.dart';

/// שתי הכניסות הישירות לספריות. `\b` תופס גם tear-off וגם קריאה שנשברה
/// לשורה הבאה — לא רק `name(`.
final _directEntryPoints = {
  r'\bfluentIconFromName\b': 'fluentIconFromName',
  r'\bOtzariaIcons\.allIcons\b': 'OtzariaIcons.allIcons',
};

void main() {
  final sources = <String, String>{
    for (final entity in Directory('lib').listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart'))
        entity.path
            .replaceAll('\\', '/')
            .replaceFirst(
              RegExp(r'^.*?/?lib/'),
              'lib/',
            ): _stripComments(
          entity.readAsStringSync(),
        ),
  };

  test('רק ה-resolver של התוספים פונה ישירות לספריות האייקונים', () {
    expect(
      sources.keys,
      contains(_resolverPath),
      reason: 'ה-resolver לא נמצא — עדכן את הנתיב בבדיקה',
    );

    final violations = <String>[];
    for (final entry in sources.entries) {
      if (entry.key == _resolverPath) continue;
      if (entry.key == _generatedFluentMap) continue;

      for (final pattern in _directEntryPoints.entries) {
        for (final match in RegExp(pattern.key).allMatches(entry.value)) {
          final line =
              '\n'.allMatches(entry.value.substring(0, match.start)).length + 1;
          violations.add('  ${entry.key}:$line → ${pattern.value}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'פנייה ישירה לספריית אייקונים:\n${violations.join('\n')}\n\n'
          'החלף ב-pluginIconFromName מ-$_resolverPath.',
    );
  });

  // בלי הטענה הזו הבדיקה שלמעלה עוברת לנצח גם אם ה-resolver התרוקן.
  test('ה-resolver עצמו פונה לשתי הספריות', () {
    final resolver = sources[_resolverPath]!;
    for (final name in _directEntryPoints.values) {
      expect(resolver, contains(name), reason: '$name חסר ב-resolver');
    }
  });

  test('מסלולי התוספים אכן קוראים ל-pluginIconFromName', () {
    final callers = sources.entries
        .where((e) => e.key != _resolverPath)
        .where((e) => e.value.contains('pluginIconFromName('))
        .length;
    expect(
      callers,
      greaterThan(5),
      reason: 'מסלולי התוספים נותקו מה-resolver',
    );
  });
}

/// מסיר הערות שורה ומחרוזות, כדי שאזכור של שם פונקציה בתיעוד לא ייחשב
/// לקריאה. גס בכוונה — עודף הסרה גורם לפספוס, לא לדיווח שווא.
String _stripComments(String source) => source
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    .replaceAll(RegExp(r'//[^\n]*'), '')
    .replaceAll(RegExp(r"'[^'\n]*'"), "''")
    .replaceAll(RegExp(r'"[^"\n]*"'), '""');
