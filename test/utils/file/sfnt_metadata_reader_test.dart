import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otzaria/theme/app_fonts.dart';
import 'package:otzaria/utils/file/sfnt_metadata_reader.dart';

/// כל הגופנים המובנים ב-repo — קורפוס אמיתי (סטטיים, משתנים, עם/בלי OS/2).
List<File> _bundledFontFiles() =>
    Directory('fonts')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.toLowerCase().endsWith('.ttf'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

void main() {
  test('יש קורפוס גופנים לבדוק מולו', () {
    expect(_bundledFontFiles(), isNotEmpty);
  });

  group('קריאת מטא-דאטה חלקית שקולה לקריאת הקובץ המלא', () {
    for (final file in _bundledFontFiles()) {
      final name = file.uri.pathSegments.last;

      test(name, () {
        final full = Uint8List.fromList(file.readAsBytesSync());
        final partial = SfntMetadataReader.readSync(file.path);

        expect(partial, isNotNull, reason: 'הקריאה החלקית החזירה null');

        // הזיהוי — כל מה שהסורק נשען עליו — חייב לצאת זהה.
        expect(
          AppFonts.debugSfntSupportsHebrew(partial!),
          AppFonts.debugSfntSupportsHebrew(full),
        );
        expect(
          AppFonts.debugSfntCategory(partial),
          AppFonts.debugSfntCategory(full),
        );
        expect(
          AppFonts.debugFontFamilyName(partial),
          AppFonts.debugFontFamilyName(full),
        );
        expect(
          AppFonts.debugFontWeightClass(partial),
          AppFonts.debugFontWeightClass(full),
        );
        expect(
          AppFonts.debugFontIsBoldStyle(partial),
          AppFonts.debugFontIsBoldStyle(full),
        );
        expect(
          AppFonts.debugFontIsItalic(partial),
          AppFonts.debugFontIsItalic(full),
        );
        expect(
          AppFonts.debugFontHasWeightAxis(partial),
          AppFonts.debugFontHasWeightAxis(full),
        );
      });
    }
  });

  test('buffer המטא-דאטה אינו בגודל הקבצים השלמים', () {
    var fullBytes = 0;
    var metadataBytes = 0;
    for (final file in _bundledFontFiles()) {
      final partial = SfntMetadataReader.readSync(file.path);
      if (partial == null) continue;
      fullBytes += file.lengthSync();
      metadataBytes += partial.length;
    }
    expect(fullBytes, greaterThan(0));
    expect(metadataBytes, lessThan(fullBytes ~/ 2));
  });

  group('קלט פגום — כשל שקט, בלי חריגה', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('sfnt_meta'));
    tearDown(() => tmp.deleteSync(recursive: true));

    File write(String name, List<int> bytes) =>
        File('${tmp.path}/$name')..writeAsBytesSync(bytes);

    test('קובץ שאינו קיים → null', () {
      expect(SfntMetadataReader.readSync('${tmp.path}/nope.ttf'), isNull);
    });

    test('קובץ ריק → null', () {
      expect(SfntMetadataReader.readSync(write('empty.ttf', []).path), isNull);
    });

    test('קצר מכותרת SFNT → null', () {
      final f = write('short.ttf', List<int>.filled(8, 0));
      expect(SfntMetadataReader.readSync(f.path), isNull);
    });

    test('numTables מופרך → null (אין טווח לקרוא)', () {
      final d = ByteData(12)
        ..setUint32(0, 0x00010000)
        ..setUint16(4, 0);
      final f = write('notables.ttf', d.buffer.asUint8List());
      expect(SfntMetadataReader.readSync(f.path), isNull);
    });

    test('טבלה שהיסטה מחוץ לקובץ → הזיהוי נכשל בשקט', () {
      final d = ByteData(12 + 16)
        ..setUint32(0, 0x00010000)
        ..setUint16(4, 1)
        ..setUint8(12, 0x63) // 'c'
        ..setUint8(13, 0x6D) // 'm'
        ..setUint8(14, 0x61) // 'a'
        ..setUint8(15, 0x70) // 'p'
        ..setUint32(20, 0x7FFFFF00) // offset מעבר לסוף הקובץ
        ..setUint32(24, 100);
      final f = write('badoffset.ttf', d.buffer.asUint8List());
      final partial = SfntMetadataReader.readSync(f.path);
      expect(partial, isNotNull);
      expect(AppFonts.debugSfntSupportsHebrew(partial!), isFalse);
    });

    test('טבלה רחוקה נארזת בלי להקצות את המרווח שלפניה', () {
      final d = ByteData(1050)
        ..setUint32(0, 0x00010000)
        ..setUint16(4, 1)
        ..setUint8(12, 0x6E) // 'n'
        ..setUint8(13, 0x61) // 'a'
        ..setUint8(14, 0x6D) // 'm'
        ..setUint8(15, 0x65) // 'e'
        ..setUint32(20, 1024)
        ..setUint32(24, 26);
      final f = write('far-name.ttf', d.buffer.asUint8List());

      final metadata = SfntMetadataReader.readSync(f.path);

      expect(metadata, isNotNull);
      expect(metadata!.length, lessThan(100));
    });

    test('TTC קומפקטי משכתב היסטים לכותרת ול-directory', () {
      final d = ByteData(126)
        ..setUint8(0, 0x74) // 't'
        ..setUint8(1, 0x74) // 't'
        ..setUint8(2, 0x63) // 'c'
        ..setUint8(3, 0x66) // 'f'
        ..setUint32(4, 0x00010000)
        ..setUint32(8, 1)
        ..setUint32(12, 32)
        ..setUint32(32, 0x00010000)
        ..setUint16(36, 1)
        ..setUint8(44, 0x6E) // 'n'
        ..setUint8(45, 0x61) // 'a'
        ..setUint8(46, 0x6D) // 'm'
        ..setUint8(47, 0x65) // 'e'
        ..setUint32(52, 100)
        ..setUint32(56, 26);
      final f = write('compact.ttc', d.buffer.asUint8List());

      final metadata = SfntMetadataReader.readSync(f.path);

      expect(metadata, isNotNull);
      final view = ByteData.sublistView(metadata!);
      expect(metadata.length, 70);
      expect(view.getUint32(12), 16);
      expect(view.getUint32(36), 44);
    });
  });
}
