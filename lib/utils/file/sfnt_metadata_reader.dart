import 'dart:typed_data';

import 'sfnt_metadata_reader_stub.dart'
    if (dart.library.io) 'sfnt_metadata_reader_io.dart'
    as impl;

/// קורא מקובץ גופן רק את הטבלאות שנדרשות לזיהוי (cmap/OS-2/head/name/fvar),
/// ומדלג על טבלאות הגליפים — שהן כמעט כל נפח הקובץ.
class SfntMetadataReader {
  SfntMetadataReader._();

  /// מחזיר קובץ SFNT קומפקטי עם טבלאות הזיהוי בלבד והיסטים שנכתבו מחדש.
  /// מחזיר `null` כשהקובץ אינו קריא או פגום.
  static Uint8List? readSync(String path) => impl.readMetadataSync(path);
}
