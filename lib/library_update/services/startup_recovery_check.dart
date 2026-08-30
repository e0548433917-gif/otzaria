import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:seforim_library_updater/seforim_library_updater.dart';

/// בדיקת ההתאוששות מעדכון ספרייה שנקטע, בעליית התוכנה.
///
/// כשנמצא סימון עדכון ללא גיבוי (מסלול דלתא), נדרש `quick_check` שקורא את
/// **כל** קובץ ה-DB — דקה ויותר על ספרייה מלאה. תוצאת הבדיקה לסימון מסוים
/// נשמרת בהעדפות, כי יש שני מצבים שבהם הסימון שורד את הבדיקה: מחיקתו נכשלת
/// (ProgramData ללא הרשאת כתיבה למשתמש רגיל), או שה-DB נמצא פגום. בלי הזיכרון
/// הזה כל עלייה משלמת סריקה מלאה מחדש (issue #989).
class StartupRecoveryCheck {
  static const String prefKey = 'library-update-marker-check-result';

  final LibraryDbRecoveryService recovery;
  final Future<bool> Function(String dbPath) runQuickCheck;
  final String? Function(String key) readPref;
  final Future<void> Function(String key, String value) writePref;
  final void Function(String title, String message) logError;

  StartupRecoveryCheck({
    this.recovery = const LibraryDbRecoveryService(),
    Future<bool> Function(String dbPath)? runQuickCheck,
    required this.readPref,
    required this.writePref,
    required this.logError,
  }) : runQuickCheck = runQuickCheck ?? _quickCheckInIsolate;

  /// ברירת המחדל: הסריקה המלאה רצה ב-isolate כדי לא להקפיא את ה-main isolate
  /// (טיימרים, ערוץ ה-splash) למשך דקה ויותר.
  static Future<bool> _quickCheckInIsolate(String dbPath) {
    return Isolate.run(
      () => const LibraryDbRecoveryService().checkDbHealthAfterCrash(dbPath),
    );
  }

  Future<void> run(String dbPath) async {
    try {
      final result = await recovery.recoverIfNeeded(dbPath);
      switch (result.action) {
        case RecoveryAction.restored:
          debugPrint('📦 ${result.detail}');
        case RecoveryAction.blockedMissingBackup:
          await _verifyAfterInterruptedDelta(dbPath, result);
        case RecoveryAction.none:
          break;
      }
    } catch (e) {
      debugPrint('library update recovery failed: $e');
    }
  }

  Future<void> _verifyAfterInterruptedDelta(
    String dbPath,
    RecoveryResult result,
  ) async {
    final marker = File(recovery.markerPathFor(dbPath));
    final stamp = _markerStamp(marker);
    if (stamp != null) {
      final previous = readPref(prefKey);
      if (previous == 'ok|$stamp' || previous == 'corrupt|$stamp') {
        return;
      }
    }

    if (await runQuickCheck(dbPath)) {
      debugPrint('📦 ${result.detail}: ה-DB עבר quick_check; מנקה סימון');
      recovery.clearStaleArtifacts(dbPath);
      if (marker.existsSync()) {
        if (stamp != null) await writePref(prefKey, 'ok|$stamp');
        logError(
          'Library update marker cleanup failed',
          'הסימון ${marker.path} אומת אך לא ניתן למחיקה (כנראה הרשאות). '
              'האימות נשמר בהעדפות כדי שהעליות הבאות לא יסרקו את כל ה-DB מחדש.',
        );
      }
    } else {
      debugPrint('   ⚠️ ה-DB פגום/לא קריא — נדרשת הורדה מלאה; משאיר סימון');
      if (stamp != null) await writePref(prefKey, 'corrupt|$stamp');
      logError(
        'Library DB failed quick_check after interrupted update',
        'עדכון ספרייה שנקטע הותיר DB שנכשל ב-quick_check — נדרשת הורדה מלאה. '
            'התוצאה נשמרה כדי שהעליות הבאות לא יסרקו את כל ה-DB מחדש.',
      );
    }
  }

  String? _markerStamp(File marker) {
    try {
      return marker.existsSync() ? marker.readAsStringSync() : null;
    } catch (_) {
      return null;
    }
  }
}
