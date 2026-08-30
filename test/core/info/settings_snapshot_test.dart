import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:otzaria/core/info/settings_snapshot.dart';
import 'package:otzaria/data/data_providers/hive_data_provider.dart';
import 'package:path/path.dart' as p;

/// תיקיות ה-staging של [SettingsSnapshot] שקיימות כרגע ב-temp.
Set<String> _stagingDirs() => Directory.systemTemp
    .listSync()
    .whereType<Directory>()
    .map((dir) => p.basename(dir.path))
    .where((name) => name.startsWith('otzaria-settings-'))
    .toSet();

void main() {
  late Directory dataRoot;

  setUp(() async {
    dataRoot = await Directory.systemTemp.createTemp('otzaria-snapshot-test-');
  });

  tearDown(() async {
    try {
      await dataRoot.delete(recursive: true);
    } catch (_) {}
  });

  /// כותב תיבת הגדרות אמיתית ב-[dataRoot] וסוגר אותה. הסגירה חיונית:
  /// Hive.openBox מחזיר תיבה פתוחה קיימת לפי שם, ולכן תיבה שנשארה פתוחה
  /// הייתה מסתירה את העותק שהתצלום פותח.
  Future<void> seedBox(Map<String, dynamic> values) async {
    Hive.init(dataRoot.path);
    final box = await Hive.openBox<dynamic>(HiveCache.keyName);
    await box.putAll(values);
    await box.close();
  }

  group('SettingsSnapshot.read', () {
    test('קורא את כל הזוגות מתיבה קיימת', () async {
      await seedBox({
        'key-library-path': r'D:\אוצריא\books',
        'key-font-size': 18.5,
        'key-dark-mode': true,
        'key-app-tracked-version': '0.3.2+112',
      });

      final values = await SettingsSnapshot.read(dataRootPath: dataRoot.path);

      expect(values, isNotNull);
      expect(values!['key-library-path'], r'D:\אוצריא\books');
      expect(values['key-font-size'], 18.5);
      expect(values['key-dark-mode'], isTrue);
      expect(values['key-app-tracked-version'], '0.3.2+112');
    });

    test('אינו משנה את קובץ התיבה המקורי', () async {
      await seedBox({'key-library-path': 'x'});
      final source = File(p.join(dataRoot.path, SettingsSnapshot.boxFileName));
      final before = await source.readAsBytes();

      await SettingsSnapshot.read(dataRootPath: dataRoot.path);

      expect(await source.readAsBytes(), before);
    });

    test('אינו משאיר תיבה פתוחה בתהליך', () async {
      await seedBox({'key-library-path': 'x'});

      await SettingsSnapshot.read(dataRootPath: dataRoot.path);

      expect(Hive.isBoxOpen(HiveCache.keyName), isFalse);
    });

    test('תיבה חסרה מחזירה null', () async {
      final values = await SettingsSnapshot.read(dataRootPath: dataRoot.path);

      expect(values, isNull);
    });

    test('תיבה ריקה מחזירה מפה ריקה, לא null', () async {
      await seedBox(const {});

      final values = await SettingsSnapshot.read(dataRootPath: dataRoot.path);

      expect(values, isNotNull);
      expect(values, isEmpty);
    });

    test('תיבה פתוחה בתהליך — מסרב ואינו סוגר אותה', () async {
      // Hive.openBox מחזיר תיבה פתוחה קיימת לפי שם ומתעלם מהנתיב; בלי
      // הסירוב הקריאה כאן הייתה סוגרת את התיבה החיה של האפליקציה.
      Hive.init(dataRoot.path);
      final live = await Hive.openBox<dynamic>(HiveCache.keyName);
      await live.put('key-library-path', 'live');
      addTearDown(() async {
        if (Hive.isBoxOpen(HiveCache.keyName)) await live.close();
      });

      final values = await SettingsSnapshot.read(dataRootPath: dataRoot.path);

      expect(values, isNull);
      expect(Hive.isBoxOpen(HiveCache.keyName), isTrue);
      expect(live.get('key-library-path'), 'live');
    });

    test('קובץ תיבה פגום אינו משאיר תיקיית staging', () async {
      await File(
        p.join(dataRoot.path, SettingsSnapshot.boxFileName),
      ).writeAsBytes(List<int>.filled(64, 0xFF));

      final before = _stagingDirs();
      try {
        await SettingsSnapshot.read(dataRootPath: dataRoot.path);
      } catch (_) {
        // גם אם Hive זורק — מה שנבדק הוא הניקוי.
      }

      expect(_stagingDirs(), before);
      expect(Hive.isBoxOpen(HiveCache.keyName), isFalse);
    });
  });

  group('ReadOnlySettingsCache', () {
    test('מחזיר ערכים לפי טיפוס ומתעלם מאי-התאמה', () {
      final cache = ReadOnlySettingsCache({
        'text': 'abc',
        'number': 7,
        'flag': true,
        'fraction': 1.5,
      });

      expect(cache.getString('text'), 'abc');
      expect(cache.getInt('number'), 7);
      expect(cache.getBool('flag'), isTrue);
      expect(cache.getDouble('fraction'), 1.5);
      // טיפוס לא מתאים נופל ל-defaultValue ולא זורק.
      expect(cache.getInt('text', defaultValue: -1), -1);
      expect(cache.getString('missing'), isNull);
      expect(cache.containsKey('text'), isTrue);
      expect(cache.getKeys(), hasLength(4));
    });

    test('כתיבה היא no-op — התצלום נשאר ללא שינוי', () async {
      final cache = ReadOnlySettingsCache({'text': 'abc'});

      await cache.setString('text', 'changed');
      await cache.setInt('number', 1);
      await cache.remove('text');
      await cache.removeAll();

      expect(cache.getString('text'), 'abc');
      expect(cache.containsKey('number'), isFalse);
    });
  });
}
