import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:otzaria/plugins/models/installed_plugin.dart';
import 'package:otzaria/plugins/models/plugin_valid_permissions.dart';
import 'package:otzaria/plugins/repository/plugin_registry_repository.dart';
import 'package:otzaria/plugins/storage/plugin_system_database.dart';

/// שער בקשות ההרשאה של WebView התוספים.
///
/// יכולת מאושרת רק לאחר הצהרה במניפסט והענקה מפורשת של המשתמש; היתר נדחה ונרשם
/// בלוג הריצה של התוסף.
class PluginWebViewPermissionGate {
  const PluginWebViewPermissionGate._();

  /// משתמשים בערך המחרוזת כי `PermissionResourceType.==` אינו סימטרי.
  static const Map<String, String> requirements = {
    'CLIPBOARD_READ': pluginClipboardReadPermission,
  };

  /// התשובה לבקשה של [request], אחרי בדיקת המניפסט וההענקה שנשמרה.
  ///
  /// אינה זורקת: חריגה כאן משאירה את ה-deferral של WebView2 פתוח, כלומר דף
  /// שממתין לתשובה שלא תבוא.
  static Future<PermissionResponse> respond({
    required InstalledPlugin plugin,
    required PermissionRequest request,
    required PluginRegistryRepository registry,
  }) async {
    try {
      final decision = await _decide(
        resources: request.resources,
        plugin: plugin,
        registry: registry,
      );
      if (decision.granted) {
        return PermissionResponse(
          resources: request.resources,
          action: PermissionResponseAction.GRANT,
        );
      }
      _logDenial(plugin, request, decision.missingPermission);
    } catch (e) {
      debugPrint(
        'PluginWebViewPermissionGate: החלטה נכשלה לתוסף '
        '${plugin.pluginId} — נדחה. $e',
      );
    }
    return PermissionResponse(
      resources: request.resources,
      action: PermissionResponseAction.DENY,
    );
  }

  static Future<_Decision> _decide({
    required List<PermissionResourceType> resources,
    required InstalledPlugin plugin,
    required PluginRegistryRepository registry,
  }) async {
    // בקשה בלי משאבים אינה "הכול מותר" אלא בקשה שאין מה לאשר בה.
    if (resources.isEmpty) return const _Decision.denied(null);

    for (final resource in resources) {
      final permission = requiredPermissionFor(resource);
      if (permission == null) return _Decision.denied(resource.toValue());
      if (!declaresPermission(plugin, permission)) {
        return _Decision.denied(permission);
      }
      if (await registry.getPermission(plugin.pluginId, permission) != true) {
        return _Decision.denied(permission);
      }
    }
    return const _Decision.granted();
  }

  /// ההרשאה שנדרשת ל-[resource], או `null` כשהיכולת אינה נפתחת לתוספים.
  @visibleForTesting
  static String? requiredPermissionFor(PermissionResourceType resource) {
    return requirements[resource.toValue()];
  }

  /// האם המניפסט הצהיר על [permission].
  ///
  /// כולל את אליאס התאימות לאחור, כמו ב-`PluginBridgeHandler`: תוסף ותיק
  /// שהצהיר על ההרשאה שממנה זו פוצלה אינו נשבר בעדכון.
  @visibleForTesting
  static bool declaresPermission(InstalledPlugin plugin, String permission) {
    final declared = plugin.manifest.permissions;
    return pluginBaselinePermissions.contains(permission) ||
        declared.contains(permission) ||
        declared.contains(pluginLegacyPermissionAliases[permission]);
  }

  static void _logDenial(
    InstalledPlugin plugin,
    PermissionRequest request,
    String? missing,
  ) {
    final resources = request.resources.map((r) => r.toValue()).join(', ');
    final reason = missing == null
        ? 'היכולת אינה נפתחת לתוספים'
        : 'חסרה ההרשאה $missing';
    final message =
        'בקשת הרשאת WebView נדחתה [$resources] מ-${request.origin}: $reason';
    debugPrint('PluginWebViewPermissionGate [${plugin.pluginId}]: $message');
    // fire-and-forget, כמו כל כתיבה ללוג הריצה.
    unawaited(
      PluginSystemDatabase.instance.writeLog(plugin.pluginId, 'warn', message),
    );
  }
}

class _Decision {
  final bool granted;

  /// ההרשאה שחסרה, או `null` כשהיכולת עצמה אינה ממופה.
  final String? missingPermission;

  const _Decision.granted() : granted = true, missingPermission = null;

  const _Decision.denied(this.missingPermission) : granted = false;
}
