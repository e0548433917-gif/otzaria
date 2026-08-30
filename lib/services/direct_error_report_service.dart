import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_settings_screens/flutter_settings_screens.dart';
import 'package:http/http.dart' as http;
import 'package:otzaria/core/messages/report_messages.dart';
import 'package:otzaria/data/repository/hive_list_repository.dart';
import 'package:otzaria/models/direct_error_report.dart';
import 'package:otzaria/services/offline_report_script_builder.dart';
import 'package:otzaria/settings/engine/settings_repository.dart';

export 'package:otzaria/services/offline_report_script_builder.dart'
    show OfflineSendScript, OfflineSendScriptTarget;

enum DirectReportDeliveryStatus {
  sent,
  queued,
  failed,
}

class DirectReportDeliveryResult {
  final DirectReportDeliveryStatus status;
  final String message;

  /// השרת קלט את הדיווח אך לא שלח מייל, כי תוכן זהה כבר נשלח בעבר.
  final bool isDuplicate;

  const DirectReportDeliveryResult._({
    required this.status,
    required this.message,
    this.isDuplicate = false,
  });

  factory DirectReportDeliveryResult.sent(
    String message, {
    bool isDuplicate = false,
  }) {
    return DirectReportDeliveryResult._(
      status: DirectReportDeliveryStatus.sent,
      message: message,
      isDuplicate: isDuplicate,
    );
  }

  factory DirectReportDeliveryResult.queued(String message) {
    return DirectReportDeliveryResult._(
      status: DirectReportDeliveryStatus.queued,
      message: message,
    );
  }

  factory DirectReportDeliveryResult.failed(String message) {
    return DirectReportDeliveryResult._(
      status: DirectReportDeliveryStatus.failed,
      message: message,
    );
  }

  bool get isSent => status == DirectReportDeliveryStatus.sent;

  bool get isQueued => status == DirectReportDeliveryStatus.queued;
}

class DirectErrorReportService {
  static const String _endpoint = 'https://otzaria.org/api/reportingerrors';
  static const String queueBoxName = 'error_reports_queue';
  static const String pendingReportsKey = 'pending_reports';
  static const String sentReportsKey = 'sent_reports';
  static const int maxSentReportsToKeep = 100;
  static const Duration _timeout = Duration(seconds: 10);
  static const Duration _flushInterval = Duration(minutes: 5);
  static const int _maxQueuedFlushPerRun = 20;
  static const String _otzariaDirectReportTarget = 'אוצריא';
  static const String _sefariaDirectReportTarget = 'ספריא';

  static Timer? _flushTimer;
  static bool _isFlushing = false;
  static Completer<void>? _flushInFlight;

  /// עוצר את השליחה האוטומטית וממתין לשליחה שבאמצע, כדי שכתיבה חיצונית לתור
  /// (שחזור מגיבוי) לא תדרוס אותה. `startAutomaticFlush` מפעיל מחדש בעלייה.
  static Future<void> suspendAutomaticFlush() async {
    _flushTimer?.cancel();
    _flushTimer = null;
    await _flushInFlight?.future;
  }

  final http.Client _client;
  final HiveListRepository<DirectErrorReport> _queueRepository;
  final HiveListRepository<DirectErrorReport> _sentRepository;

  DirectErrorReportService({
    http.Client? client,
    HiveListRepository<DirectErrorReport>? queueRepository,
    HiveListRepository<DirectErrorReport>? sentRepository,
  }) : _client = client ?? http.Client(),
       _queueRepository =
           queueRepository ??
           HiveListRepository<DirectErrorReport>(
             boxName: queueBoxName,
             key: pendingReportsKey,
             fromJson: DirectErrorReport.fromJson,
             toJson: (report) => report.toJson(),
           ),
       _sentRepository =
           sentRepository ??
           HiveListRepository<DirectErrorReport>(
             boxName: queueBoxName,
             key: sentReportsKey,
             fromJson: DirectErrorReport.fromJson,
             toJson: (report) => report.toJson(),
           );

