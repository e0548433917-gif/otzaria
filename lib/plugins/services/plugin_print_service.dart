import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:printing/printing.dart';

/// מייצר PDF מתוכן WebView של תוסף — להדפסה דרך דיאלוג המערכת או לייצוא
/// לקובץ (`ui.print` / `ui.exportPdf`).
class PluginPrintService {
  const PluginPrintService();

  /// הפלטפורמות שבהן `createPdf` ממומש בצד הנייטיב של ה-WebView.
  static bool get isSupported =>
      Platform.isWindows || Platform.isMacOS || Platform.isIOS;

  /// מייצר PDF מהדף הנטען ב-[controller]. זורק אם הייצור נכשל או חזר ריק.
  Future<Uint8List> createPdf(InAppWebViewController controller) async {
    if (!isSupported) {
      throw Exception(
        'error.unsupported_platform: PDF generation is not supported on '
        '${Platform.operatingSystem}',
      );
    }

    final Uint8List? generated;
    try {
      generated = await controller.createPdf();
    } catch (e) {
      throw Exception('error.internal: PDF generation failed: $e');
    }
    if (generated == null || generated.isEmpty) {
      throw Exception('error.internal: PDF generation returned no data');
    }
    return generated;
  }

  /// מדפיס את הדף הנטען ב-[controller] בשם עבודה [jobName].
  /// מחזיר האם המשתמש אישר את ההדפסה בדיאלוג המערכת.
  Future<bool> printWebView(
    InAppWebViewController controller, {
    required String jobName,
  }) async {
    final pdf = await createPdf(controller);
    return Printing.layoutPdf(
      name: jobName,
      onLayout: (_) => pdf,
      // ה-PDF כבר מעומד ע"י מנוע ה-WebView; אין מה לפרוס מחדש לפי המדפסת.
      dynamicLayout: false,
      usePrinterSettings: true,
    );
  }
}
