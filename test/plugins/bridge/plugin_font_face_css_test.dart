import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:otzaria/plugins/bridge/plugin_bridge_adapter.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';
import 'package:otzaria/theme/app_fonts.dart';
import 'package:otzaria/theme/app_theme_data.dart';
import 'package:flutter/material.dart';

import '../../test_helpers/memory_cache_provider.dart';

/// ה-`@font-face` שאוצריא מזריקה ל-WebView של תוסף. משפחה חסרה, face בולד
/// חסר או טווח משקלים חסר — כולם מתבטאים אצל המשתמש כגופן שגוי או מרוח.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Settings.init(cacheProvider: MemoryCacheProvider());
  });

  group('buildPluginFontFaceCss', () {
    test('כל הגופנים המובנים נשלחים, לא רק שני הנבחרים בהגדרות', () async {
      final css = await buildPluginFontFaceCss();
      for (final family in AppFonts.fontPaths.keys) {
        expect(
          css,
          contains("font-family:'$family'"),
          reason: 'התוסף יכול לנקוב ב-$family, ובלי face הוא ייפול ל-fallback',
        );
      }
    });

    test('גופן עם קובץ בולד נפרד מקבל גם face של 700', () async {
      final css = await buildPluginFontFaceCss();
      final rules = css
          .split('\n')
          .where((r) => r.contains("font-family:'FrankRuhlCLM'"))
          .toList();
      expect(rules.length, 2);
      expect(rules.where((r) => r.contains('font-weight:400')), hasLength(1));
      expect(rules.where((r) => r.contains('font-weight:700')), hasLength(1));
    });

    test('גופן משתנה מקבל טווח משקלים ולא משקל בודד', () async {
      final css = await buildPluginFontFaceCss();
      for (final family in AppFonts.variableWeightFonts) {
        if (!AppFonts.fontPaths.containsKey(family)) continue;
        final rule = css
            .split('\n')
            .firstWhere((r) => r.contains("font-family:'$family'"));
        expect(rule, contains('font-weight:100 900'));
      }
    });

    test('גופן שאינו משתנה ואין לו קובץ בולד מקבל face יחיד', () async {
      final css = await buildPluginFontFaceCss();
      final rules = css
          .split('\n')
          .where((r) => r.contains("font-family:'Shofar'"))
          .toList();
      expect(rules, hasLength(1));
      expect(rules.single, contains('font-weight:400'));
    });
  });

  group('typography ב-theme payload', () {
    test('ברירת המחדל היא משפחה שנשלחת בפועל כ-@font-face', () async {
      final css = await buildPluginFontFaceCss();
      final typography = _typography();
      expect(css, contains("font-family:'${typography['fontFamily']}'"));
      expect(
        css,
        contains("font-family:'${typography['commentatorsFontFamily']}'"),
      );
    });

    test('גופן הממשק נפרד מגופן הקריאה ונשלח כ-@font-face', () async {
      // בלי שדה נפרד, כותב תוסף מחיל את גופן הקריאה על כפתורים בני 12px,
      // וגופן ספרים בגודל כזה נמרח.
      final typography = _typography();
      expect(typography['uiFontFamily'], isNot(typography['fontFamily']));
      expect(
        await buildPluginFontFaceCss(),
        contains("font-family:'${typography['uiFontFamily']}'"),
      );
    });

    test('גופן שנבחר בהגדרות הוא זה שמגיע ב-payload', () async {
      await Settings.setValue<String>(
        SettingsRepository.keyFontFamily,
        'TaameyDavidCLM',
      );
      addTearDown(
        () => Settings.setValue<String>(
          SettingsRepository.keyFontFamily,
          AppFonts.defaultFont,
        ),
      );
      final typography = _typography();
      expect(typography['fontFamily'], 'TaameyDavidCLM');
    });
  });
}

Map<String, dynamic> _typography() =>
    buildThemePayloadFromScheme(
          AppThemeData.createColorScheme(Colors.blue, Brightness.light),
          isDark: false,
        )['typography']
        as Map<String, dynamic>;