  /// סוגר את ה-HTTP client הפנימי. ב-Windows admin install הקרנל נתקע
  /// לכמה שניות בעת ניקוי socket handles ביציאה, אז יש לקרוא לפונקציה
  /// הזו כשלב מקדים ל-onWindowClose עבור המופע הארוך-טווח (זה שמריץ
  /// את `startAutomaticFlush` ב-main.dart). מופעים קצרי-טווח שנוצרים
  /// בדיאלוגים ובמסכי הגדרות לא צריכים להיכלל כאן.
  Future<void> closeHttpClient() async {
    _client.close();
  }

  String get senderEmail =>
      (Settings.getValue<String>(
                SettingsRepository.keyErrorReportSenderEmail,
              ) ??
              '')
          .trim();

  bool get queueWhenOfflineEnabled =>
      Settings.getValue<bool>(
        SettingsRepository.keyQueueErrorReportsWhenOffline,
      ) ??
      true;

  bool get _isOfflineMode =>
      Settings.getValue<bool>(SettingsRepository.keyOfflineMode) ?? false;

  Future<void> saveSenderEmail(String email) async {
    await Settings.setValue(
      SettingsRepository.keyErrorReportSenderEmail,
      email.trim(),
    );
  }

  Future<void> clearSenderEmail() async {
    await Settings.setValue(SettingsRepository.keyErrorReportSenderEmail, '');
  }

  Future<void> setQueueWhenOfflineEnabled(bool value) async {
    await Settings.setValue(
      SettingsRepository.keyQueueErrorReportsWhenOffline,
      value,
    );
  }

  Future<int> getPendingReportsCount() async {
    final reports = await _queueRepository.load();
    return reports.length;
  }

  Future<List<DirectErrorReport>> getPendingReports() async {
    return _queueRepository.load();
  }

  Future<List<DirectErrorReport>> getSentReports() async {
    return _sentRepository.load();
  }

  Future<void> deleteSentReport(String reportId) async {
    final reports = await _sentRepository.load();
    reports.removeWhere((report) => report.id == reportId);
    await _sentRepository.save(reports);
  }

  Future<void> clearSentReports() async {
    await _sentRepository.clear();
  }

  Future<void> updatePendingReport(DirectErrorReport report) async {
    final reports = await _queueRepository.load();
    final index = reports.indexWhere((item) => item.id == report.id);
    if (index == -1) {
      return;
    }

    reports[index] = report;
    await _queueRepository.save(reports);
  }

  Future<void> deletePendingReport(String reportId) async {
    final reports = await _queueRepository.load();
    reports.removeWhere((report) => report.id == reportId);
    await _queueRepository.save(reports);
  }

  /// מסמן דיווח מהתור כנשלח ידנית: מעביר אותו להיסטוריית הנשלחים
  /// ומסיר אותו מהתור, מבלי לפנות לשרת.
  Future<void> markPendingReportAsSent(DirectErrorReport report) async {
    await _saveSentReport(report);
    await deletePendingReport(report.id);
  }

  Future<void> queueReport(
    DirectErrorReport report, {
    DirectErrorReportQueueType queueType = DirectErrorReportQueueType.manual,
  }) async {
    await _enqueueIfNeeded(report, queueType: queueType);
  }

  Future<void> clearPendingReports() async {
    await _queueRepository.clear();
  }

  Future<DirectReportDeliveryResult> submitPendingReport(
    DirectErrorReport report,
  ) async {
    final result = await submitReport(report);
    if (result.isSent) {
      await deletePendingReport(report.id);
    }
    return result;
  }

  /// בונה סקריפט שליחה של הדיווחים השמורים, מותאם למערכת ההפעלה של המחשב
  /// המחובר שבו יופעל. הסקריפט קריא לבני אדם (ללא Base64), ומציג את התוצאה
  /// בחלון מערכת כדי להימנע מג'יבריש עברית בקונסול.
  OfflineSendScript buildOfflineSendScript(
    List<DirectErrorReport> reports, {
    required OfflineSendScriptTarget target,
  }) {
    return buildOfflineReportScript(
      target: target,
      endpoint: _endpoint,
      payloads: reports.map((report) => report.toApiPayload()).toList(),
      ids: reports.map((report) => report.id).toList(),
      idField: 'report_id',
      baseFileName: 'otzaria_send_saved_reports',
    );
  }

