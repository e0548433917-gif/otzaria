import 'package:flutter_test/flutter_test.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:otzaria/plugins/models/plugin_manifest.dart';
import 'package:otzaria/plugins/services/plugin_manifest_validator.dart';
import 'package:otzaria/plugins/utils/fluent_icon_resolver.dart';
import 'package:otzaria/plugins/utils/plugin_icon_resolver.dart';
import 'package:otzaria_icons/otzaria_icons.dart';

/// שמות שקיימים בשתי הספריות — עליהם מוכרעת קדימות אוצריא.
Iterable<String> get _sharedNames =>
    OtzariaIcons.allIcons.keys.where((n) => fluentIconFromName(n) != null);

Future<void> _validateIconName(String iconName) =>
    PluginManifestValidator.validateManifest(
      manifest: PluginManifest.fromJson({
        'id': 'test.icons',
        'name': 'Icons',
        'version': '1.0.0',
        'entrypoint': 'index.html',
        'contributes': {
          'toolTab': {'iconName': iconName},
        },
      }),
      directoryPath: '.',
      skipAppVersionValidation: true,
      skipFileValidation: true,
    );

void main() {
  group('pluginIconFromName — קדימות אוצריא', () {
    test('כל שם משותף נפתר לאוצריא ולא לפלואנט', () {
      final shared = _sharedNames.toList();
      expect(shared, isNotEmpty, reason: 'אין חפיפה — בדוק את הספריות');

      for (final name in shared) {
        expect(
          pluginIconFromName(name),
          OtzariaIcons.allIcons[name],
          reason: '$name חייב להיפתר לאוצריא',
        );
      }
    });

    test('book_24_regular — אוצריא, לא פלואנט', () {
      expect(
        pluginIconFromName('book_24_regular'),
        OtzariaIcons.book_24_regular,
      );
      expect(
        pluginIconFromName('book_24_regular'),
        isNot(FluentIcons.book_24_regular),
        reason: 'הפיכת סדר הקדימות חייבת להיתפס כאן',
      );
    });
  });

  group('pluginIconFromName — כיסוי מלא של שתי הספריות', () {
    test('כל שמות אוצריא נפתרים', () {
      expect(OtzariaIcons.allIcons, isNotEmpty);
      for (final entry in OtzariaIcons.allIcons.entries) {
        expect(pluginIconFromName(entry.key), entry.value, reason: entry.key);
      }
    });

    test('שם שקיים רק בפלואנט נופל לפלואנט', () {
      expect(
        pluginIconFromName('puzzle_piece_24_regular'),
        FluentIcons.puzzle_piece_24_regular,
      );
      expect(
        pluginIconFromName('settings_24_filled'),
        FluentIcons.settings_24_filled,
      );
    });

    test('שם לא מוכר ו-null מחזירים null', () {
      expect(pluginIconFromName('no_such_icon_24_regular'), isNull);
      expect(pluginIconFromName(null), isNull);
    });
  });

  group('pluginIconFromName — תחיליות מפורשות', () {
    test('$kFluentIconPrefix כופה את הצורה של פלואנט בשם משותף', () {
      expect(
        pluginIconFromName('${kFluentIconPrefix}book_24_regular'),
        FluentIcons.book_24_regular,
      );
    });

    test('$kOtzariaIconPrefix כופה את הצורה של אוצריא', () {
      expect(
        pluginIconFromName('${kOtzariaIconPrefix}book_24_regular'),
        OtzariaIcons.book_24_regular,
      );
    });

    test('תחילית מפורשת לא נופלת לספרייה השנייה', () {
      expect(
        pluginIconFromName('${kOtzariaIconPrefix}puzzle_piece_24_regular'),
        isNull,
        reason: 'puzzle_piece קיים רק בפלואנט',
      );
      expect(
        pluginIconFromName('${kFluentIconPrefix}alef_24_regular'),
        isNull,
        reason: 'alef קיים רק באוצריא',
      );
    });

    test('קלטי תחילית מנוונים מחזירים null', () {
      for (final name in [
        '',
        kOtzariaIconPrefix,
        kFluentIconPrefix,
        '$kOtzariaIconPrefix${kFluentIconPrefix}book_24_regular',
        'my_${kFluentIconPrefix}book_24_regular',
        'Fluent:book_24_regular',
        ' ${kFluentIconPrefix}book_24_regular',
        '${kFluentIconPrefix}book_24_regular ',
      ]) {
        expect(pluginIconFromName(name), isNull, reason: '"$name"');
      }
    });
  });

  group('toolTabIconNamePattern', () {
    test('שתי התחיליות של ה-resolver מקובלות בוולידציה', () {
      for (final prefix in ['', kOtzariaIconPrefix, kFluentIconPrefix]) {
        expect(
          PluginManifest.toolTabIconNamePattern.hasMatch(
            '${prefix}book_24_regular',
          ),
          isTrue,
          reason: 'תחילית "$prefix" נתמכת ב-resolver וחייבת לעבור ולידציה',
        );
      }
    });

    test('דוחה גודל אחר, וריאנט אחר ותחילית לא מוכרת', () {
      for (final name in [
        'book_20_regular',
        'calendar_24_light',
        'material:book_24_regular',
        'Book_24_Regular',
      ]) {
        expect(
          PluginManifest.toolTabIconNamePattern.hasMatch(name),
          isFalse,
          reason: name,
        );
      }
    });

    test('כל שם באוצריא עובר את התבנית', () {
      for (final name in OtzariaIcons.allIcons.keys) {
        expect(
          PluginManifest.toolTabIconNamePattern.hasMatch(name),
          isTrue,
          reason: name,
        );
      }
    });

    // ה-resolver סובלני מהוולידציה: הוא פותר גם וריאנט light שהמניפסט דוחה.
    // הפער מכוון — הוולידציה שומרת על עקביות הטאבים, לא על יכולת הפתירה.
    test('פער מכוון: light נפתר ב-resolver ונדחה בוולידציה', () {
      expect(pluginIconFromName('document_24_light'), isNotNull);
      expect(
        PluginManifest.toolTabIconNamePattern.hasMatch('document_24_light'),
        isFalse,
      );
    });
  });

  group('PluginManifestValidator — iconName', () {
    test('מקבל שם עם תחילית מפורשת', () async {
      for (final prefix in ['', kOtzariaIconPrefix, kFluentIconPrefix]) {
        await expectLater(
          _validateIconName('${prefix}book_24_regular'),
          completes,
          reason: 'תחילית "$prefix"',
        );
      }
    });

    test('דוחה שם לא תקין ומסביר את שתי הספריות', () async {
      await expectLater(
        _validateIconName('calendar_24_light'),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            allOf(contains('FluentUI'), contains('אוצריא')),
          ),
        ),
      );
    });
  });
}
