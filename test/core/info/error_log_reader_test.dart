import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/core/info/error_log_reader.dart';

void main() {
  group('ErrorLogReader.parseBlockLog', () {
    test('מפענח בלוק שגיאה עם גרסה, חריגה ו-stack', () {
      const content = '''
=== Flutter error 2026-08-20T10:15:30.000 ===
Version: 0.3.2+12
Exception: RangeError (index): Invalid value
Library: widgets library

Stack:
#0      _TextBookState.build
#1      StatefulElement.build
#2      ComponentElement.performRebuild
#3      Element.rebuild
''';

      final entries = ErrorLogReader.parseBlockLog(
        content,
        source: 'errors.txt',
      );

      expect(entries, hasLength(1));
      final entry = entries.single;
      expect(entry.source, 'errors.txt');
      expect(entry.title, 'Flutter error');
      expect(entry.timestamp, DateTime.parse('2026-08-20T10:15:30.000'));
      expect(entry.version, '0.3.2+12');
      expect(entry.message, 'RangeError (index): Invalid value');
      // רק ראש ה-stack נשמר — שלושה פריימים.
      expect(entry.stackHead, contains('#0      _TextBookState.build'));
      expect(
        entry.stackHead,
        contains('#2      ComponentElement.performRebuild'),
      );
      expect(entry.stackHead, isNot(contains('#3')));
    });

    test('מפענח כמה בלוקים עוקבים', () {
      const content = '''
=== First 2026-08-01T08:00:00.000 ===
Version: 1.0.0
Exception: boom

=== Second 2026-08-02T09:30:00.000 ===
Version: 1.0.1
Exception: crash
''';

      final entries = ErrorLogReader.parseBlockLog(content, source: 'log');

      expect(entries.map((e) => e.title), ['First', 'Second']);
      expect(entries.map((e) => e.message), ['boom', 'crash']);
    });

    test('דוח כשלי אינדוקס ללא Exception מדווח את שורת הכשלים', () {
      const content = '''
=== Indexing failures 2026-08-03T12:00:00.000 ===
Version: 1.0.0
Completed: false
Processed: 10/40
Indexed: 8
Failures: 2
''';

      final entries = ErrorLogReader.parseBlockLog(content, source: 'log');

      expect(entries.single.title, 'Indexing failures');
      expect(entries.single.message, 'Failures: 2');
    });

    test('ה-stack אינו בולע את בלוק הכשל הבא בדוח אינדוקס', () {
      const content = '''
=== Indexing failures 2026-08-03T12:00:00.000 ===
Version: 1.0.0
Failures: 2

--- Failure 1 ---
Kind: parse
Error: boom
Stack:
#0      only-one-frame

--- Failure 2 ---
Kind: io
Error: crash
''';

      final entries = ErrorLogReader.parseBlockLog(content, source: 'log');

      expect(entries.single.stackHead, '#0      only-one-frame');
    });

    test('כותרת בלי חותמת זמן תקינה משאירה timestamp ריק', () {
      const content = '=== Broken not-a-date ===\nException: boom\n';

      final entries = ErrorLogReader.parseBlockLog(content, source: 'log');

      expect(entries.single.title, 'Broken');
      expect(entries.single.timestamp, isNull);
    });

    test('קובץ ריק או ללא כותרות אינו מייצר רשומות', () {
      expect(ErrorLogReader.parseBlockLog('', source: 'log'), isEmpty);
      expect(
        ErrorLogReader.parseBlockLog('סתם טקסט\nעוד שורה', source: 'log'),
        isEmpty,
      );
    });
  });

  group('ErrorLogReader.parseLineLog', () {
    test('מפענח שורות של לוג הסגירה הכפויה', () {
      const content = '''
2026-08-20T10:00:00.000 | job object creation failed
2026-08-20T11:00:00.000 | channel invoke failed
  #0 some frame
''';

      final entries = ErrorLogReader.parseLineLog(content, source: 'shutdown');

      expect(entries, hasLength(2));
      expect(entries.first.title, 'סגירה כפויה');
      expect(entries.first.message, 'job object creation failed');
      expect(entries.last.timestamp, DateTime.parse('2026-08-20T11:00:00.000'));
    });

    test('שורות בלי חותמת זמן תקינה מדולגות', () {
      const content = 'not-a-date | reason\nגם לא שורה תקינה\n';

      expect(ErrorLogReader.parseLineLog(content, source: 'x'), isEmpty);
    });
  });

  group('ErrorLogReader.sortNewestFirst', () {
    test('ממיין מהחדש לישן ודוחק רשומות בלי זמן לסוף', () {
      final entries = [
        ErrorLogEntry(
          source: 'a',
          title: 'ישן',
          timestamp: DateTime.parse('2026-01-01T00:00:00.000'),
        ),
        const ErrorLogEntry(source: 'a', title: 'ללא זמן'),
        ErrorLogEntry(
          source: 'a',
          title: 'חדש',
          timestamp: DateTime.parse('2026-05-01T00:00:00.000'),
        ),
      ];

      final sorted = ErrorLogReader.sortNewestFirst(entries);

      expect(sorted.map((e) => e.title), ['חדש', 'ישן', 'ללא זמן']);
    });
  });

  group('ErrorLogEntry.toJson', () {
    test('משמיט שדות ריקים', () {
      const entry = ErrorLogEntry(source: 'errors.txt', title: 'רק כותרת');

      expect(entry.toJson(), {'source': 'errors.txt', 'title': 'רק כותרת'});
    });

    test('חותמת הזמן היא UTC עם סיומת Z', () {
      final entry = ErrorLogEntry(
        source: 'errors.txt',
        title: 'כותרת',
        timestamp: DateTime.parse('2026-08-17T08:51:29.000'),
      );

      final value = entry.toJson()['timestamp'] as String;
      expect(value, endsWith('Z'));
      expect(
        DateTime.parse(value),
        DateTime.parse('2026-08-17T08:51:29.000').toUtc(),
      );
    });
  });

  group('ErrorLogFileSummary.toJson', () {
    test('קובץ חסר מדווח רק path ו-exists', () {
      const summary = ErrorLogFileSummary(path: 'x.txt', exists: false);

      expect(summary.toJson(), {'path': 'x.txt', 'exists': false});
    });

    test('כשל קריאה מדווח readError ולא נבלע', () {
      final summary = ErrorLogFileSummary(
        path: 'x.txt',
        exists: true,
        sizeBytes: 12,
        modifiedAt: DateTime.parse('2026-08-17T08:51:29.000'),
        readError: 'FormatException: bad utf8',
      );

      final json = summary.toJson();
      expect(json['readError'], 'FormatException: bad utf8');
      expect(json['entryCount'], 0);
      expect(json['modifiedAt'], endsWith('Z'));
    });
  });
}