  Future<DirectReportDeliveryResult> submitReport(
    DirectErrorReport report,
  ) async {
    final directReportTargetLabel = _resolveDirectReportTargetLabel(report);

    if (_isOfflineMode) {
      if (!queueWhenOfflineEnabled) {
        return DirectReportDeliveryResult.failed(
          ReportMessages.offlineQueueDisabled,
        );
      }

      await _enqueueIfNeeded(
        report,
        queueType: DirectErrorReportQueueType.automaticRetry,
      );
      return DirectReportDeliveryResult.queued(
        ReportMessages.queuedOffline(directReportTargetLabel),
      );
    }

    final attemptResult = await _trySend(report);
    if (attemptResult.isSuccess) {
      await _saveSentReport(report);
      unawaited(flushPendingReports(onlyAutomaticRetry: true));
      if (attemptResult.isDuplicate) {
        return DirectReportDeliveryResult.sent(
          ReportMessages.duplicateReport(directReportTargetLabel),
          isDuplicate: true,
        );
      }
      if (_isSefariaReport(report)) {
        return DirectReportDeliveryResult.sent(ReportMessages.sentToSefaria);
      }

      return DirectReportDeliveryResult.sent(ReportMessages.sentToOtzaria);
    }

    if (attemptResult.isPermanentFailure) {
      return DirectReportDeliveryResult.failed(attemptResult.message);
    }

    await _enqueueIfNeeded(
      report,
      queueType: DirectErrorReportQueueType.automaticRetry,
    );
    return DirectReportDeliveryResult.queued(
      ReportMessages.queuedAfterFailure(directReportTargetLabel),
    );
  }

  bool _isSefariaReport(DirectErrorReport report) {
    final normalizedSource = report.sourceFolder.trim().toLowerCase();
    return normalizedSource.contains('sefariatootzaria') ||
        normalizedSource.contains('sefaria');
  }

  String _resolveDirectReportTargetLabel(DirectErrorReport report) {
    return _isSefariaReport(report)
        ? _sefariaDirectReportTarget
        : _otzariaDirectReportTarget;
  }

  Future<int> flushPendingReports({
    bool onlyAutomaticRetry = false,
  }) async {
    if (_isOfflineMode || _isFlushing) {
      return 0;
    }

    _isFlushing = true;
    final inFlight = _flushInFlight = Completer<void>();
    try {
      final pendingReports = await _queueRepository.load();
      if (pendingReports.isEmpty) {
        return 0;
      }

      final reportsToAttempt = onlyAutomaticRetry
          ? pendingReports
                .where(
                  (report) =>
                      report.queueType ==
                      DirectErrorReportQueueType.automaticRetry,
                )
                .take(_maxQueuedFlushPerRun)
                .toList()
          : pendingReports.take(_maxQueuedFlushPerRun).toList();

      if (reportsToAttempt.isEmpty) {
        return 0;
      }

      final remainingReports = List<DirectErrorReport>.from(pendingReports);
      var sentCount = 0;

      for (final report in reportsToAttempt) {
        final attemptResult = await _trySend(report);

        if (attemptResult.isSuccess) {
          remainingReports.removeWhere((item) => item.id == report.id);
          await _saveSentReport(report);
          sentCount++;
          continue;
        }

        if (attemptResult.isPermanentFailure) {
          debugPrint(
            'Direct report permanently failed and was removed from queue: ${report.id}',
          );
          remainingReports.removeWhere((item) => item.id == report.id);
          continue;
        }

        break;
      }

      await _queueRepository.save(remainingReports);
      return sentCount;
    } finally {
      _isFlushing = false;
      _flushInFlight = null;
      inFlight.complete();
    }
  }

  Future<void> startAutomaticFlush() async {
    if (_flushTimer != null) {
      return;
    }

    unawaited(flushPendingReports(onlyAutomaticRetry: true));
    _flushTimer = Timer.periodic(_flushInterval, (_) {
      unawaited(flushPendingReports(onlyAutomaticRetry: true));
    });
  }

