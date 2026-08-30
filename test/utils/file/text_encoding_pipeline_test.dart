// הצנרת מקצה לקצה (§69, §70): קובץ טקסט בקידוד לא-מוכר עובר את אותו זיהוי
// בשלושת מסלולי הכניסה — פתיחת ספר, בניית בסיס הנתונים, ותוכן העניינים.
//
// הרגרסיה שהבדיקה מונעת: המסלולים האלה קראו את הקובץ ב-`readAsString` וכשלו
// (או נפלו ל-Latin-1) על ספר שנשמר ב-ANSI עברית, ואז נכנס לבסיס הנתונים
// ולאינדקס ג'יבריש שנראה כספר תקין.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/migration/generator/generator.dart';
import 'package:otzaria/utils/file/document_conversion_exceptions.dart';
import 'package:otzaria/utils/file/document_converter.dart';
import 'package:otzaria/utils/file/document_format.dart';
import 'package:otzaria/utils/file/text_encoding.dart';
import 'package:otzaria/utils/file/toc_parser.dart';
import 'package:path/path.dart' as p;

import '../../../tool/generate_text_encoding_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('encoding-pipeline-');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      try {
        await tempDir.delete(recursive: true);
      } on FileSystemException {
        // תיקיית temp שנשארה תפוסה אינה כשל של המוצר.
      }
    }
  });

  File write(String name, Uint8List bytes) =>
      File(p.join(tempDir.path, name))..writeAsBytesSync(bytes);

  /// אותו ספר קצר, בכל הקידודים שהצנרת אמורה לעכל.
  const book =
      '<h1>מסכת ברכות</h1>\n'
      'מאימתי קורין את שמע בערבית, משעה שהכהנים נכנסים לאכול בתרומתן.\n'
      'עד סוף האשמורה הראשונה, דברי רבי אליעזר.\n';

  Map<String, Uint8List> encodedVariants() => {
    'utf8.txt': Uint8List.fromList(utf8.encode(book)),
    'utf8_bom.txt': Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(book),
    ]),
    'utf16le.txt': encodeUtf16(book, littleEndian: true, bom: true),
    'utf16be_no_bom.txt': encodeUtf16(book, littleEndian: false),
    'windows1255.txt': encodeLegacy(book, TextEncoding.windows1255),
    'cp862.txt': encodeLegacy(book, TextEncoding.cp862),
  };

  group('מסלול בניית בסיס הנתונים והאינדוקס', () {
    test('readBookLines מחזירה את השורות הנכונות בכל קידוד', () async {
      for (final entry in encodedVariants().entries) {
        final file = write(entry.key, entry.value);
        final lines = await DatabaseGenerator.readBookLines(file.path);
        expect(
          lines.first,
          '<h1>מסכת ברכות</h1>',
          reason: '${entry.key}: הכותרת לא פוענחה',
        );
        expect(lines.length, 4, reason: '${entry.key}: מספר שורות שונה');
        expect(
          lines.join('\n'),
          book,
          reason: '${entry.key}: התוכן שונה מהמקור',
        );
      }
    });
  });

  group('מסלול פתיחת הספר', () {
    test('convertDocumentWithCache מחזירה את הטקסט בכל קידוד', () async {
      for (final entry in encodedVariants().entries) {
        final file = write(entry.key, entry.value);
        final text = await convertDocumentWithCache(
          file,
          'מסכת ברכות',
          DocumentFormat.txt,
        );
        expect(text, book, reason: '${entry.key}: הטקסט שונה מהמקור');
      }
    });

    test('סיומת text משתמשת באותו מסלול פענוח כמו txt', () async {
      final file = write('legacy.text', encodedVariants()['windows1255.txt']!);
      final text = await convertDocumentWithCache(
        file,
        'מסכת ברכות',
        DocumentFormat.text,
      );
      expect(text, book);
      expect(documentFormatFromExtension(file.path), DocumentFormat.text);
      expect(DocumentFormat.text.isPlainText, isTrue);
    });

    test('readFileBackedBookText מפענח Windows-1255 גם עבור text', () async {
      final file = write(
        'legacy-read.text',
        encodedVariants()['windows1255.txt']!,
      );
      final text = await readFileBackedBookText(
        file,
        'text',
        'מסכת ברכות',
      );
      expect(text, book);
    });

    test('readFileBackedBookText על ספר ANSI עברית', () async {
      final file = write(
        'ansi_book.txt',
        encodeLegacy(book, TextEncoding.windows1255),
      );
      final text = await readFileBackedBookText(file, 'txt', 'מסכת ברכות');
      expect(text, book);
    });

    test('convertDocumentBytesSync על בייטים בקידוד ישן', () {
      final text = convertDocumentBytesSync(
        encodeLegacy(book, TextEncoding.cp862),
        'מסכת ברכות',
        format: DocumentFormat.txt,
      );
      expect(text, book);
    });

    test('תוכן העניינים נבנה מספר בקידוד ישן', () {
      // המסלול של `database_library_provider`: בייטים → המרה → TOC, בתוך
      // isolate. כותרת שנפענחה כג'יבריש הייתה נכנסת כך לתוכן העניינים.
      for (final encoding in [
        TextEncoding.windows1255,
        TextEncoding.cp862,
      ]) {
        final content = convertDocumentBytesSync(
          encodeLegacy(book, encoding),
          'מסכת ברכות',
          format: DocumentFormat.txt,
        );
        final toc = TocParser.parseEntriesFromContent(content);
        expect(toc.single.text, 'מסכת ברכות', reason: encoding.label);
      }
    });
  });

  group('דיווח על זיהוי לא-ודאי', () {
    test('קובץ שהזיהוי בו לא ודאי נרשם ללוג בפתיחה (§66)', () async {
      // בלי הרישום, "הספר נראה ג'יבריש" הוא דיווח שאין דרך לאבחן: אף שכבה
      // אחרת אינה מבחינה בין פענוח ודאי לניחוש.
      final file = write(
        'לא ודאי.txt',
        Uint8List.fromList([
          for (var i = 0; i < 6; i++) ...[
            0xD9,
            0xDA,
            0xDB,
            0xDC,
            0xDD,
            0xDE,
            0xFB,
            0xFC,
          ],
        ]),
      );
      final original = debugPrint;
      final logged = <String>[];
      debugPrint = (message, {wrapWidth}) => logged.add(message ?? '');
      addTearDown(() => debugPrint = original);

      await convertDocumentWithCache(file, 'לא ודאי', DocumentFormat.txt);

      expect(logged, isNotEmpty);
      expect(logged.join('\n'), contains('בוודאות נמוכה'));
    });

    test('קובץ בקידוד מזוהה אינו מייצר רעש בלוג', () async {
      final file = write(
        'ברור.txt',
        encodeLegacy(book, TextEncoding.windows1255),
      );
      final original = debugPrint;
      final logged = <String>[];
      debugPrint = (message, {wrapWidth}) => logged.add(message ?? '');
      addTearDown(() => debugPrint = original);

      await convertDocumentWithCache(file, 'ברור', DocumentFormat.txt);

      expect(logged.join('\n'), isNot(contains('בוודאות נמוכה')));
    });
  });

  group('גבולות שנשמרו', () {
    test('מכולה בינארית עם סיומת txt עדיין נדחית', () async {
      final zip = ZipEncoder().encode(
        Archive()..addFile(ArchiveFile('a.txt', 3, [1, 2, 3])),
      );
      final file = write('disguised.txt', Uint8List.fromList(zip));
      await expectLater(
        convertDocumentWithCache(file, 'x', DocumentFormat.txt),
        throwsA(isA<UnsupportedDocumentFormatException>()),
      );
    });

    test('קובץ ריק אינו כשל', () async {
      final file = write('empty.txt', Uint8List(0));
      expect(await DatabaseGenerator.readBookLines(file.path), ['']);
      expect(
        await convertDocumentWithCache(file, 'x', DocumentFormat.txt),
        '',
      );
    });

    test('קובץ text ריק אינו כשל', () async {
      final file = write('empty.text', Uint8List(0));
      expect(await readFileBackedBookText(file, 'text', 'ריק'), isEmpty);
      expect(
        await convertDocumentWithCache(file, 'ריק', DocumentFormat.text),
        '',
      );
    });
  });
}