  static bool isValidSenderEmail(String email) {
    final normalized = email.trim();
    if (normalized.isEmpty) {
      return false;
    }

    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(normalized);
  }

  Future<void> _enqueueIfNeeded(
    DirectErrorReport report, {
    required DirectErrorReportQueueType queueType,
  }) async {
    final pendingReports = await _queueRepository.load();
    final alreadyQueued = pendingReports.any((item) => item.id == report.id);
    if (alreadyQueued) {
      return;
    }

    pendingReports.add(report.copyWith(queueType: queueType));
    await _queueRepository.save(pendingReports);
  }

  Future<void> _saveSentReport(DirectErrorReport report) async {
    final sentReports = await _sentRepository.load();
    sentReports.removeWhere((item) => item.id == report.id);
    sentReports.insert(0, report);
    if (sentReports.length > maxSentReportsToKeep) {
      sentReports.removeRange(maxSentReportsToKeep, sentReports.length);
    }
    await _sentRepository.save(sentReports);
  }

  Future<_SendAttemptResult> _trySend(DirectErrorReport report) async {
    try {
      final response = await _client
          .post(
            Uri.parse(_endpoint),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(report.toApiPayload()),
          )
          .timeout(_timeout);

      if (response.statusCode == HttpStatus.ok) {
        return _SendAttemptResult.success(
          isDuplicate: _isDuplicateResponse(response.body),
        );
      }

      if (_isPermanentHttpFailure(response.statusCode)) {
        return _SendAttemptResult.permanentFailure(
          ReportMessages.serverPermanentFailure(response.statusCode),
        );
      }

      return _SendAttemptResult.transientFailure(
        ReportMessages.serverTransientFailure(response.statusCode),
      );
    } on SocketException catch (e) {
      debugPrint('Direct report network error: $e');
      return _SendAttemptResult.transientFailure(ReportMessages.noInternet);
    } on http.ClientException catch (e) {
      debugPrint('Direct report client error: $e');
      return _SendAttemptResult.transientFailure(ReportMessages.sendFailed);
    } on TimeoutException {
      return _SendAttemptResult.transientFailure(ReportMessages.serverTimeout);
    } catch (e) {
      debugPrint('Direct report unexpected error: $e');
      return _SendAttemptResult.transientFailure(
        ReportMessages.unexpectedSendError,
      );
    }
  }

  bool _isPermanentHttpFailure(int statusCode) {
    return statusCode == HttpStatus.badRequest || statusCode == 422;
  }

  /// השרת מחזיר 200 עם duplicate:true כשתוכן זהה כבר נשלח — הדיווח נקלט
  /// אך לא נשלח מייל, ואסור להציג למשתמש "נשלח בהצלחה".
  static bool _isDuplicateResponse(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> && decoded['duplicate'] == true;
    } catch (_) {
      return false;
    }
  }
}

class _SendAttemptResult {
  final bool isSuccess;
  final String message;
  final _SendAttemptFailureType? failureType;
  final bool isDuplicate;

  const _SendAttemptResult._({
    required this.isSuccess,
    required this.message,
    this.failureType,
    this.isDuplicate = false,
  });

  const _SendAttemptResult.success({bool isDuplicate = false})
    : this._(
        isSuccess: true,
        message: '',
        failureType: null,
        isDuplicate: isDuplicate,
      );

  bool get isPermanentFailure =>
      !isSuccess && failureType == _SendAttemptFailureType.permanent;

  factory _SendAttemptResult.transientFailure(String message) {
    return _SendAttemptResult._(
      isSuccess: false,
      message: message,
      failureType: _SendAttemptFailureType.transient,
    );
  }

  factory _SendAttemptResult.permanentFailure(String message) {
    return _SendAttemptResult._(
      isSuccess: false,
      message: message,
      failureType: _SendAttemptFailureType.permanent,
    );
  }
}

enum _SendAttemptFailureType {
  transient,
  permanent,
}
